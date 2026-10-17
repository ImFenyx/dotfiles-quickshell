import QtQuick
import QtQuick.Layouts
import qs.components
import qs.services

// SSID + icone de sinal. Clique abre o NetMenu.
RowLayout {
  id: root

  property var tip: null
  signal clicked

  spacing: 5

  UiText {
    color: Wifi.on ? Theme.text : Theme.overlay0
    font.weight: Font.DemiBold
    text: Wifi.name

    TipArea {
      anchors.fill: parent
      tipWindow: root.tip
      tipText: Wifi.strength === "" ? Wifi.name : Wifi.name + " \u00b7 " + Wifi.strength
      onTipRequested: Wifi.refresh()
      onClicked: {
        if (root.tip)
          root.tip.hide();
        root.clicked();
      }
    }
  }
  Glyph {
    visible: Wifi.icon !== ""
    color: Wifi.on ? Theme.text : Theme.overlay0
    text: Wifi.icon
  }
}
