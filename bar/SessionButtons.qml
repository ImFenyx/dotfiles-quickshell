import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.components

// Bloquear + menu de energia.
RowLayout {
  id: root

  signal powerClicked

  spacing: 14

  Glyph {
    color: Theme.lavender
    font.pointSize: 11
    font.weight: Font.DemiBold
    text: Icons.lock
    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      onClicked: Quickshell.execDetached(Config.locker)
    }
  }
  Glyph {
    color: Theme.red
    font.pointSize: 11
    font.weight: Font.DemiBold
    text: Icons.power
    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      onClicked: root.powerClicked()
    }
  }
}
