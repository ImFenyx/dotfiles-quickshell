import QtQuick
import QtQuick.Layouts
import qs.components

// Atalho do centro (estilo quick settings do Android/macOS): icone, rotulo e
// uma linha de estado opcional. Acende em mauve quando ligado. Clique direito
// = `secondary` (abrir o app de configuracao).
Rectangle {
  id: root

  property string icon: ""
  property string label: ""
  property string sub: ""
  property bool active: false
  signal clicked
  signal secondary

  Layout.fillWidth: true
  Layout.preferredWidth: 1
  Layout.preferredHeight: 62
  radius: 14
  color: active ? Theme.mauve : (area.containsMouse ? Theme.surface1 : Theme.surface0)

  Behavior on color {
    ColorAnimation {
      duration: 150
    }
  }

  ColumnLayout {
    anchors.centerIn: parent
    width: parent.width - 12
    spacing: 2
    Glyph {
      Layout.alignment: Qt.AlignHCenter
      color: root.active ? Theme.base : Theme.mauve
      text: root.icon
    }
    UiText {
      Layout.fillWidth: true
      horizontalAlignment: Text.AlignHCenter
      color: root.active ? Theme.base : Theme.text
      font.pointSize: 9
      fontSizeMode: Text.HorizontalFit
      minimumPointSize: 7
      text: root.label
    }
    UiText {
      Layout.fillWidth: true
      visible: root.sub !== ""
      horizontalAlignment: Text.AlignHCenter
      color: root.active ? Theme.base : Theme.subtext0
      font.pointSize: 8
      elide: Text.ElideRight
      text: root.sub
    }
  }
  MouseArea {
    id: area
    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    cursorShape: Qt.PointingHandCursor
    onClicked: mouse => {
      if (mouse.button === Qt.RightButton)
        root.secondary();
      else
        root.clicked();
    }
  }
}
