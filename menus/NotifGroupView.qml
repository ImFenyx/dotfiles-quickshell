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
      duration: Theme.animMove
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
        radius: Theme.shape.sm
        color: Theme.surfaceContainerHighest
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
          color: Theme.primary
          font.pixelSize: Theme.type.label_m
          font.weight: Font.Bold
          text: root.group.appName.length > 0 ? root.group.appName.charAt(0).toUpperCase() : "?"
        }
      }
      UiText {
        font.pixelSize: Theme.type.body_m
        font.weight: Font.Bold
        elide: Text.ElideRight
        Layout.maximumWidth: 180
        textFormat: Text.PlainText
        text: root.group.appName
      }
      Rectangle {
        implicitWidth: countText.implicitWidth + 12
        implicitHeight: 18
        radius: height / 2
        color: root.group.urgency === 2 ? Theme.error : Theme.surfaceContainerHighest
        UiText {
          id: countText
          anchors.centerIn: parent
          color: root.group.urgency === 2 ? Theme.fgError : Theme.fgSurfaceVariant
          font.pixelSize: Theme.type.label_m
          font.weight: Font.Bold
          text: root.group.count
        }
      }
      Item {
        Layout.fillWidth: true
      }
      Rectangle {
        Layout.preferredWidth: 24
        Layout.preferredHeight: 24
        radius: height / 2
        color: "transparent"
        StateLayer { hovered: toggleArea.containsMouse; pressed: toggleArea.pressed }
        Glyph {
          anchors.centerIn: parent
          color: Theme.fgSurfaceVariant
          font.pixelSize: Theme.icon.s
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
        radius: height / 2
        color: "transparent"
        StateLayer { hovered: clearArea.containsMouse; pressed: clearArea.pressed }
        Glyph {
          anchors.centerIn: parent
          color: Theme.fgSurfaceVariant
          font.pixelSize: Theme.icon.s
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
        radius: Theme.shape.md
        color: Theme.surfaceContainer
        opacity: 0.75
      }
      Rectangle {
        visible: !root.open && root.group.count > 2
        x: 16
        y: cards.implicitHeight - 8
        width: parent.width - 32
        height: 24
        radius: Theme.shape.md
        color: Theme.surfaceContainer
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
            duration: Theme.animNormal
          }
        }

        Repeater {
          // recolhido: so o primeiro cartao existe (os outros nao ficam instanciados ocultos)
          model: ScriptModel {
            values: root.open ? root.group.items : root.group.items.slice(0, 1)
          }
          delegate: NotifCard {
            required property var modelData
            width: cards.width
            item: modelData
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
