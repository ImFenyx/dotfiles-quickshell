import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import qs.components

// Uma linha do menu do tray (DBusMenu): separador, ou icone + texto +
// check + seta. indent = nivel do submenu (recuo de 16px por nivel).
Item {
  id: row

  required property var entry
  property int indent: 0
  property bool expanded: false
  property var popup: null
  signal expandToggled

  Layout.fillWidth: true
  implicitHeight: entry.isSeparator ? 9 : (indent === 0 ? 32 : 30)

  Rectangle {
    visible: row.entry.isSeparator
    anchors.centerIn: parent
    width: parent.width - 16 * row.indent
    height: 1
    color: Theme.surface1
  }
  Rectangle {
    visible: !row.entry.isSeparator
    anchors.fill: parent
    anchors.leftMargin: 16 * row.indent
    radius: 8
    color: area.containsMouse && row.entry.enabled ? Theme.surface1 : "transparent"
  }
  RowLayout {
    visible: !row.entry.isSeparator
    anchors.fill: parent
    anchors.leftMargin: 10 + 16 * row.indent
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
      text: row.expanded ? Icons.chevronDown : Icons.chevronRight
    }
  }
  MouseArea {
    id: area
    anchors.fill: parent
    enabled: !row.entry.isSeparator && row.entry.enabled
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: {
      if (row.entry.hasChildren) {
        row.expandToggled();
      } else {
        row.entry.triggered();
        if (row.popup)
          row.popup.close();
      }
    }
  }
}
