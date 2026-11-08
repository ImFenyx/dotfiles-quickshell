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
  radius: Theme.shape.md
  color: active ? Theme.primary : Theme.surfaceContainer
  StateLayer { hovered: area.containsMouse; pressed: area.pressed; tint: root.active ? Theme.fgPrimary : Theme.fgSurface }

  Behavior on color {
    ColorAnimation {
      duration: Theme.animNormal
    }
  }

  ColumnLayout {
    anchors.centerIn: parent
    width: parent.width - 12
    spacing: 2
    Glyph {
      Layout.alignment: Qt.AlignHCenter
      color: root.active ? Theme.fgPrimary : Theme.primary
      text: root.icon
    }
    UiText {
      Layout.fillWidth: true
      horizontalAlignment: Text.AlignHCenter
      color: root.active ? Theme.fgPrimary : Theme.fgSurface
      font.pixelSize: Theme.type.label_m
      fontSizeMode: Text.HorizontalFit
      minimumPointSize: 7
      text: root.label
    }
    UiText {
      Layout.fillWidth: true
      visible: root.sub !== ""
      horizontalAlignment: Text.AlignHCenter
      color: root.active ? Theme.fgPrimary : Theme.fgSurfaceVariant
      font.pixelSize: Theme.type.label_s
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
