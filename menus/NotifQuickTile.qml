import QtQuick
import QtQuick.Layouts
import qs.components

// Atalho rapido (estilo quick settings do Android/macOS): icone + rotulo,
// acende em mauve quando ativo.
Rectangle {
  id: root

  property string icon: ""
  property string label: ""
  property bool active: false
  signal clicked

  Layout.fillWidth: true
  Layout.preferredHeight: 54
  radius: 14
  color: active ? Theme.mauve : (area.containsMouse ? Theme.surface1 : Theme.surface0)

  Behavior on color {
    ColorAnimation {
      duration: 150
    }
  }

  ColumnLayout {
    anchors.centerIn: parent
    spacing: 3
    Glyph {
      Layout.alignment: Qt.AlignHCenter
      color: root.active ? Theme.base : Theme.mauve
      text: root.icon
    }
    UiText {
      Layout.alignment: Qt.AlignHCenter
      color: root.active ? Theme.base : Theme.text
      font.pointSize: 9
      text: root.label
    }
  }
  MouseArea {
    id: area
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: root.clicked()
  }
}
