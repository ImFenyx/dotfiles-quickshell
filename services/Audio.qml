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
    if (!sinkPrimed || !sinkOk)
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
  }

  PwObjectTracker {
    objects: [root.sink, root.source]
  }

  Connections {
    target: root.sinkOk ? root.sink.audio : null
    function onVolumeChanged() {
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
    id: micArm
    interval: 150
    onTriggered: root.emitMic()
  }
}
