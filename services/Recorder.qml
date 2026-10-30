pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Gravacao de tela (gpu-screen-recorder): tela de um monitor ou regiao, com as opcoes da
// barra da tela de captura (ShellState: audio, qualidade, fps, cursor, pasta). SIGINT para
// e salva (codigo 0). O indicador da barra mostra o tempo.
Singleton {
  id: root

  readonly property bool recording: proc.running
  property int elapsed: 0
  property string file: ""
  readonly property string dir: ShellState.recDir || Quickshell.env("HOME") + "/Vídeos"
  readonly property var audioArgs: ({
      none: [],
      system: ["-a", "default_output"],
      mic: ["-a", "default_input"],
      both: ["-a", "default_output|default_input"]
    })
  readonly property string elapsedText: Math.floor(elapsed / 60) + ":" + String(elapsed % 60).padStart(2, "0")

  function startMonitor(name) {
    run(["-w", name]);
  }
  // coordenadas globais (layout do Hyprland); encoder pede lados pares
  function startRegion(x, y, w, h) {
    run(["-w", "region", "-region", (w - w % 2) + "x" + (h - h % 2) + "+" + x + "+" + y]);
  }
  function run(args) {
    if (proc.running)
      return;
    file = dir + "/gravacao_" + Qt.formatDateTime(new Date(), "yyyy-MM-dd_HH-mm-ss") + ".mp4";
    proc.command = ["gpu-screen-recorder"].concat(args, ["-f", String(ShellState.recFps), "-q", ShellState.recQuality, "-cursor", ShellState.recCursor ? "yes" : "no"], audioArgs[ShellState.recAudio] ?? [], ["-o", file]);
    elapsed = 0;
    proc.running = true;
  }
  function stop() {
    if (proc.running)
      proc.signal(2);
  }

  Process {
    id: proc
    onExited: code => {
      if (code === 0)
        Quickshell.execDetached(["notify-send", "-a", "Gravação", "Gravação salva", root.file.replace(Quickshell.env("HOME"), "~")]);
      else
        Quickshell.execDetached(["notify-send", "-a", "Gravação", "-u", "critical", "A gravação falhou", "gpu-screen-recorder saiu com código " + code]);
    }
  }
  Timer {
    interval: 1000
    repeat: true
    running: proc.running
    onTriggered: root.elapsed++
  }
}
