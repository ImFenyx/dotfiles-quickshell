pragma Singleton

import Quickshell
import Quickshell.Services.Pipewire
import QtQuick
import qs.components

// Audio nativo via PipeWire (substitui wpctl + pactl subscribe + audioProc).
// Sem processos, reativo, e sem o bug de "sink-input" disparar refresh nem de
// o monitor morrer sem voltar.
//
// OSD de volume: so depois de "primed" (1s apos o sink ficar pronto), p/ nao
// mostrar OSD na partida. OSD do mic: so quando pedido via IPC (showMic).
//
// Protecao de volume (ShellState.volumeGuard, liga no mixer), so na saida padrao.
// O PipeWire nao diz quem mudou o volume, entao a regra e pelo tamanho do passo:
// subiu mais que Config.volumeGuardStep (%) de uma vez -> volta ao nivel anterior
// (app, pactl, porta/dispositivo novo ou troca de padrao: o nivel anterior e o do
// que saiu). As teclas (wpctl, 5% por vez) passam; o slider/roda do mixer passam
// por setVolume (janela `own`). Descer e mudo nunca. Config.volumeGuardMax = teto.
Singleton {
  id: root

  readonly property var sink: Pipewire.defaultAudioSink
  readonly property var source: Pipewire.defaultAudioSource
  readonly property bool sinkOk: !!sink && sink.ready && !!sink.audio
  readonly property bool sourceOk: !!source && source.ready && !!source.audio

  // ---- bar ----
  readonly property int volume: sinkOk ? Math.round(sink.audio.volume * 100) : 0
  readonly property bool muted: sinkOk ? sink.audio.muted : false
  readonly property string sinkText: !sinkOk ? "--" : (muted ? "mut" : volume + "%")
  readonly property string sinkIcon: (!sinkOk || muted) ? "" : Icons.level(volume, Icons.volume)
  readonly property string micText: sourceOk ? Math.round(source.audio.volume * 100) + "%" : ""
  readonly property bool micVisible: micText !== ""

  // ---- mixer (menus/AudioMenu) ----
  // dispositivos de saida/entrada e apps tocando (streams de saida; os de captura,
  // tipo um app gravando o mic, ficam de fora). Quem mostra rastreia os nos.
  readonly property var sinks: Pipewire.nodes.values.filter(n => n.audio && n.isSink && !n.isStream)
  readonly property var sources: Pipewire.nodes.values.filter(n => n.audio && !n.isSink && !n.isStream)
  readonly property var streams: Pipewire.nodes.values.filter(n => n.audio && n.isSink && n.isStream)
  property bool osdSuppressed: false   // mixer aberto: o slider ja mostra o volume

  // volume pela propria shell (mixer): a protecao nao reverte o salto
  function setVolume(n, v) {
    if (n === sink)
      own.restart();
    n.audio.volume = v;
  }
  function setSink(n) {
    Pipewire.preferredDefaultAudioSink = n;
  }
  function setSource(n) {
    Pipewire.preferredDefaultAudioSource = n;
  }
  function deviceName(n) {
    return n.description || n.nickname || n.name;
  }
  function appName(n) {
    const p = n.properties || {};
    return p["application.name"] || n.description || n.name;
  }
  function appIcon(n) {
    const p = n.properties || {};
    return Quickshell.iconPath(p["application.icon-name"] || p["application.process.binary"] || "", "audio-x-generic");
  }

  // ---- protecao de volume ----
  readonly property bool guard: ShellState.ready && ShellState.volumeGuard
  property int guardLast: -1        // ultimo nivel aceito (%); -1 = ainda nao sabe (partida)
  property real guardNoted: 0       // hora do ultimo aviso (segurar a tecla no teto nao vira rajada)

  function toggleGuard() {
    ShellState.volumeGuard = !ShellState.volumeGuard;
  }
  // true = corrigiu o volume: o OSD espera o evento do valor corrigido
  function guardCheck() {
    if (!sink || !sink.ready || !sink.audio)
      return false;
    const v = sink.audio.volume;
    if (isNaN(v))   // no recriado/voltando do suspend sem canais: espera o valor real
      return false;
    const vp = Math.round(v * 100);
    let tp = vp;
    if (guard) {
      if (guardLast >= 0 && !own.running && vp - guardLast > Config.volumeGuardStep)
        tp = guardLast;
      if (Config.volumeGuardMax > 0)
        tp = Math.min(tp, Config.volumeGuardMax);
    }
    guardLast = tp;   // desligada: so acompanha, p/ religar sem salto velho
    if (tp >= vp)
      return false;
    sink.audio.volume = tp / 100;
    if (Date.now() - guardNoted > 3000) {
      guardNoted = Date.now();
      Quickshell.execDetached(["notify-send", "-a", "Volume", "-u", "low", "-e", "-t", "4000", "-h", "string:x-canonical-private-synchronous:volume-guard", "-i", "audio-volume-high", "Volume limitado", "Ia para " + vp + "%, ficou em " + tp + "%"]);
    }
    return true;
  }

  // ---- OSD ----
  signal sinkShown(int pct, bool muted, string icon)
  signal sourceShown(int pct, bool muted, string icon)

  property bool sinkPrimed: false
  property bool micArmed: false

  // chamado pelo atalho de mic (IPC): mostra o OSD no proximo evento do mic
  // ou, se nada mudar, com o estado atual apos 150ms
  function showMic() {
    micArmed = true;
    micArm.restart();
  }

  // Le direto de sink.audio (nao dos bindings acima: dentro do handler eles
  // ainda podem estar com o valor antigo).
  function noteSink() {
    if (!sinkPrimed || !sinkOk || osdSuppressed)
      return;
    const v = Math.round(sink.audio.volume * 100);
    const m = sink.audio.muted;
    sinkShown(v, m, m ? Icons.volumeMuted : (Icons.level(v, Icons.volume) || Icons.volumeDefault));
  }
  function noteSource() {
    if (micArmed)
      emitMic();
  }
  function emitMic() {
    micArm.stop();
    if (!micArmed)
      return;
    micArmed = false;
    if (!sourceOk)
      return;
    sourceShown(Math.round(source.audio.volume * 100), source.audio.muted, Icons.mic);
  }

  onSinkOkChanged: {
    sinkPrimed = false;
    if (sinkOk)
      prime.restart();
    guardCheck();
  }
  onSinkChanged: guardCheck()   // troca de padrao com o novo ja pronto (sinkOk nao muda)
  onGuardChanged: guardCheck()  // religou: o teto vale ja

  PwObjectTracker {
    objects: [root.sink, root.source]
  }

  Connections {
    target: root.sinkOk ? root.sink.audio : null
    function onVolumeChanged() {
      if (!root.guardCheck())
        root.noteSink();
    }
    function onMutedChanged() {
      root.noteSink();
    }
  }
  Connections {
    target: root.sourceOk ? root.source.audio : null
    function onVolumeChanged() {
      root.noteSource();
    }
    function onMutedChanged() {
      root.noteSource();
    }
  }

  Timer {
    id: prime
    interval: 1000
    onTriggered: root.sinkPrimed = true
  }
  Timer {
    id: own
    interval: 500   // setVolume -> evento (na 0.3.2 vem na hora; folga se virar assincrono)
  }
  Timer {
    id: micArm
    interval: 150
    onTriggered: root.emitMic()
  }
}
