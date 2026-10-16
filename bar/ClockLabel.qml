import QtQuick
import Quickshell.Io
import qs.components
import qs.services

// Relogio + tooltip com o calendario (cal, monoespacado).
UiText {
  id: root

  property var tip: null
  property string calText: ""

  color: Theme.mauve
  font.bold: true
  text: Time.barText

  Process {
    id: calProc
    command: ["cal"]
    stdout: StdioCollector {
      onStreamFinished: root.calText = text.trim()
    }
  }

  TipArea {
    anchors.fill: parent
    tipWindow: root.tip
    mono: true
    tipText: root.calText === "" ? Time.longDate : root.calText
    // relê o cal a cada hover (so aqui; nao mais a cada 30min)
    onTipRequested: {
      calProc.running = false;
      calProc.running = true;
    }
  }
}
