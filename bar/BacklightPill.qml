import QtQuick
import qs.components
import qs.services

Pill {
  id: root

  property var tip: null

  color: Theme.tertiary
  spacing: 5
  tipWindow: root.tip
  tipText: "Brilho " + Brightness.text

  PillText {
    font.weight: Font.DemiBold // mais leve que as outras pills
    text: Brightness.text
  }
  PillGlyph {
    visible: Brightness.icon !== ""
    font.weight: Font.Normal
    text: Brightness.icon
  }
}
