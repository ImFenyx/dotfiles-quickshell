import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets

// Cartao de uma notificacao (toast e lista do centro). `item` e um NotifItem.
// Clique no corpo: acao padrao do app (se houver). Botoes = demais acoes.
Rectangle {
  id: root

  required property var item
  property bool toast: false           // toast: hover pausa o timer

  implicitHeight: content.implicitHeight + 24
  radius: 14
  color: area.containsMouse ? Theme.surface1 : Theme.surface0
  border.width: item.urgency === 2 ? 1 : 0
  border.color: Theme.red

  Behavior on color {
    ColorAnimation {
      duration: 120
    }
  }

  MouseArea {
    id: area
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: root.item.defaultAction ? Qt.PointingHandCursor : Qt.ArrowCursor
    onContainsMouseChanged: {
      if (root.toast)
        root.item.hovered = containsMouse;
    }
    onClicked: root.item.activate()
  }

  RowLayout {
    id: content
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.margins: 12
    spacing: 12

    // icone do app (ou a inicial dele)
    ClippingRectangle {
      Layout.alignment: Qt.AlignTop
      Layout.preferredWidth: 40
      Layout.preferredHeight: 40
      radius: 12
      color: Theme.surface1

      Image {
        anchors.fill: parent
        visible: root.item.icon !== "" && status === Image.Ready
        source: root.item.icon
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        sourceSize.width: 80
        sourceSize.height: 80
      }
      UiText {
        anchors.centerIn: parent
        visible: root.item.icon === ""
        color: Theme.mauve
        font.pointSize: 14
        font.weight: Font.DemiBold
        text: root.item.appName.length > 0 ? root.item.appName.charAt(0).toUpperCase() : "?"
      }
    }

    ColumnLayout {
      Layout.fillWidth: true
      spacing: 2

      // app · quando  (+ fechar)
      RowLayout {
        Layout.fillWidth: true
        spacing: 6
        UiText {
          Layout.fillWidth: true
          color: Theme.subtext0
          font.pointSize: 9
          elide: Text.ElideRight
          text: root.item.appName + "  \u00b7  " + root.item.ago
        }
        Rectangle {
          Layout.preferredWidth: 20
          Layout.preferredHeight: 20
          radius: 10
          opacity: (area.containsMouse || closeArea.containsMouse || root.toast) ? 1 : 0
          color: closeArea.containsMouse ? Theme.surface0 : "transparent"
          Behavior on opacity {
            NumberAnimation {
              duration: 120
            }
          }
          Glyph {
            anchors.centerIn: parent
            color: Theme.subtext0
            font.pointSize: 9
            text: Icons.close
          }
          MouseArea {
            id: closeArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.item.dismiss()
          }
        }
      }

      UiText {
        Layout.fillWidth: true
        visible: text !== ""
        font.weight: Font.DemiBold
        wrapMode: Text.Wrap
        maximumLineCount: 2
        elide: Text.ElideRight
        text: root.item.summary
      }
      UiText {
        Layout.fillWidth: true
        visible: text !== ""
        color: Theme.subtext0
        font.pointSize: 10
        textFormat: Text.StyledText
        wrapMode: Text.Wrap
        maximumLineCount: root.toast ? 3 : 4
        elide: Text.ElideRight
        text: root.item.body
      }

      // botoes de acao do app
      Flow {
        Layout.fillWidth: true
        Layout.topMargin: 4
        spacing: 6
        visible: root.item.buttons.length > 0
        Repeater {
          model: root.item.buttons
          delegate: Rectangle {
            required property var modelData
            width: label.implicitWidth + 20
            height: 26
            radius: 13
            color: btnArea.containsMouse ? Theme.mauve : Theme.surface1
            UiText {
              id: label
              anchors.centerIn: parent
              color: btnArea.containsMouse ? Theme.base : Theme.text
              font.pointSize: 9
              text: parent.modelData.text
            }
            MouseArea {
              id: btnArea
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                root.item.invoke(parent.modelData);
                if (!root.item.resident)
                  root.item.dismiss();
              }
            }
          }
        }
      }
    }
  }
}
