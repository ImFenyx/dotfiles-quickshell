import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import qs.components

// Uma linha de menu do tray (DBusMenu): separador, ou icone + texto + check
// + seta. A abertura de submenu e decidida por quem usa (sinais abaixo).
Item {
  id: row

  required property var entry
  property bool active: false      // submenu desta linha esta aberto (fica destacada)
  property var popup: null

  signal hovered
  signal unhovered
  signal submenuClicked

  Layout.fillWidth: true
  implicitHeight: entry.isSeparator ? 9 : 32

  Rectangle {
    visible: row.entry.isSeparator
    anchors.centerIn: parent
    width: parent.width
    height: 1
    color: Theme.surface1
  }
  Rectangle {
    visible: !row.entry.isSeparator
    anchors.fill: parent
    radius: 8
    color: (row.active || (area.containsMouse && row.entry.enabled)) ? Theme.surface1 : "transparent"
  }
  RowLayout {
    visible: !row.entry.isSeparator
    anchors.fill: parent
    anchors.leftMargin: 10
    anchors.rightMargin: 10
    spacing: 8
    IconImage {
      visible: (row.entry.icon || "") !== ""
      Layout.preferredWidth: 16
      Layout.preferredHeight: 16
      asynchronous: true
      source: row.entry.icon || ""
    }
    UiText {
      Layout.fillWidth: true
      color: row.entry.enabled ? Theme.text : Theme.overlay0
      elide: Text.ElideRight
      text: row.entry.text || ""
    }
    Glyph {
      visible: row.entry.buttonType !== 0 && row.entry.checkState === 2
      text: Icons.check
    }
    Glyph {
      visible: row.entry.hasChildren
      text: Icons.chevronRight
    }
  }
  MouseArea {
    id: area
    anchors.fill: parent
    enabled: !row.entry.isSeparator && row.entry.enabled
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onEntered: row.hovered()
    onExited: row.unhovered()
    onClicked: {
      if (row.entry.hasChildren) {
        row.submenuClicked();
      } else {
        row.entry.triggered();
        if (row.popup)
          row.popup.close();
      }
    }
  }
}
