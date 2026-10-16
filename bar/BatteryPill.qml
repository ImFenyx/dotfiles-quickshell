import QtQuick
import qs.components
import qs.services

Pill {
  id: root

  property var tip: null

  visible: Battery.present
  color: Battery.percent <= 20 ? Theme.red : (Battery.percent <= 40 ? Theme.peach : Theme.green)
  spacing: 4
  tipWindow: root.tip
  tipText: Battery.tooltip

  PillText {
    text: String(Battery.percent)
  }
  PillGlyph {
    visible: Battery.charging
    text: Icons.plug
  }
}
