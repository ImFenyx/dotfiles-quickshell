import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import qs.components
import qs.services

// Cartao de midia do centro: o que estiver tocando (musica, video no mpv,
// aba do navegador...), com capa, progresso e controles. Quem decide o player
// e o servico Media.
Rectangle {
  id: root

  function fmt(sec) {
    const s = Math.max(0, Math.floor(sec));
    const h = Math.floor(s / 3600);
    const m = Math.floor((s % 3600) / 60);
    const r = s % 60;
    const mm = (h > 0 && m < 10 ? "0" : "") + m;
    return (h > 0 ? h + ":" : "") + mm + ":" + (r < 10 ? "0" : "") + r;
  }

  Layout.fillWidth: true
  implicitHeight: col.implicitHeight + 24
  radius: 16
  color: Theme.surface0

  // a posicao do MPRIS nao notifica: puxa a cada segundo (so tocando e visivel)
  Timer {
    interval: 1000
    repeat: true
    running: Media.playing && root.visible
    onTriggered: Media.tick()
  }

  ColumnLayout {
    id: col
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.margins: 12
    spacing: 10

    RowLayout {
      Layout.fillWidth: true
      spacing: 12

      ClippingRectangle {
        Layout.preferredWidth: 58
        Layout.preferredHeight: 58
        radius: 12
        color: Theme.surface1
        Image {
          anchors.fill: parent
          visible: Media.art !== "" && status === Image.Ready
          source: Media.art
          fillMode: Image.PreserveAspectCrop
          asynchronous: true
          sourceSize.width: 116
          sourceSize.height: 116
        }
        Glyph {
          anchors.centerIn: parent
          visible: Media.art === ""
          font.pointSize: 18
          color: Theme.overlay0
          text: Media.kindIcon
        }
      }

      ColumnLayout {
        Layout.fillWidth: true
        spacing: 1

        RowLayout {
          spacing: 6
          Glyph {
            color: Media.kind === "video" ? Theme.peach : Theme.green
            font.pointSize: 9
            text: Media.kindIcon
          }
          UiText {
            Layout.fillWidth: true
            color: Theme.subtext0
            font.pointSize: 9
            elide: Text.ElideRight
            text: Media.kindLabel + (Media.player !== "" ? "  \u00b7  " + Media.player : "")
          }
        }
        UiText {
          Layout.fillWidth: true
          font.weight: Font.DemiBold
          elide: Text.ElideRight
          text: Media.title !== "" ? Media.title : "Sem título"
        }
        UiText {
          Layout.fillWidth: true
          visible: Media.artist !== ""
          color: Theme.subtext0
          font.pointSize: 10
          elide: Text.ElideRight
          text: Media.artist
        }
      }

      // mais de um player: troca
      Rectangle {
        visible: Media.players.length > 1
        Layout.alignment: Qt.AlignTop
        Layout.preferredWidth: 24
        Layout.preferredHeight: 24
        radius: 12
        color: swapArea.containsMouse ? Theme.surface1 : "transparent"
        Glyph {
          anchors.centerIn: parent
          font.pointSize: 10
          color: Theme.subtext0
          text: Icons.chevronRight
        }
        MouseArea {
          id: swapArea
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: Media.cycle()
        }
      }
    }

    // progresso (so quando o player informa a duracao)
    ColumnLayout {
      Layout.fillWidth: true
      visible: Media.length > 0
      spacing: 3

      Item {
        Layout.fillWidth: true
        Layout.preferredHeight: 12
        Rectangle {
          anchors.verticalCenter: parent.verticalCenter
          width: parent.width
          height: 5
          radius: 3
          color: Theme.surface1
          Rectangle {
            width: parent.width * Math.min(1, Media.position / Media.length)
            height: parent.height
            radius: 3
            color: Theme.mauve
          }
        }
        MouseArea {
          anchors.fill: parent
          enabled: Media.canSeek
          cursorShape: Media.canSeek ? Qt.PointingHandCursor : Qt.ArrowCursor
          onClicked: mouse => Media.seek(mouse.x / width * Media.length)
        }
      }
      RowLayout {
        Layout.fillWidth: true
        UiText {
          color: Theme.subtext0
          font.pointSize: 9
          text: root.fmt(Media.position)
        }
        Item {
          Layout.fillWidth: true
        }
        UiText {
          color: Theme.subtext0
          font.pointSize: 9
          text: root.fmt(Media.length)
        }
      }
    }

    RowLayout {
      Layout.alignment: Qt.AlignHCenter
      spacing: 14

      Rectangle {
        Layout.preferredWidth: 36
        Layout.preferredHeight: 36
        radius: 18
        opacity: Media.canPrev ? 1 : 0.35
        color: prevArea.containsMouse ? Theme.surface1 : "transparent"
        Glyph {
          anchors.centerIn: parent
          color: Theme.text
          text: Icons.prev
        }
        MouseArea {
          id: prevArea
          anchors.fill: parent
          hoverEnabled: true
          enabled: Media.canPrev
          cursorShape: Qt.PointingHandCursor
          onClicked: Media.previous()
        }
      }
      Rectangle {
        Layout.preferredWidth: 44
        Layout.preferredHeight: 44
        radius: 22
        opacity: Media.canToggle ? 1 : 0.35
        color: playArea.containsMouse ? Theme.lavender : Theme.mauve
        Glyph {
          anchors.centerIn: parent
          color: Theme.base
          font.pointSize: 14
          text: Media.playing ? Icons.pause : Icons.play
        }
        MouseArea {
          id: playArea
          anchors.fill: parent
          hoverEnabled: true
          enabled: Media.canToggle
          cursorShape: Qt.PointingHandCursor
          onClicked: Media.togglePlaying()
        }
      }
      Rectangle {
        Layout.preferredWidth: 36
        Layout.preferredHeight: 36
        radius: 18
        opacity: Media.canNext ? 1 : 0.35
        color: nextArea.containsMouse ? Theme.surface1 : "transparent"
        Glyph {
          anchors.centerIn: parent
          color: Theme.text
          text: Icons.next
        }
        MouseArea {
          id: nextArea
          anchors.fill: parent
          hoverEnabled: true
          enabled: Media.canNext
          cursorShape: Qt.PointingHandCursor
          onClicked: Media.next()
        }
      }
    }
  }
}
