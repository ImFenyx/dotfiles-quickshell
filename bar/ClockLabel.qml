import QtQuick
import Quickshell.Io
import qs.components
import qs.services

// Relogio + tooltip com o calendario (cal, monoespacado).
UiText {
  id: root

  property var tip: null
  property string calText: ""
  property string calDay: ""       // dia do ultimo cal (so muda 1x por dia)

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
    // relê o cal no hover, so se o dia virou
    onTipRequested: {
      const d = Time.date.toDateString();
      if (d !== root.calDay) {
        root.calDay = d;
        calProc.running = true;
      }
    }
  }
}
