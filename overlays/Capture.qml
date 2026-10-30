import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs.components
import qs.services

// Captura (Print) e gravacao (Shift+Print): a tela congela (grim) e escurece; arrastar =
// regiao, mouse sobre uma janela destaca e clique captura ela, Enter = tela toda, Esc ou
// clique direito cancela. Screenshot: recorta, copia e salva em ~/Imagens/Screenshots.
// Gravacao: a mesma escolha vira a area do gpu-screen-recorder (services/Recorder).
// Barra embaixo (como o Cmd+Shift+5 do macOS): troca o modo e as opcoes de cada um, que
// ficam salvas (ShellState). Temporizador: captura ao vivo depois da contagem.
PanelWindow {
  id: root

  WlrLayershell.namespace: "quickshell:capture"
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
  exclusionMode: ExclusionMode.Ignore
  anchors.top: true
  anchors.bottom: true
  anchors.left: true
  anchors.right: true
  color: "transparent"
  visible: open

  property bool open: false
  property string mode: "shot"          // shot | record
  property rect sel: Qt.rect(0, 0, 0, 0)
  property bool dragging: false
  property point origin: Qt.point(0, 0)
  property var windows: []              // janelas visiveis neste monitor (coordenadas da tela)

  readonly property var monitor: screen ? Hyprland.monitorFor(screen) : null
  readonly property real scaleF: monitor ? monitor.scale : 1
  readonly property string tmp: Quickshell.env("XDG_RUNTIME_DIR") + "/eco-captura.png"
  readonly property string outDir: ShellState.captureDir || Quickshell.env("HOME") + "/Imagens/Screenshots"
  readonly property string home: Quickshell.env("HOME")

  function start(m) {
    if (open) {          // o mesmo atalho de novo cancela
      close();
      return;
    }
    mode = m;
    optionsOpen = false;
    if (m === "record") {
      listAudio.running = true;
      listApps.running = true;
    }
    sel = Qt.rect(0, 0, 0, 0);
    dragging = false;
    Hyprland.refreshToplevels();
    grim.command = ["grim", "-o", screen.name, tmp];
    grim.running = true;
  }
  // tela inteira na hora, sem escolher
  function quick() {
    save(["grim", "-o", screen.name, "$out"]);
  }
  function close() {
    open = false;
  }

  function visibleWindows() {
    const ws = monitor && monitor.activeWorkspace ? monitor.activeWorkspace.name : "";
    const out = [];
    for (const t of Hyprland.toplevels.values) {
      const i = t.lastIpcObject;
      if (!i || !i.at || !i.workspace || i.workspace.name !== ws || i.hidden)
        continue;
      out.push({ r: Qt.rect(i.at[0] - monitor.x, i.at[1] - monitor.y, i.size[0], i.size[1]), floating: i.floating });
    }
    // flutuantes por cima: testadas primeiro
    return out.sort((a, b) => (b.floating ? 1 : 0) - (a.floating ? 1 : 0));
  }
  function windowAt(x, y) {
    for (const w of windows) {
      if (x >= w.r.x && x < w.r.x + w.r.width && y >= w.r.y && y < w.r.y + w.r.height)
        return w.r;
    }
    return null;
  }

  // gera $out (cmd) e, conforme as opcoes, copia e/ou guarda; avisa no fim
  function save(cmd) {
    const keep = ShellState.captureSave, copy = ShellState.captureCopy || !keep;
    const dir = outDir.replace(home, "~");
    const out = keep ? outDir + "/captura_$(date +%F_%H-%M-%S).png" : Quickshell.env("XDG_RUNTIME_DIR") + "/eco-captura-final.png";
    const title = copy && keep ? "Captura copiada e salva" : (copy ? "Captura copiada" : "Captura salva");
    const sh = 'out="' + out + '"; mkdir -p "' + outDir + '" && ' + cmd.join(" ") + (copy ? ' && wl-copy -t image/png < "$out"' : "") + ' && notify-send -a Captura -i "$out" "' + title + '" "' + (keep ? "Em " + dir : "Na área de transferência") + '"';
    Quickshell.execDetached(["sh", "-c", sh]);
  }
  function finish(r) {
    close();
    if (r.width < 4 || r.height < 4)
      return;
    if (mode === "record") {
      const full = r.x <= 0 && r.y <= 0 && r.width >= width && r.height >= height;
      if (full)
        Recorder.startMonitor(screen.name);
      else
        Recorder.startRegion(Math.round(monitor.x + r.x), Math.round(monitor.y + r.y), Math.round(r.width), Math.round(r.height));
      return;
    }
    const t = ShellState.captureTimer;
    if (t > 0) {
      // ao vivo depois da contagem (para dar tempo de abrir um menu, por exemplo)
      Quickshell.execDetached(["notify-send", "-a", "Captura", "-t", String(t * 1000), "Captura em " + t + " s"]);
      const g = '"' + Math.round(monitor.x + r.x) + "," + Math.round(monitor.y + r.y) + " " + Math.round(r.width) + "x" + Math.round(r.height) + '"';
      save(["sleep", String(t), "&&", "grim", "-g", g, '"$out"']);
      return;
    }
    const s = scaleF;
    const geo = Math.round(r.width * s) + "x" + Math.round(r.height * s) + "+" + Math.round(r.x * s) + "+" + Math.round(r.y * s);
    save(["magick", '"' + tmp + '"', "-crop", geo, "+repage", '"$out"']);
  }

  function pickDir() {
    const cur = mode === "record" ? Recorder.dir : outDir;
    close();
    dirPick.command = ["kdialog", "--getexistingdirectory", cur, "--title", mode === "record" ? "Pasta das gravações" : "Pasta das capturas"];
    dirPick.running = true;
  }
  Process {
    id: dirPick
    stdout: StdioCollector {
      onStreamFinished: {
        const d = text.trim();
        if (d !== "") {
          if (root.mode === "record")
            ShellState.recDir = d;
          else
            ShellState.captureDir = d;
        }
        root.start(root.mode);
      }
    }
  }

  Process {
    id: grim
    onExited: code => {
      if (code !== 0)
        return;
      frozen.source = "";
      frozen.source = "file://" + root.tmp;
      root.windows = root.visibleWindows();
      root.open = true;
    }
  }

  // tela congelada
  Image {
    id: frozen
    anchors.fill: parent
    cache: false
    fillMode: Image.Stretch
  }

  // escurece fora da selecao (4 faixas; sem selecao, a tela toda)
  readonly property color dim: Qt.alpha(Theme.scrim, 0.5)
  Rectangle {
    color: root.dim
    x: 0
    y: 0
    width: parent.width
    height: root.sel.width > 0 ? root.sel.y : parent.height
  }
  Rectangle {
    visible: root.sel.width > 0
    color: root.dim
    x: 0
    y: root.sel.y + root.sel.height
    width: parent.width
    height: parent.height - y
  }
  Rectangle {
    visible: root.sel.width > 0
    color: root.dim
    x: 0
    y: root.sel.y
    width: root.sel.x
    height: root.sel.height
  }
  Rectangle {
    visible: root.sel.width > 0
    color: root.dim
    x: root.sel.x + root.sel.width
    y: root.sel.y
    width: parent.width - x
    height: root.sel.height
  }
  // borda da selecao + tamanho
  Rectangle {
    visible: root.sel.width > 0
    x: root.sel.x - 2
    y: root.sel.y - 2
    width: root.sel.width + 4
    height: root.sel.height + 4
    color: "transparent"
    border.width: 2
    border.color: root.mode === "record" ? Theme.error : Theme.primary
  }
  Rectangle {
    visible: root.sel.width > 0
    x: Math.min(root.sel.x, parent.width - width - Theme.space.sm)
    y: root.sel.y + root.sel.height + Theme.space.sm + height > parent.height ? root.sel.y - height - Theme.space.sm : root.sel.y + root.sel.height + Theme.space.sm
    implicitWidth: size.implicitWidth + 2 * Theme.space.md
    implicitHeight: 26
    radius: height / 2
    color: Theme.surface
    UiText {
      id: size
      anchors.centerIn: parent
      font.pixelSize: Theme.type.label_l
      text: Math.round(root.sel.width * root.scaleF) + " × " + Math.round(root.sel.height * root.scaleF)
    }
  }

  // ---- opcoes (dados): cada uma e uma chave do ShellState e seus valores ----
  // Dispositivos de audio e apps vem do proprio gpu-screen-recorder ao abrir no modo gravacao.
  property var sysDevices: []
  property var micDevices: []
  property var apps: []
  property bool optionsOpen: false

  function pairs(list) {
    return list.map(x => ({ v: x[0], l: x[1] }));
  }
  readonly property var recRows: [
    { g: "Vídeo", label: "Codec", key: "recCodec", values: pairs([["auto", "Auto"], ["h264", "H.264"], ["hevc", "HEVC"], ["hevc_10bit", "HEVC 10-bit"], ["vp9", "VP9"]]) },
    { g: "Vídeo", label: "Qualidade", key: "recQuality", values: pairs([["medium", "Média"], ["high", "Alta"], ["very_high", "Muito alta"], ["ultra", "Máxima"], ["cbr:8000", "8 Mbps"], ["cbr:16000", "16 Mbps"], ["cbr:32000", "32 Mbps"]]) },
    { g: "Vídeo", label: "FPS", key: "recFps", values: pairs([[24, "24"], [30, "30"], [60, "60"]]) },
    { g: "Vídeo", label: "Quadros", key: "recFpsMode", values: pairs([["vfr", "Variável"], ["cfr", "Constante (editores)"]]) },
    { g: "Vídeo", label: "Resolução", key: "recScale", values: pairs([["0x0", "Original"], ["1920x1080", "1080p"], ["1280x720", "720p"], ["854x480", "480p"]]) },
    { g: "Vídeo", label: "Cores", key: "recColor", values: pairs([["limited", "Limitada"], ["full", "Completa"]]) },
    { g: "Vídeo", label: "Codificador", key: "recEncoder", values: pairs([["gpu", "GPU"], ["cpu", "CPU (só H.264)"]]) },
    { g: "Vídeo", label: "Keyframe", key: "recKeyint", values: pairs([[1, "1 s"], [2, "2 s"], [5, "5 s"]]) },
    { g: "Áudio", label: "Sistema", key: "recSys", values: pairs([["", "Nenhum"], ["default_output", "Padrão"]].concat(sysDevices)) },
    { g: "Áudio", label: "Microfone", key: "recMic", values: pairs([["", "Nenhum"], ["default_input", "Padrão"]].concat(micDevices)) },
    { g: "Áudio", label: "Só um app", key: "recApp", values: pairs([["", "Não"]].concat(apps.map(a => [a, a]))) },
    { g: "Áudio", label: "Codec", key: "recAudioCodec", values: pairs([["opus", "Opus"], ["aac", "AAC"], ["flac", "FLAC"]]) },
    { g: "Áudio", label: "Bitrate", key: "recAudioBitrate", values: pairs([[96, "96"], [128, "128"], [192, "192"], [256, "256 kbps"]]) },
    { g: "Arquivo", label: "Formato", key: "recFormat", values: pairs([["mp4", "MP4"], ["mkv", "MKV"], ["webm", "WebM"], ["mov", "MOV"]]) },
    { g: "Arquivo", label: "Pasta", key: "", values: [{ v: "pick", l: Recorder.dir.replace(home, "~") }] },
    { g: "Extras", label: "Webcam (tela inteira)", key: "recWebcam", values: pairs([["none", "Não"], ["br", "↘"], ["bl", "↙"], ["tr", "↗"], ["tl", "↖"]]) },
    { g: "Extras", label: "Cursor", key: "recCursor", values: pairs([[true, "Sim"], [false, "Não"]]) },
    { g: "Extras", label: "Replay (últimos)", key: "recReplay", values: pairs([[0, "Não"], [30, "30 s"], [60, "1 min"], [120, "2 min"], [300, "5 min"]]) },
    { g: "Extras", label: "Replay em", key: "recReplayStorage", values: pairs([["ram", "Memória"], ["disk", "Disco"]]) }
  ]
  function row(key) {
    return recRows.find(r => r.key === key);
  }
  function valueLabel(r) {
    const v = r.values.find(x => x.v === ShellState[r.key]);
    return v ? v.l : String(ShellState[r.key]);
  }
  function pick(r, v) {
    if (v === "pick")
      pickDir();
    else
      ShellState[r.key] = v;
  }
  function cycle(key) {
    const r = row(key), i = r.values.findIndex(x => x.v === ShellState[key]);
    ShellState[key] = r.values[(i + 1) % r.values.length].v;
  }
  readonly property string audioSummary: {
    const parts = [];
    if (ShellState.recSys !== "")
      parts.push("sistema");
    if (ShellState.recMic !== "")
      parts.push("mic");
    if (ShellState.recApp !== "")
      parts.push(ShellState.recApp);
    return parts.length > 0 ? parts.join(" + ") : "nenhum";
  }

  Process {
    id: listAudio
    command: ["gpu-screen-recorder", "--list-audio-devices"]
    stdout: StdioCollector {
      onStreamFinished: {
        const devs = text.split("\n").filter(l => l.includes("|")).map(l => l.split("|"));
        root.sysDevices = devs.filter(d => d[0].endsWith(".monitor"));
        root.micDevices = devs.filter(d => !d[0].endsWith(".monitor") && !d[0].startsWith("default_"));
      }
    }
  }
  Process {
    id: listApps
    command: ["gpu-screen-recorder", "--list-application-audio"]
    stdout: StdioCollector {
      onStreamFinished: root.apps = text.split("\n").map(l => l.trim()).filter(l => l !== "")
    }
  }

  // ---- barra embaixo: modo + opcoes principais (clique alterna) + "Opcoes..." ----
  readonly property var shotChips: [
    { label: "Copiar: " + (ShellState.captureCopy ? "sim" : "não"), act: () => ShellState.captureCopy = !ShellState.captureCopy },
    { label: "Salvar: " + (ShellState.captureSave ? "sim" : "não"), act: () => ShellState.captureSave = !ShellState.captureSave },
    { label: "Temporizador: " + (ShellState.captureTimer > 0 ? ShellState.captureTimer + " s" : "não"), act: () => ShellState.captureTimer = [0, 3, 5, 10][([0, 3, 5, 10].indexOf(ShellState.captureTimer) + 1) % 4] },
    { label: "Pasta: " + outDir.replace(home, "~"), act: () => pickDir() }
  ]
  readonly property var recChips: [
    { label: "Áudio: " + audioSummary, act: () => root.optionsOpen = true },
    { label: "Qualidade: " + valueLabel(row("recQuality")), act: () => cycle("recQuality") },
    { label: valueLabel(row("recFps")) + " fps", act: () => cycle("recFps") },
    { label: "Replay: " + valueLabel(row("recReplay")), act: () => cycle("recReplay") },
    { label: root.optionsOpen ? "Fechar opções" : "Opções…", act: () => root.optionsOpen = !root.optionsOpen }
  ]

  Column {
    z: 10
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: Theme.space.xxl
    spacing: Theme.space.sm

    // painel com todas as opcoes de gravacao, em 4 colunas por grupo
    Rectangle {
      id: panel
      visible: root.optionsOpen && root.mode === "record"
      anchors.horizontalCenter: parent.horizontalCenter
      implicitWidth: groups.implicitWidth + 2 * Theme.space.lg
      implicitHeight: groups.implicitHeight + 2 * Theme.space.lg
      radius: Theme.shape.dialog || 28
      color: Theme.surface
      MouseArea {
        anchors.fill: parent      // engole o clique (nao comeca selecao por baixo)
        acceptedButtons: Qt.AllButtons
      }

      Row {
        id: groups
        anchors.centerIn: parent
        spacing: Theme.space.xl

        Repeater {
          model: ["Vídeo", "Áudio", "Arquivo", "Extras"]
          Column {
            id: grp
            required property string modelData
            width: 230
            spacing: Theme.space.sm
            UiText {
              color: Theme.primary
              font.pixelSize: Theme.type.title_s
              font.weight: Font.Bold
              text: grp.modelData
            }
            Repeater {
              model: root.recRows.filter(r => r.g === grp.modelData)
              Column {
                id: opt
                required property var modelData
                width: grp.width
                spacing: 2
                UiText {
                  color: Theme.fgSurfaceVariant
                  font.pixelSize: Theme.type.label_m
                  font.weight: Font.Medium
                  text: opt.modelData.label
                }
                Flow {
                  width: parent.width
                  spacing: Theme.space.xs
                  Repeater {
                    model: opt.modelData.values
                    Rectangle {
                      id: val
                      required property var modelData
                      readonly property bool on: opt.modelData.key !== "" && ShellState[opt.modelData.key] === modelData.v
                      implicitWidth: Math.min(valText.implicitWidth + 2 * Theme.space.sm, grp.width)
                      implicitHeight: 26
                      radius: height / 2
                      color: on ? Theme.primary : (valArea.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainer)
                      UiText {
                        id: valText
                        anchors.centerIn: parent
                        width: Math.min(implicitWidth, grp.width - 2 * Theme.space.sm)
                        elide: Text.ElideMiddle
                        color: val.on ? Theme.fgPrimary : Theme.fgSurface
                        font.pixelSize: Theme.type.label_m
                        text: val.modelData.l
                      }
                      MouseArea {
                        id: valArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.pick(opt.modelData, val.modelData.v)
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    }

    Rectangle {
      anchors.horizontalCenter: parent.horizontalCenter
      implicitWidth: tools.implicitWidth + 2 * Theme.space.sm
      implicitHeight: 44
      radius: height / 2
      color: Theme.surface
      MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
      }

      Row {
        id: tools
        anchors.centerIn: parent
        spacing: Theme.space.xs

        // modo
        Repeater {
          model: [{ id: "shot", label: "Captura" }, { id: "record", label: "Gravação" }]
          Rectangle {
            id: seg
            required property var modelData
            readonly property bool on: root.mode === modelData.id
            implicitWidth: segText.implicitWidth + 2 * Theme.space.md
            implicitHeight: 32
            radius: height / 2
            color: on ? (modelData.id === "record" ? Theme.error : Theme.primary) : (segArea.containsMouse ? Theme.surfaceContainerHighest : "transparent")
            UiText {
              id: segText
              anchors.centerIn: parent
              color: seg.on ? Theme.fgPrimary : Theme.fgSurface
              font.weight: Font.Bold
              text: seg.modelData.label
            }
            MouseArea {
              id: segArea
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                root.mode = seg.modelData.id;
                if (root.mode === "record") {
                  listAudio.running = true;
                  listApps.running = true;
                }
              }
            }
          }
        }

        Rectangle {
          width: 1
          height: 24
          anchors.verticalCenter: parent.verticalCenter
          color: Theme.outlineVariant
        }

        // opcoes principais do modo
        Repeater {
          model: root.mode === "record" ? root.recChips : root.shotChips
          Rectangle {
            id: chip
            required property var modelData
            implicitWidth: chipText.implicitWidth + 2 * Theme.space.md
            implicitHeight: 32
            radius: height / 2
            color: chipArea.containsMouse ? Theme.surfaceContainerHighest : Theme.surfaceContainer
            UiText {
              id: chipText
              anchors.centerIn: parent
              font.pixelSize: Theme.type.label_l
              font.weight: Font.DemiBold
              text: chip.modelData.label
            }
            MouseArea {
              id: chipArea
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: chip.modelData.act()
            }
          }
        }
      }
    }

    Rectangle {
      anchors.horizontalCenter: parent.horizontalCenter
      implicitWidth: hint.implicitWidth + 2 * Theme.space.md
      implicitHeight: 24
      radius: height / 2
      color: Theme.surface
      UiText {
        id: hint
        anchors.centerIn: parent
        color: Theme.fgSurfaceVariant
        font.pixelSize: Theme.type.label_m
        font.weight: Font.Medium
        text: "arraste uma região · clique numa janela · Enter tela toda · Esc cancela"
      }
    }
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    cursorShape: Qt.CrossCursor
    onPressed: m => {
      if (m.button === Qt.RightButton) {
        root.close();
        return;
      }
      root.origin = Qt.point(m.x, m.y);
      root.dragging = false;
    }
    onPositionChanged: m => {
      if (pressed && (root.dragging || Math.hypot(m.x - root.origin.x, m.y - root.origin.y) > 4)) {
        root.dragging = true;
        root.sel = Qt.rect(Math.min(m.x, root.origin.x), Math.min(m.y, root.origin.y), Math.abs(m.x - root.origin.x), Math.abs(m.y - root.origin.y));
      } else if (!pressed) {
        root.sel = root.windowAt(m.x, m.y) ?? Qt.rect(0, 0, 0, 0);
      }
    }
    onReleased: m => {
      if (m.button !== Qt.LeftButton)
        return;
      if (root.dragging)
        root.finish(root.sel);
      else {
        const w = root.windowAt(m.x, m.y);
        if (w)
          root.finish(w);
      }
    }
  }

  Item {
    focus: root.open
    Keys.onPressed: event => {
      if (event.key === Qt.Key_Escape)
        root.close();
      else if (event.key === Qt.Key_Enter || event.key === Qt.Key_Return)
        root.finish(Qt.rect(0, 0, root.width, root.height));
      else
        return;
      event.accepted = true;
    }
  }
}
