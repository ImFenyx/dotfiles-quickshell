import QtQuick
import QtQuick.Shapes
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

// Powermenu (substitui rofi/extensions/powermenu.sh): mesmo modelo dos menus
// (Overlay + slide + Esc + notch). 2 cliques p/ acao destrutiva: arma, confirma.
PanelWindow {
  id: root
  anchors.top: true
  anchors.bottom: true
  anchors.left: true
  anchors.right: true
  WlrLayershell.layer: WlrLayer.Overlay
  exclusionMode: ExclusionMode.Ignore
  mask: open ? fullMask : emptyMask
  color: "transparent"
  // Desmapeada quando fechada (menos RAM): layerrule noanim p/ namespace
  // quickshell evita o fadeLayersIn do Hyprland, o slide continua 100% QML.
  // offsetScale<1 mantem mapeada durante a animacao de saida.
  visible: open || offsetScale < 0.999

  property bool open: false
  property string armed: ""
  property color menuBg: "#ff1e1e2e"
  property int topY: 48
  property real offsetScale: open ? 0 : 1
  Behavior on offsetScale {
    SpringAnimation {
      spring: 6
      damping: 0.8
      epsilon: 0.001
    }
  }

  function toggle() {
    if (open)
      close();
    else {
      armed = "";
      open = true;
    }
  }
  // modelo OSD: close direto, spring resolve o colapso (sem estado closing)
  function close() {
    open = false;
    armed = "";
  }

  HyprlandFocusGrab {
    active: root.open
    windows: [QsWindow.window]
    onCleared: root.close()
  }

  MouseArea {
    anchors.fill: parent
    focus: root.open
    Keys.onEscapePressed: root.close()
    onClicked: root.close()
  }

  Region {
    id: emptyMask
  }
  Region {
    id: fullMask
    x: 0
    y: 0
    width: root.width
    height: root.height
  }

  Item {
    width: 270
    height: menuCol.implicitHeight + 24
    clip: true
    x: root.width - width - 8
    y: root.topY
    visible: root.offsetScale < 1

    Item {
      width: parent.width
      height: parent.height
      y: -height * root.offsetScale

      Shape {
        id: bgShape
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        asynchronous: true
        ShapePath {
          strokeWidth: 0
          strokeColor: "transparent"
          fillColor: root.menuBg
          PathSvg {
            path: {
              const w = bgShape.width, h = bgShape.height, r = 16, f = 8, k = 10;
              const bx = w - f;
              return `M0,0 L${w},0 C${w - 2},0 ${bx},${k * 0.25} ${bx},${k} L${bx},${h - r} Q${bx},${h} ${bx - r},${h} L${f + r},${h} Q${f},${h} ${f},${h - r} L${f},${k} C${f},${k * 0.25} 2,0 0,0 Z`;
            }
          }
        }
      }

      ColumnLayout {
        id: menuCol
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: 14
        anchors.leftMargin: 18
        anchors.rightMargin: 18
        anchors.bottomMargin: 10
        spacing: 2

        Repeater {
          model: [
            { id: "shutdown", label: "Desligar", icon: "󰐥", cmd: ["systemctl", "poweroff"] },
            { id: "reboot", label: "Reiniciar", icon: "󰜉", cmd: ["systemctl", "reboot"] },
            { id: "suspend", label: "Dormir", icon: "\u{F0904}", cmd: ["systemctl", "suspend"] },
            { id: "logout", label: "Sair", icon: "󰍃", cmd: ["sh", "-c", "uwsm check is-active >/dev/null 2>&1 && uwsm stop || hyprctl dispatch 'hl.dsp.exit()'"] },
          ]
          delegate: Item {
            id: row
            required property var modelData
            property bool isArmed: root.armed === modelData.id
            Layout.fillWidth: true
            implicitHeight: 32
            Rectangle {
              anchors.fill: parent
              radius: 8
              color: row.isArmed ? "#f38ba8" : (rowArea.containsMouse ? "#45475a" : "transparent")
            }
            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: 10
              anchors.rightMargin: 10
              spacing: 8
              Text {
                color: row.isArmed ? "#1e1e2e" : "#cba6f7"
                font.family: "JetBrainsMono Nerd Font Propo"
                font.pointSize: 12
                text: row.modelData.icon
              }
              Text {
                Layout.fillWidth: true
                color: row.isArmed ? "#1e1e2e" : "#cdd6f4"
                font.family: "Rubik"
                font.pointSize: 11
                font.weight: Font.Medium
                elide: Text.ElideRight
                text: row.isArmed ? "Confirmar " + row.modelData.label.toLowerCase() + "?" : row.modelData.label
              }
            }
            MouseArea {
              id: rowArea
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                if (row.isArmed) {
                  Quickshell.execDetached(row.modelData.cmd);
                  root.close();
                } else {
                  root.armed = row.modelData.id;
                }
              }
            }
          }
        }
      }
    }
  }
}
