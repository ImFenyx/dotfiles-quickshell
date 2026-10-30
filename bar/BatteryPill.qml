import QtQuick
import qs.components
import qs.services

Pill {
  id: root

  property var tip: null

  visible: Battery.present
  color: Battery.percent <= 20 ? Theme.error : (Battery.percent <= 40 ? Theme.warning : Theme.success)
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
