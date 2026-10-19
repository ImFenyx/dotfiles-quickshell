import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.components
import qs.services

// Um grupo de notificacoes do mesmo app (estilo macOS). Com uma so, e o
// proprio cartao. Com varias: recolhido mostra a mais importante/recente com
// a "pilha" aparecendo por tras (clique expande; arrastar dispensa o grupo);
// expandido mostra todas, com cabecalho (recolher, limpar o app).
Item {
  id: root

  required property var group             // NotifGroup
  readonly property bool multi: group.count > 1
  readonly property bool open: group.expanded || !multi
  readonly property int stackPad: 12      // quanto a pilha aparece embaixo do cartao

  implicitHeight: col.implicitHeight
  clip: true

  Behavior on implicitHeight {
    NumberAnimation {
      duration: 180
      easing.type: Easing.OutCubic
    }
  }

  ColumnLayout {
    id: col
    width: root.width
    spacing: 6

    // cabecalho do app (so com mais de uma)
    RowLayout {
      visible: root.multi
      Layout.fillWidth: true
      Layout.leftMargin: 4
      spacing: 8

      ClippingRectangle {
        Layout.preferredWidth: 20
        Layout.preferredHeight: 20
        radius: 6
        color: Theme.surface1
        Image {
          anchors.fill: parent
          visible: root.group.icon !== "" && status === Image.Ready
          source: root.group.icon
          fillMode: Image.PreserveAspectCrop
          asynchronous: true
          sourceSize.width: 40
          sourceSize.height: 40
        }
        UiText {
          anchors.centerIn: parent
          visible: root.group.icon === ""
          color: Theme.mauve
          font.pointSize: 9
          font.weight: Font.DemiBold
          text: root.group.appName.length > 0 ? root.group.appName.charAt(0).toUpperCase() : "?"
        }
      }
      UiText {
        font.pointSize: 10
        font.weight: Font.DemiBold
        elide: Text.ElideRight
        Layout.maximumWidth: 180
        text: root.group.appName
      }
      Rectangle {
        implicitWidth: countText.implicitWidth + 12
        implicitHeight: 18
        radius: 9
        color: root.group.urgency === 2 ? Theme.red : Theme.surface1
        UiText {
          id: countText
          anchors.centerIn: parent
          color: root.group.urgency === 2 ? Theme.base : Theme.subtext0
          font.pointSize: 9
          font.weight: Font.DemiBold
          text: root.group.count
        }
      }
      Item {
        Layout.fillWidth: true
      }
      Rectangle {
        Layout.preferredWidth: 24
        Layout.preferredHeight: 24
        radius: 12
        color: toggleArea.containsMouse ? Theme.surface1 : "transparent"
        Glyph {
          anchors.centerIn: parent
          color: Theme.subtext0
          font.pointSize: 10
          text: root.open ? Icons.chevronUp : Icons.chevronDown
        }
        MouseArea {
          id: toggleArea
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: root.group.expanded = !root.group.expanded
        }
      }
      Rectangle {
        Layout.preferredWidth: 24
        Layout.preferredHeight: 24
        radius: 12
        color: clearArea.containsMouse ? Theme.surface1 : "transparent"
        Glyph {
          anchors.centerIn: parent
          color: Theme.subtext0
          font.pointSize: 10
          text: Icons.trash
        }
        MouseArea {
          id: clearArea
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: Notifs.dismissGroup(root.group)
        }
      }
    }

    // cartoes (+ pilha por tras quando recolhido)
    Item {
      Layout.fillWidth: true
      Layout.preferredHeight: cards.implicitHeight + (root.open ? 0 : root.stackPad)

      Rectangle {
        visible: !root.open
        x: 8
        y: cards.implicitHeight - 14
        width: parent.width - 16
        height: 24
        radius: 14
        color: Theme.surface0
        opacity: 0.75
      }
      Rectangle {
        visible: !root.open && root.group.count > 2
        x: 16
        y: cards.implicitHeight - 8
        width: parent.width - 32
        height: 24
        radius: 14
        color: Theme.surface0
        opacity: 0.45
      }

      Column {
        id: cards
        width: parent.width
        spacing: 8

        add: Transition {
          NumberAnimation {
            property: "opacity"
            from: 0
            to: 1
            duration: 160
          }
        }

        Repeater {
          model: ScriptModel {
            values: root.group.items
          }
          delegate: NotifCard {
            required property int index
            required property var modelData
            width: cards.width
            item: modelData
            visible: root.open || index === 0
            // pilha recolhida: o swipe leva o grupo todo
            autoDismiss: root.open
            onSwiped: {
              if (!root.open)
                Notifs.dismissGroup(root.group);
            }
            onBodyClicked: {
              if (root.multi && !root.open)
                root.group.expanded = true;
            }
          }
        }
      }

      // clicar na pilha expande
      MouseArea {
        visible: !root.open
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: root.stackPad + 6
        cursorShape: Qt.PointingHandCursor
        onClicked: root.group.expanded = true
      }
    }
  }
}
