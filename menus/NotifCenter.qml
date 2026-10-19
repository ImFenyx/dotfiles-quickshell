import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.components
import qs.services

// Centro de notificacoes: aba colada no filete direito (PopupBase.fromRight),
// aberta pelo sino. De cima para baixo:
//   atalhos (Wi-Fi, Bluetooth, nao perturbe...)  = a "status bar"
//   notificacoes agrupadas por app (prioridade > cronologia; rola; "Limpar")
//   cartao de midia (so enquanto algo toca)
// A altura acompanha o conteudo ate o fundo da tela.
PopupBase {
  id: root

  fromRight: true
  topY: Theme.sideTabTop
  panelWidth: Theme.sideTabW + Theme.edge
  panelX: root.width - panelWidth
  // topo e base incluem a orelha da concordancia com o filete (EdgeTab.ear)
  padTop: Theme.scoop + 14
  padBottom: Theme.scoop + 14
  padX: 14
  padRight: Theme.edge + 14
  spacing: 10
  // digitando uma resposta: o foco e do campo de texto (como na senha do NetMenu)
  backdropFocus: !Notifs.list.some(n => n.replying)

  // Midia so aparece tocando. Se voce pausar com o centro aberto ela fica ate
  // fechar (senao o cartao sumiria debaixo do mouse e nao daria p/ retomar).
  property bool mediaSticky: false
  readonly property bool showMedia: Media.playing || mediaSticky

  // o que sobra para a lista: janela - topo - respiro do fundo (filete + dobra)
  // - molduras da aba - os outros blocos
  readonly property real chrome: status.implicitHeight + head.implicitHeight + (media.visible ? media.implicitHeight : 0) + spacing * (media.visible ? 3 : 2)
  readonly property real listMax: Math.max(120, root.height - topY - 24 - padTop - padBottom - chrome)

  function toggle() {
    if (open)
      close();
    else
      open = true;
  }

  // abriu = viu: os toasts pendentes saem
  onOpenChanged: {
    if (open) {
      Notifs.hidePopups();
      mediaSticky = Media.playing;
      Energy.refresh();
      NightLight.refresh();
    } else {
      mediaSticky = false;
    }
  }

  Connections {
    target: Media
    function onPlayingChanged() {
      if (Media.playing)
        root.mediaSticky = true;
    }
  }

  NotifStatusBar {
    id: status
  }

  RowLayout {
    id: head
    Layout.fillWidth: true
    Layout.topMargin: 4
    spacing: 8

    UiText {
      font.pointSize: 12
      font.weight: Font.DemiBold
      text: "Notificações"
    }
    UiText {
      visible: Notifs.total > 0
      color: Theme.subtext0
      text: Notifs.total
    }
    Item {
      Layout.fillWidth: true
    }
    Rectangle {
      visible: Notifs.total > 0
      implicitWidth: clearRow.implicitWidth + 20
      implicitHeight: 26
      radius: 13
      color: clearArea.containsMouse ? Theme.surface1 : Theme.surface0
      RowLayout {
        id: clearRow
        anchors.centerIn: parent
        spacing: 6
        Glyph {
          color: Theme.subtext0
          font.pointSize: 9
          text: Icons.trash
        }
        UiText {
          color: Theme.subtext0
          font.pointSize: 9
          text: "Limpar tudo"
        }
      }
      MouseArea {
        id: clearArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Notifs.clearAll()
      }
    }
  }

  // vazio (centralizado na largura do painel)
  Item {
    visible: Notifs.total === 0
    Layout.fillWidth: true
    Layout.preferredHeight: 110

    Column {
      anchors.centerIn: parent
      spacing: 8
      Glyph {
        anchors.horizontalCenter: parent.horizontalCenter
        color: Theme.overlay0
        font.pointSize: 22
        text: Notifs.dnd ? Icons.bellSlash : Icons.bell
      }
      UiText {
        anchors.horizontalCenter: parent.horizontalCenter
        color: Theme.overlay0
        text: Notifs.dnd ? "Não perturbe ligado" : "Nenhuma notificação"
      }
    }
  }

  ListView {
    id: list
    visible: Notifs.total > 0
    Layout.fillWidth: true
    Layout.preferredHeight: Math.min(contentHeight, root.listMax)
    clip: true
    spacing: 10
    cacheBuffer: 2000
    boundsBehavior: Flickable.StopAtBounds

    model: ScriptModel {
      values: Notifs.groups
    }
    delegate: NotifGroupView {
      required property var modelData
      width: list.width
      group: modelData
    }

    add: Transition {
      NumberAnimation {
        property: "opacity"
        from: 0
        to: 1
        duration: 160
      }
    }
    remove: Transition {
      ParallelAnimation {
        NumberAnimation {
          property: "opacity"
          to: 0
          duration: 140
        }
        NumberAnimation {
          property: "x"
          to: list.width / 2
          duration: 140
        }
      }
    }
    displaced: Transition {
      NumberAnimation {
        property: "y"
        duration: 180
        easing.type: Easing.OutCubic
      }
    }
  }

  NotifMedia {
    id: media
    visible: root.showMedia && Media.has
  }
}
