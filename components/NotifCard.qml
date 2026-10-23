import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets

// Cartao de uma notificacao (toast e lista do centro). `item` e um NotifItem.
// Arrastar para a direita dispensa. Clique no corpo roda a acao padrao do app;
// sem ela emite bodyClicked (quem usa decide: toast some, pilha expande).
// Botoes = demais acoes (ou icones, com o hint action-icons). Resposta inline
// so no centro (o toast nao recebe teclado).
Item {
  id: root

  required property var item
  property bool toast: false           // toast: hover pausa o timer, sem resposta inline
  property bool autoDismiss: true      // false: quem usa trata o swipe (pilha recolhida)

  signal swiped
  signal bodyClicked

  implicitHeight: card.implicitHeight

  Rectangle {
    id: card

    width: root.width
    implicitHeight: content.implicitHeight + 24
    height: implicitHeight
    radius: 14
    color: area.containsMouse ? Theme.surface1 : Theme.surface0
    border.width: root.item.urgency === 2 ? 1 : 0
    border.color: Theme.red
    // some conforme sai pela borda
    opacity: 1 - 0.8 * Math.min(1, x / Math.max(1, root.width))

    Behavior on color {
      ColorAnimation {
        duration: 120
      }
    }

    // deslizar p/ a direita (em direcao a borda) fecha
    DragHandler {
      id: drag
      target: card
      yAxis.enabled: false
      xAxis.minimum: 0
      xAxis.maximum: root.width
      onActiveChanged: {
        if (active)
          return;
        if (card.x > root.width * 0.28)
          leave.start();
        else
          back.start();
      }
    }
    NumberAnimation {
      id: back
      target: card
      property: "x"
      to: 0
      duration: 200
      easing.type: Easing.OutCubic
    }
    SequentialAnimation {
      id: leave
      NumberAnimation {
        target: card
        property: "x"
        to: root.width
        duration: 150
        easing.type: Easing.InCubic
      }
      ScriptAction {
        script: {
          root.swiped();
          if (root.autoDismiss)
            root.item.dismiss();
        }
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
      onClicked: {
        if (root.item.defaultAction)
          root.item.activate();
        else
          root.bodyClicked();
      }
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
            textFormat: Text.PlainText
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
          // spec: titulo e texto puro. AutoText viraria StyledText e um <img> remoto (titulo de site via navegador) seria baixado
          textFormat: Text.PlainText
          text: root.item.summary
        }
        UiText {
          Layout.fillWidth: true
          visible: text !== ""
          color: Theme.subtext0
          font.pointSize: 10
          textFormat: Text.StyledText
          linkColor: Theme.blue
          wrapMode: Text.Wrap
          maximumLineCount: root.toast ? 3 : 6
          elide: Text.ElideRight
          text: root.item.body
          onLinkActivated: link => Qt.openUrlExternally(link)
        }

        // imagem do corpo (so arquivo local)
        ClippingRectangle {
          Layout.fillWidth: true
          Layout.topMargin: 4
          Layout.preferredHeight: 110
          visible: root.item.bodyImage !== "" && bodyImg.status === Image.Ready
          radius: 10
          color: Theme.surface1
          Image {
            id: bodyImg
            anchors.fill: parent
            source: root.item.bodyImage
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            sourceSize.width: 600
          }
        }

        // progresso (hint "value": volume, brilho, download...)
        Rectangle {
          Layout.fillWidth: true
          Layout.topMargin: 4
          Layout.preferredHeight: 6
          visible: root.item.progress >= 0
          radius: 3
          color: Theme.surface1
          Rectangle {
            width: parent.width * root.item.progress / 100
            height: parent.height
            radius: 3
            color: Theme.mauve
          }
        }

        // botoes de acao do app (ou so o icone, com action-icons)
        Flow {
          Layout.fillWidth: true
          Layout.topMargin: 4
          spacing: 6
          visible: root.item.buttons.length > 0
          Repeater {
            model: root.item.buttons
            delegate: Rectangle {
              id: btn
              required property var modelData
              readonly property string iconSrc: root.item.actionIcons ? Quickshell.iconPath(modelData.id, true) : ""
              width: iconSrc !== "" ? 30 : label.implicitWidth + 20
              height: 26
              radius: 13
              color: btnArea.containsMouse ? Theme.mauve : Theme.surface1
              IconImage {
                anchors.centerIn: parent
                visible: btn.iconSrc !== ""
                implicitSize: 16
                source: btn.iconSrc
              }
              UiText {
                id: label
                anchors.centerIn: parent
                visible: btn.iconSrc === ""
                color: btnArea.containsMouse ? Theme.base : Theme.text
                font.pointSize: 9
                text: btn.modelData.text
              }
              MouseArea {
                id: btnArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  root.item.invoke(btn.modelData.action);
                  if (!root.item.resident)
                    root.item.dismiss();
                }
              }
            }
          }
        }

        // resposta inline (chat): so no centro
        Rectangle {
          Layout.fillWidth: true
          Layout.topMargin: 4
          Layout.preferredHeight: 32
          visible: root.item.hasReply && !root.toast
          radius: 16
          color: Theme.surface1
          border.width: input.activeFocus ? 1 : 0
          border.color: Theme.mauve

          TextInput {
            id: input
            anchors.left: parent.left
            anchors.right: sendBtn.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 12
            anchors.rightMargin: 6
            color: Theme.text
            font.family: Theme.uiFont
            font.pointSize: 10
            clip: true
            selectByMouse: true
            onAccepted: {
              root.item.reply(text);
              text = "";
            }
            onActiveFocusChanged: root.item.replying = activeFocus
            Keys.onEscapePressed: focus = false

            UiText {
              anchors.fill: parent
              visible: input.text === ""
              color: Theme.overlay0
              font.pointSize: 10
              verticalAlignment: Text.AlignVCenter
              text: root.item.replyHint !== "" ? root.item.replyHint : "Responder…"
            }
          }
          Glyph {
            id: sendBtn
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.rightMargin: 12
            color: input.text !== "" ? Theme.mauve : Theme.overlay0
            font.pointSize: 11
            text: Icons.send
            MouseArea {
              anchors.fill: parent
              anchors.margins: -6
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                root.item.reply(input.text);
                input.text = "";
              }
            }
          }
        }
      }
    }
  }
}
