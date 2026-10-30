import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell.Widgets
import qs.components
import qs.services

// Tocando agora (MPRIS, services/Media), sem pill: capa redonda com anel de progresso
// + titulo solto. Anel e titulo apagam com a midia pausada. Clique toca/pausa, roda
// troca de faixa (cima = anterior), clique direito abre o centro (player completo).
// `room` = largura livre: o titulo encolhe para nao invadir o centro e some abaixo de
// 50 px; sem espaco nem para a capa, some tudo. O anel atualiza 1x/s so tocando.
Item {
  id: root

  property var tip: null
  property real room: 9999
  signal centerRequested

  readonly property real ring: 26
  readonly property real titleMax: room - ring - row.spacing
  readonly property real progress: Media.length > 0 ? Math.min(1, Media.position / Media.length) : 0

  visible: Media.has && room >= ring
  implicitWidth: row.implicitWidth
  implicitHeight: ring

  RowLayout {
    id: row
    anchors.verticalCenter: parent.verticalCenter
    spacing: Theme.space.sm

    Item {
      Layout.preferredWidth: root.ring
      Layout.preferredHeight: root.ring

      Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        // trilha
        ShapePath {
          fillColor: "transparent"
          strokeColor: Theme.surfaceContainerHighest
          strokeWidth: 2
          PathAngleArc {
            centerX: root.ring / 2
            centerY: root.ring / 2
            radiusX: root.ring / 2 - 1
            radiusY: root.ring / 2 - 1
            startAngle: -90
            sweepAngle: 360
          }
        }
        // progresso
        ShapePath {
          fillColor: "transparent"
          strokeColor: Media.playing ? Theme.primary : Theme.outline
          strokeWidth: 2
          capStyle: ShapePath.RoundCap
          PathAngleArc {
            centerX: root.ring / 2
            centerY: root.ring / 2
            radiusX: root.ring / 2 - 1
            radiusY: root.ring / 2 - 1
            startAngle: -90
            sweepAngle: 360 * root.progress
          }
        }
      }

      ClippingRectangle {
        anchors.centerIn: parent
        width: root.ring - 8
        height: width
        radius: width / 2
        color: Theme.surfaceContainerHighest
        opacity: Media.playing ? 1 : 0.6
        Image {
          anchors.fill: parent
          visible: Media.art !== ""
          source: Media.art
          fillMode: Image.PreserveAspectCrop
          sourceSize: Qt.size(36, 36)
          asynchronous: true
        }
        Glyph {
          anchors.centerIn: parent
          visible: Media.art === ""
          font.pixelSize: Theme.icon.xs
          text: Media.kindIcon
        }
      }
    }

    UiText {
      visible: root.titleMax >= 50
      Layout.maximumWidth: root.titleMax
      elide: Text.ElideRight
      color: Media.playing ? Theme.fgSurface : Theme.fgSurfaceVariant
      text: Media.title || Media.player
    }
  }

  TipArea {
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    cursorShape: Qt.PointingHandCursor
    tipWindow: root.tip
    tipText: Media.artist !== "" ? Media.title + " — " + Media.artist : Media.title
    property real acc: 0
    onClicked: mouse => {
      if (mouse.button === Qt.RightButton)
        root.centerRequested();
      else
        Media.togglePlaying();
    }
    onWheel: wheel => {
      acc += wheel.angleDelta.y;
      if (Math.abs(acc) < 120)
        return;
      if (acc > 0)
        Media.previous();
      else
        Media.next();
      acc = 0;
    }
  }

  Timer {
    interval: 1000
    repeat: true
    running: root.visible && Media.playing
    onTriggered: Media.tick()
  }
}
