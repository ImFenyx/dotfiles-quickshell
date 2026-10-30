pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Gravacao de tela (gpu-screen-recorder) com todas as opcoes da barra da tela de captura
// (ShellState rec*). Sinais: SIGINT para e salva (no replay, so para), SIGUSR1 salva o
// replay, SIGUSR2 pausa/retoma. O indicador da barra mostra o estado e o tempo.
Singleton {
  id: root

  readonly property bool running: proc.running
  readonly property bool replaying: running && replayMode
  readonly property bool recording: running && !replayMode
  property bool replayMode: false
  property bool paused: false
  property int elapsed: 0
  property string file: ""
  readonly property string dir: ShellState.recDir || Quickshell.env("HOME") + "/Vídeos"
  readonly property string elapsedText: Math.floor(elapsed / 60) + ":" + String(elapsed % 60).padStart(2, "0")

  // webcam no canto (so tela inteira): halign/valign do gpu-screen-recorder
  readonly property var webcamPos: ({
      br: "halign=end;valign=end",
      bl: "halign=start;valign=end",
      tr: "halign=end;valign=start",
      tl: "halign=start;valign=start"
    })

  function startMonitor(name) {
    const cam = ShellState.recWebcam;
    run([cam !== "none" && webcamPos[cam] ? name + "|v4l2:/dev/video0;" + webcamPos[cam] + ";width=25%;height=25%" : name]);
  }
  // coordenadas globais (layout do Hyprland); encoder pede lados pares
  function startRegion(x, y, w, h) {
    run(["region", "-region", (w - w % 2) + "x" + (h - h % 2) + "+" + x + "+" + y]);
  }

  function args(capture) {
    const S = ShellState;
    let a = ["-w"].concat(capture);
    if (S.recEncoder === "cpu")
      a = a.concat(["-encoder", "cpu", "-k", "h264"]);
    else if (S.recCodec !== "auto")
      a = a.concat(["-k", S.recCodec]);
    const q = String(S.recQuality);
    a = a.concat(q.startsWith("cbr:") ? ["-bm", "cbr", "-q", q.slice(4)] : ["-q", q]);
    a = a.concat(["-f", String(S.recFps), "-fm", S.recFpsMode, "-cr", S.recColor, "-keyint", String(S.recKeyint), "-cursor", S.recCursor ? "yes" : "no"]);
    if (S.recScale !== "0x0")
      a = a.concat(["-s", S.recScale]);
    const audio = [S.recSys, S.recMic, S.recApp !== "" ? "app:" + S.recApp : ""].filter(x => x !== "");
    if (audio.length > 0)
      a = a.concat(["-a", audio.join("|"), "-ac", S.recAudioCodec, "-ab", String(S.recAudioBitrate)]);
    if (S.recReplay > 0)
      return a.concat(["-r", String(S.recReplay), "-replay-storage", S.recReplayStorage, "-c", S.recFormat, "-o", dir]);
    file = dir + "/gravacao_" + Qt.formatDateTime(new Date(), "yyyy-MM-dd_HH-mm-ss") + "." + S.recFormat;
    return a.concat(["-o", file]);
  }
  function run(capture) {
    if (proc.running)
      return;
    replayMode = ShellState.recReplay > 0;
    paused = false;
    elapsed = 0;
    proc.command = ["sh", "-c", 'mkdir -p "$1" && shift && exec gpu-screen-recorder "$@"', "sh", dir].concat(args(capture));
    proc.running = true;
  }
  function stop() {
    if (proc.running)
      proc.signal(2);
  }
  function togglePause() {
    if (!recording)
      return;
    proc.signal(12);
    paused = !paused;
  }
  function saveReplay() {
    if (!replaying)
      return;
    proc.signal(10);
    Quickshell.execDetached(["notify-send", "-a", "Gravação", "Replay salvo", "Últimos " + ShellState.recReplay + " s em " + dir.replace(Quickshell.env("HOME"), "~")]);
  }

  Process {
    id: proc
    onExited: code => {
      if (root.replayMode)
        Quickshell.execDetached(["notify-send", "-a", "Gravação", "Replay encerrado"]);
      else if (code === 0)
        Quickshell.execDetached(["notify-send", "-a", "Gravação", "Gravação salva", root.file.replace(Quickshell.env("HOME"), "~")]);
      else
        Quickshell.execDetached(["notify-send", "-a", "Gravação", "-u", "critical", "A gravação falhou", "gpu-screen-recorder saiu com código " + code]);
    }
  }
  Timer {
    interval: 1000
    repeat: true
    running: proc.running && !root.paused
    onTriggered: root.elapsed++
  }
}
