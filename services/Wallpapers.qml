pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import qs.components

// Wallpapers p/ o seletor: imagens e videos de Config.wallpaperDir com miniatura
// em cache (scripts/wall-thumbs.sh, so roda quando o seletor abre).
// - Imagem: Config.wallpaperApply (awww); o awww-daemon restaura no boot sozinho.
// - Video: Config.wallpaperVideoPlayer via scripts/wall-video.sh numa unidade
//   transiente do systemd (qs-wallvideo): sobrevive a reload da shell, fica
//   salvo no ShellState e volta quando a shell inicia.
// Aplicar um para o outro. Caminhos vao como argumento (nunca dentro do sh -c).
Singleton {
  id: root

  property var items: []            // {path, name, thumb, video}
  property string image: ""         // imagem do awww (awww query)
  readonly property string video: ShellState.wallpaperVideo
  readonly property string current: video !== "" ? video : image
  readonly property bool loading: listProc.running
  readonly property string unit: "qs-wallvideo"

  property var pending: []
  property bool primed: false       // ja listou 1x (depois, a grade so troca no fim)
  property bool restored: false

  function refresh() {
    pending = [];
    listProc.running = false;
    listProc.running = true;
    queryProc.running = false;
    queryProc.running = true;
  }

  function apply(it) {
    if (it.video) {
      ShellState.wallpaperVideo = it.path;
      startVideo(it.path, true);
      return;
    }
    ShellState.wallpaperVideo = "";
    Quickshell.execDetached(["sh", "-c", "systemctl --user stop " + unit + " 2>/dev/null; exec \"$@\"", "sh"].concat(Config.wallpaperApply, [it.path]));
    image = it.path;
  }

  // replace: troca o que estiver tocando; senao (partida) so sobe se nao houver nada.
  // Um player por tela ($0 = script, depois player, arquivo e as saidas).
  function startVideo(path, replace) {
    const pre = replace ? "systemctl --user stop " + unit + " 2>/dev/null; " : "systemctl --user is-active --quiet " + unit + " && exit 0; ";
    const run = "exec systemd-run --user --unit=" + unit + " --collect --quiet sh \"$0\" \"$@\"";
    Quickshell.execDetached(["sh", "-c", pre + run, Quickshell.shellPath("scripts/wall-video.sh"), Config.wallpaperVideoPlayer, path].concat(Quickshell.screens.map(s => s.name)));
  }

  // partida: o video salvo volta (espera o state.json ser lido)
  function restore() {
    if (restored || !ShellState.ready)
      return;
    restored = true;
    if (video !== "")
      startVideo(video, false);
  }
  Connections {
    target: ShellState
    function onReadyChanged() {
      root.restore();
    }
  }
  Component.onCompleted: restore()

  Process {
    id: listProc
    command: ["sh", Quickshell.shellPath("scripts/wall-thumbs.sh"), Config.wallpaperDir]
    stdout: SplitParser {
      // caminho<TAB>miniatura<TAB>image|video
      onRead: line => {
        const f = line.split("\t");
        if (f.length < 3)
          return;
        root.pending.push({
          path: f[0],
          name: f[0].slice(f[0].lastIndexOf("/") + 1).replace(/\.[^.]+$/, ""),
          thumb: "file://" + f[1],
          video: f[2] === "video"
        });
        // 1a vez (miniaturas sendo geradas): a grade enche conforme saem
        if (!root.primed)
          root.items = root.pending.slice();
      }
    }
    // depois, a lista nova (com remocoes) entra inteira no fim: reabrir nao pisca vazio
    onExited: {
      root.items = root.pending.slice();
      root.primed = true;
    }
  }

  // a imagem atual ja na partida: a 1a abertura ja seleciona e rola ate ela
  Process {
    id: queryProc
    command: ["awww", "query"]
    running: true
    stdout: StdioCollector {
      // ": eDP-1: 1366x768, scale: 1, currently displaying: image: /caminho.jpg"
      onStreamFinished: {
        const m = text.match(/image: (.+)$/m);
        if (m)
          root.image = m[1].trim();
      }
    }
  }
}
