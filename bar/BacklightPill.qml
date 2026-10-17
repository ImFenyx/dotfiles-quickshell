import QtQuick
import qs.components
import qs.services

Pill {
  id: root

  property var tip: null

  color: Theme.rosewater
  spacing: 5
  tipWindow: root.tip
  tipText: "Brilho " + Brightness.text
  onTipRequested: Brightness.refresh()

  PillText {
    text: Brightness.text
  }
  PillGlyph {
    visible: Brightness.icon !== ""
    font.weight: Font.Normal
    text: Brightness.icon
  }
}
