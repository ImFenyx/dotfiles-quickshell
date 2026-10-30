import QtQuick
import qs.components
import qs.services

// Gravando (services/Recorder): ponto + tempo; pausado; ou replay armado.
// Clique: para e salva (replay: salva os ultimos segundos). Clique direito: pausa/retoma
// (replay: encerra).
Pill {
  id: root

  property var tip: null

  visible: Recorder.running
  color: Recorder.replaying ? Theme.tertiary : (Recorder.paused ? Theme.warning : Theme.error)
  clickable: true
  tipWindow: root.tip
  tipText: Recorder.replaying ? "Clique: salvar replay · direito: encerrar" : "Clique: parar e salvar · direito: " + (Recorder.paused ? "retomar" : "pausar")
  onClicked: Recorder.replaying ? Recorder.saveReplay() : Recorder.stop()

  PillText {
    text: Recorder.replaying ? "↺ replay" : (Recorder.paused ? "❚❚ " : "● ") + (Recorder.replaying ? "" : Recorder.elapsedText)
  }

  TapHandler {
    acceptedButtons: Qt.RightButton
    onTapped: Recorder.replaying ? Recorder.stop() : Recorder.togglePause()
  }
}
