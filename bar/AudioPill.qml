import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.components
import qs.services

// Pill unica sink + mic (formato do waybar). Clique abre o mixer (AudioMenu,
// coordenado pelo shell.qml via Bar.audioMenuRequested).
Pill {
  id: root

  property var tip: null

  color: Theme.info
  spacing: 5
  tipWindow: root.tip
  tipText: "Saída " + Audio.sinkText + (Audio.micVisible ? " \u00b7 Entrada " + Audio.micText : "")
  clickable: true

  PillText {
    font.weight: Font.DemiBold // mais leve que as outras pills
    text: Audio.sinkText
  }
  PillGlyph {
    visible: Audio.sinkIcon !== ""
    text: Audio.sinkIcon
  }
  Item {
    visible: Audio.micVisible
    Layout.preferredWidth: 8
  }
  PillText {
    font.weight: Font.DemiBold // mais leve que as outras pills
    visible: Audio.micVisible
    text: Audio.micText
  }
  PillGlyph {
    visible: Audio.micVisible
    text: Icons.mic
  }
}
