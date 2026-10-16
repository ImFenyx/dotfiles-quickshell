import QtQuick
import QtQuick.Layouts
import qs.components
import qs.services

// Contador + sino do swaync. O MouseArea fica fora do RowLayout.
Item {
  id: root

  implicitWidth: row.implicitWidth
  implicitHeight: row.implicitHeight

  RowLayout {
    id: row
    spacing: 4
    UiText {
      color: Theme.mauve
      font.weight: Font.DemiBold
      text: Notifs.count
    }
    Glyph {
      text: Icons.bell
    }
  }
  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: Notifs.toggle()
  }
}
