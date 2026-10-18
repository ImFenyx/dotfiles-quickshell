import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.components
import qs.services

// Centro de notificacoes: aba colada no filete direito (PopupBase.fromRight),
// aberta pelo sino. De cima para baixo:
//   status bar (hora, data, indicadores) e atalhos rapidos
//   lista de notificacoes (rola; "Limpar" apaga tudo)
//   cartao de midia (so quando algo esta tocando)
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

  // o que sobra para a lista: janela - topo - respiro do fundo (filete + dobra)
  // - molduras da aba - os outros blocos
  readonly property real chrome: status.implicitHeight + tiles.implicitHeight + head.implicitHeight + (media.visible ? media.implicitHeight : 0) + spacing * (media.visible ? 4 : 3)
  readonly property real listMax: Math.max(120, root.height - topY - 24 - padTop - padBottom - chrome)

  function toggle() {
    if (open)
      close();
    else
      open = true;
  }

  // abriu = viu: os toasts pendentes saem
  onOpenChanged: {
    if (open)
      Notifs.hidePopups();
  }

  NotifStatusBar {
    id: status
  }

  RowLayout {
    id: tiles
    Layout.fillWidth: true
    spacing: 8

    NotifQuickTile {
      icon: Notifs.dnd ? Icons.bellSlash : Icons.bell
      label: "Não perturbe"
      active: Notifs.dnd
      onClicked: Notifs.toggleDnd()
    }
    NotifQuickTile {
      icon: Wifi.on ? Icons.netWifi : Icons.wifiOff
      label: "Wi-Fi"
      active: Wifi.on
      onClicked: Quickshell.execDetached(["nmcli", "radio", "wifi", Wifi.on ? "off" : "on"])
    }
    NotifQuickTile {
      icon: Audio.muted ? Icons.volumeMuted : Icons.volumeDefault
      label: "Mudo"
      active: Audio.muted
      onClicked: {
        if (Audio.sinkOk)
          Audio.sink.audio.muted = !Audio.sink.audio.muted;
      }
    }
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
          text: "Limpar"
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

  // vazio
  ColumnLayout {
    visible: Notifs.total === 0
    Layout.fillWidth: true
    Layout.preferredHeight: 110
    spacing: 8
    Item {
      Layout.fillHeight: true
    }
    Glyph {
      Layout.alignment: Qt.AlignHCenter
      color: Theme.overlay0
      font.pointSize: 22
      text: Notifs.dnd ? Icons.bellSlash : Icons.bell
    }
    UiText {
      Layout.alignment: Qt.AlignHCenter
      color: Theme.overlay0
      text: Notifs.dnd ? "Não perturbe ligado" : "Nenhuma notificação"
    }
    Item {
      Layout.fillHeight: true
    }
  }

  ListView {
    id: list
    visible: Notifs.total > 0
    Layout.fillWidth: true
    Layout.preferredHeight: Math.min(contentHeight, root.listMax)
    clip: true
    spacing: 8
    cacheBuffer: 2000
    boundsBehavior: Flickable.StopAtBounds

    model: ScriptModel {
      values: Notifs.list
    }
    delegate: NotifCard {
      required property var modelData
      width: list.width
      item: modelData
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
    visible: Media.has
  }
}
