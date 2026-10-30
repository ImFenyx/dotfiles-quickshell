import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets
import qs.components
import qs.services
import qs.menus

// Mini-player no canto inferior esquerdo, encaixado na moldura: o canto de baixo
// completa o canto da moldura (mesmo centro), a orelha de cima concorda com o filete
// esquerdo e a aba da direita com o filete de baixo. Fica recolhido dentro do filete;
// aparece por uns segundos quando a faixa muda ou da play/pausa, e com o mouse no
// canto do filete. Clique (ou SUPER+CTRL+M) expande no player completo (o cartao do
// centro); Esc ou clique fora recolhe. Roda troca de faixa; o botao toca/pausa.
PanelWindow {
  id: root

  WlrLayershell.namespace: "quickshell:media"
  WlrLayershell.layer: WlrLayer.Top
  WlrLayershell.keyboardFocus: expanded ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
  exclusionMode: ExclusionMode.Ignore
  anchors.left: true
  anchors.bottom: true
  margins.left: Theme.edge
  color: "transparent"
  visible: Media.has
  mask: Region {
    item: root.shown ? body : hot
  }

  readonly property real fr: Theme.frameR
  readonly property real pr: Theme.shape.popup
  readonly property real pad: Theme.space.sm
  readonly property real miniW: 260
  readonly property real miniH: 48
  readonly property real fullW: 360
  readonly property real fullH: card.implicitHeight + 2 * Theme.space.lg

  property bool expanded: false
  property bool peek: false
  readonly property bool shown: expanded || peek || bodyHover.hovered || hotHover.hovered

  // corpo atual (anima entre mini e expandido) e recolhimento no filete
  property real bw: expanded ? fullW : miniW
  property real bh: expanded ? fullH : miniH
  property real hide: shown ? 0 : 1
  Behavior on bw {
    SpringPanel {}
  }
  Behavior on bh {
    SpringPanel {}
  }
  Behavior on hide {
    SpringPanel {}
  }

  implicitWidth: fullW + fr
  implicitHeight: fullH + fr + Theme.edge

  function toggle() {
    if (Media.has)
      expanded = !expanded;
  }

  // body: orelha (R) em cima, aba (R) a direita; coordenadas do corpo comecam no filete
  function shapePath(w, h) {
    const R = fr, r = pr, bw = w - R;
    return `M0,0 A${R},${R} 0 0 0 ${R},${R} L${bw - r},${R} A${r},${r} 0 0 1 ${bw},${R + r} L${bw},${h - R} A${R},${R} 0 0 0 ${w},${h} L${R},${h} A${R},${R} 0 0 1 0,${h - R} Z`;
  }

  // aparece por uns segundos quando a faixa muda ou da play/pausa (nao na partida)
  property bool ready: false
  Timer {
    interval: 2000
    running: true
    onTriggered: root.ready = true
  }
  Timer {
    id: peekTimer
    interval: 3500
    onTriggered: root.peek = false
  }
  function flash() {
    if (!ready)
      return;
    peek = true;
    peekTimer.restart();
  }
  Connections {
    target: Media
    function onTitleChanged() {
      root.flash();
    }
    function onPlayingChanged() {
      root.flash();
    }
  }

  // clique fora recolhe (armado depois de expandir, como no PopupBase)
  property bool grabArmed: false
  onExpandedChanged: {
    grabArmed = false;
    if (expanded)
      grabDelay.restart();
  }
  Timer {
    id: grabDelay
    interval: 50
    onTriggered: root.grabArmed = root.expanded
  }
  HyprlandFocusGrab {
    active: root.expanded && root.grabArmed
    windows: [QsWindow.window]
    onCleared: root.expanded = false
  }

  // canto do filete de baixo: com o mouse aqui o mini aparece
  Item {
    id: hot
    x: 0
    y: root.height - Theme.edge
    width: root.miniW
    height: Theme.edge
    HoverHandler {
      id: hotHover
    }
  }

  Item {
    id: body
    x: 0
    width: root.bw + root.fr
    height: root.bh + root.fr
    y: root.height - Theme.edge - height + root.hide * (height + Theme.edge)

    HoverHandler {
      id: bodyHover
    }

    Shape {
      anchors.fill: parent
      preferredRendererType: Shape.CurveRenderer
      ShapePath {
        strokeWidth: 0
        strokeColor: "transparent"
        fillColor: Theme.surface
        PathSvg {
          path: root.shapePath(body.width, body.height)
        }
      }
    }

    // area util: abaixo da orelha, a esquerda da aba
    Item {
      id: area
      x: 0
      y: root.fr
      width: root.bw
      height: root.bh

      Item {
        focus: root.expanded
        Keys.onEscapePressed: root.expanded = false
      }

      // ---- mini ----
      RowLayout {
        anchors.fill: parent
        anchors.leftMargin: root.pad
        anchors.rightMargin: root.pad
        spacing: Theme.space.sm
        opacity: root.expanded ? 0 : 1
        visible: opacity > 0
        Behavior on opacity {
          NumberAnimation {
            duration: Theme.animFast
          }
        }

        ClippingRectangle {
          Layout.preferredWidth: 32
          Layout.preferredHeight: 32
          radius: Theme.shape.sm
          color: Theme.surfaceContainerHighest
          Image {
            anchors.fill: parent
            visible: Media.art !== ""
            source: Media.art
            fillMode: Image.PreserveAspectCrop
            sourceSize: Qt.size(64, 64)
            asynchronous: true
          }
          Glyph {
            anchors.centerIn: parent
            visible: Media.art === ""
            text: Media.kindIcon
          }
        }
        ColumnLayout {
          Layout.fillWidth: true
          spacing: 0
          UiText {
            Layout.fillWidth: true
            elide: Text.ElideRight
            text: Media.title || Media.player
          }
          UiText {
            Layout.fillWidth: true
            visible: Media.artist !== ""
            elide: Text.ElideRight
            color: Theme.fgSurfaceVariant
            font.pixelSize: Theme.type.label_m
            font.weight: Font.Medium
            text: Media.artist
          }
        }
        Rectangle {
          Layout.preferredWidth: 32
          Layout.preferredHeight: 32
          radius: height / 2
          color: playArea.containsMouse ? Theme.secondary : Theme.primary
          Glyph {
            anchors.centerIn: parent
            color: Theme.fgPrimary
            text: Media.playing ? Icons.pause : Icons.play
          }
          MouseArea {
            id: playArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: Media.togglePlaying()
          }
        }
      }

      // clique no mini expande; roda troca de faixa (fica abaixo do botao de play)
      MouseArea {
        anchors.fill: parent
        z: -1
        enabled: !root.expanded
        cursorShape: Qt.PointingHandCursor
        property real acc: 0
        onClicked: root.expanded = true
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

      // ---- expandido: o mesmo cartao do centro ----
      NotifMedia {
        id: card
        x: Theme.space.lg
        y: Theme.space.lg
        width: root.fullW - 2 * Theme.space.lg
        opacity: root.expanded ? 1 : 0
        visible: opacity > 0
        Behavior on opacity {
          NumberAnimation {
            duration: Theme.animNormal
          }
        }
      }
    }
  }
}
