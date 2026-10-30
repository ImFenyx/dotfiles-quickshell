import QtQuick
import qs.components
import qs.services

// Gravando (services/Recorder): ponto + tempo; clique para e salva.
Pill {
  id: root

  property var tip: null

  visible: Recorder.recording
  color: Theme.error
  clickable: true
  tipWindow: root.tip
  tipText: "Parar gravação"
  onClicked: Recorder.stop()

  PillText {
    text: "● " + Recorder.elapsedText
  }
}
