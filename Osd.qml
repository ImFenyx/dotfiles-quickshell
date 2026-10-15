import QtQuick
import QtQuick.Shapes
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io

// OSD fundido na barra (centro, como NetMenu/TrayMenu): slide por altura, sem fade.
// Linha unica compacta: glyph nerd font + % + barra longa. Sem imagens.
PanelWindow {
  id: root
  anchors.top: true
  anchors.bottom: true
  anchors.left: true
  anchors.right: true
  WlrLayershell.layer: WlrLayer.Overlay
  exclusionMode: ExclusionMode.Ignore
  mask: emptyMask
  color: "transparent"
  // Desmapeado quando fechado (menos RAM): layerrule noanim p/ namespace
  // quickshell evita o fadeLayersIn do Hyprland, o slide continua 100% QML.
  // offsetScale<1 mantem mapeado durante a animacao de saida.
  visible: osdOpen || offsetScale < 0.999

  property bool osdOpen: false
  property real offsetScale: osdOpen ? 0 : 1
  Behavior on offsetScale {
    SpringAnimation {
      spring: 6
      damping: 0.8
      epsilon: 0.001
    }
  }
  property int vol: 0
  property bool muted: false
  property string glyph: ""
  property bool boosted: !muted && vol > 100
  property color menuBg: "#ff1e1e2e"
  property int topY: 48
  // barra coberta (fullscreen): OSD vira pill solta, sem notch/fuse.
  // toplevels.lastIpcObject e snapshot STALE no qs 0.3.1; evento raw "fullscreen"
  // cobre o toggle, e troca de foco/workspace reconsulta via hyprctl (debounce).
  property bool barHidden: false
  Connections {
    target: Hyprland
    function onRawEvent(event) {
      if (event.name === "fullscreen")
        barHidden = event.data === "1";
      else if (event.name === "activewindow" || event.name === "activewindowv2" || event.name === "workspace")
        fsDebounce.restart();
    }
  }
  Timer {
    id: fsDebounce
    interval: 150
    onTriggered: {
      fsProc.running = false;
      fsProc.running = true;
    }
  }
  Process {
    id: fsProc
    command: ["hyprctl", "-j", "activewindow"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          const j = JSON.parse(text);
          barHidden = (j.fullscreen ?? 0) > 1;
        } catch (e) {}
      }
    }
  }

  function show(v, m, g) {
    vol = v;
    muted = m;
    glyph = g;
    osdOpen = true;
    hideTimer.restart();
  }

  Timer {
    id: hideTimer
    interval: 650
    repeat: false
    onTriggered: root.osdOpen = false
  }

  Region {
    id: emptyMask
  }

  Item {
    // mascara fixa fundida + conteudo rigido que desliza dentro dela.
    width: osdRow.implicitWidth + 44
    // tuck 1px p/ dentro da barra (mesma cor opaca = sem hairline de AA)
    height: osdRow.implicitHeight + 19
    clip: true
    x: (root.width - width) / 2
    y: root.topY - 1
    visible: root.offsetScale < 1

    Item {
      width: parent.width
      height: parent.height
      y: -height * root.offsetScale

      Shape {
        id: bgShape
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
          strokeWidth: 0
          strokeColor: "transparent"
          fillColor: root.menuBg
          PathSvg {
            path: {
              const w = bgShape.width, h = bgShape.height, r = 16, f = 8, k = 10;
              const bx = w - f;
              if (root.barHidden) {
                // pill de verdade: radius = meia-altura (cantos totalmente redondos)
                const pr = Math.min(w, h) / 2;
                return `M${pr},0 L${w - pr},0 Q${w},0 ${w},${pr} L${w},${h - pr} Q${w},${h} ${w - pr},${h} L${pr},${h} Q0,${h} 0,${h - pr} L0,${pr} Q0,0 ${pr},0 Z`;
              }
              return `M0,0 L${w},0 C${w - 2},0 ${bx},${k * 0.25} ${bx},${k} L${bx},${h - r} Q${bx},${h} ${bx - r},${h} L${f + r},${h} Q${f},${h} ${f},${h - r} L${f},${k} C${f},${k * 0.25} 2,0 0,0 Z`;
            }
          }
        }
      }

      RowLayout {
        id: osdRow
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: 12
        anchors.leftMargin: 22
        anchors.rightMargin: 22
        spacing: 10
      Text {
        color: "#cba6f7"
        font.family: "JetBrainsMono Nerd Font Propo"
        font.pointSize: 12
        font.weight: Font.DemiBold
        text: root.glyph
      }
      Text {
        color: root.boosted ? "#f38ba8" : "#cdd6f4"
        font.family: "Rubik"
        font.pointSize: 11
        font.weight: Font.DemiBold
        text: root.muted ? "Mudo" : root.vol + "%"
      }
      Rectangle {
        Layout.preferredWidth: 300
        Layout.preferredHeight: 10
        Layout.alignment: Qt.AlignVCenter
        radius: 5
        color: "#45475a"
        Rectangle {
          width: parent.width * (root.muted ? 0 : Math.min(root.vol, 100) / 100)
          height: parent.height
          radius: 5
          color: root.boosted ? "#f38ba8" : "#89b4fa"
          // overshoot com cauda (igual pills 9/3.5): passa do ponto e assenta depois da tecla
          Behavior on width {
            SpringAnimation {
              spring: 9
              damping: 3.5
            }
          }
        }
      }
    }
  }
}
}
