import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import qs.components

// Bloquear + menu de energia.
RowLayout {
  id: root

  signal powerClicked

  spacing: 14

  Glyph {
    color: Theme.secondary
    font.pixelSize: Theme.icon.s
    font.weight: Font.DemiBold
    text: Icons.lock
    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      // mesmo caminho do SUPER+O (atalho global do shell): sem processo
      onClicked: Hyprland.dispatch('hl.dsp.global("quickshell:lock")')
    }
  }
  Glyph {
    color: Theme.error
    font.pixelSize: Theme.icon.s
    font.weight: Font.DemiBold
    text: Icons.power
    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      onClicked: root.powerClicked()
    }
  }
}
