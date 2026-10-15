import QtQuick
import QtQuick.Shapes
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import Quickshell.Wayland

// Menu nativo do tray (StatusNotifierItem / DBusMenu):
// botao direito abre as opcoes que o app expoe (padrao caelestia TrayMenu.qml,
// simplificado: 1 nivel + submenu inline, sem StackView).
// Template de popup copiado do NetMenu.qml (Overlay + click-fora + Canvas).
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
  property var trayItem: null
  property var expandedEntry: null
  property var subExpandedEntry: null
  property real anchorX: 0
  property int topY: 48
  property color menuBg: "#ff1e1e2e"
  property real offsetScale: open ? 0 : 1
  Behavior on offsetScale {
    SpringAnimation {
      spring: 6
      damping: 0.8
      epsilon: 0.001
    }
  }

  function show(item, p) {
    trayItem = item;
    expandedEntry = null;
    subExpandedEntry = null;
    // multi-monitor: p vem de mapToGlobal (desktop). Converte p/ local da tela
    // (ShellScreen.x/y = origem do monitor, ex. HDMI em -1920).
    const sx = (root.screen && root.screen.x !== undefined) ? root.screen.x : 0;
    anchorX = p ? p.x - sx : root.width / 2;
    open = true;
  }
  // modelo OSD: close direto, spring resolve o colapso (sem estado closing)
  function close() {
    open = false;
    trayItem = null;
    expandedEntry = null;
    subExpandedEntry = null;
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

  // submenu inline (padrao proprio; 3 niveis cobrem menus reais de tray)
  QsMenuOpener {
    id: mainOpener
    menu: root.trayItem ? root.trayItem.menu : null
  }
  QsMenuOpener {
    id: subOpener
    menu: root.expandedEntry
  }
  QsMenuOpener {
    id: subSubOpener
    menu: root.subExpandedEntry
  }

  Item {
    width: 280
    height: menuCol.implicitHeight + 24
    clip: true
    x: Math.max(8, Math.min(root.width - width - 8, root.anchorX - width / 2))
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
          model: mainOpener.children
          delegate: Item {
            id: row
            required property var modelData
            Layout.fillWidth: true
            implicitHeight: modelData.isSeparator ? 9 : 32
            visible: true

            Rectangle {
              visible: row.modelData.isSeparator
              anchors.centerIn: parent
              width: parent.width
              height: 1
              color: "#45475a"
            }

            Rectangle {
              visible: !row.modelData.isSeparator
              anchors.fill: parent
              radius: 8
              color: rowArea.containsMouse && row.modelData.enabled ? "#45475a" : "transparent"
            }
            RowLayout {
              visible: !row.modelData.isSeparator
              anchors.fill: parent
              anchors.leftMargin: 10
              anchors.rightMargin: 10
              spacing: 8
              IconImage {
                visible: (row.modelData.icon || "") !== ""
                Layout.preferredWidth: 16
                Layout.preferredHeight: 16
                asynchronous: true
                source: row.modelData.icon || ""
              }
              Text {
                Layout.fillWidth: true
                color: row.modelData.enabled ? "#cdd6f4" : "#6c7086"
                font.family: "Rubik"
                font.pointSize: 11
                font.weight: Font.Medium
                elide: Text.ElideRight
                text: row.modelData.text || ""
              }
              Text {
                visible: row.modelData.buttonType !== 0 && row.modelData.checkState === 2
                color: "#cba6f7"
                font.family: "JetBrainsMono Nerd Font Propo"
                font.pointSize: 12
                text: ""
              }
              Text {
                visible: row.modelData.hasChildren
                color: "#cba6f7"
                font.family: "JetBrainsMono Nerd Font Propo"
                font.pointSize: 12
                text: root.expandedEntry === row.modelData ? "" : ""
              }
            }
            MouseArea {
              id: rowArea
              anchors.fill: parent
              enabled: !row.modelData.isSeparator && row.modelData.enabled
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                const e = row.modelData;
                if (e.hasChildren) {
                  root.expandedEntry = (root.expandedEntry === e) ? null : e;
                  root.subExpandedEntry = null;
                } else {
                  e.triggered();
                  root.close();
                }
              }
            }

            ColumnLayout {
              visible: !row.modelData.isSeparator && root.expandedEntry === row.modelData
              anchors.top: row.bottom
              anchors.left: parent.left
              anchors.right: parent.right
              spacing: 2
              Repeater {
                model: subOpener.children
                delegate: Item {
                  id: subRow
                  required property var modelData
                  Layout.fillWidth: true
                  implicitHeight: modelData.isSeparator ? 9 : 30
                  Rectangle {
                    visible: subRow.modelData.isSeparator
                    anchors.centerIn: parent
                    width: parent.width - 16
                    height: 1
                    color: "#45475a"
                  }
                  Rectangle {
                    visible: !subRow.modelData.isSeparator
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    radius: 8
                    color: subArea.containsMouse && subRow.modelData.enabled ? "#45475a" : "transparent"
                  }
                  RowLayout {
                    visible: !subRow.modelData.isSeparator
                    anchors.fill: parent
                    anchors.leftMargin: 26
                    anchors.rightMargin: 10
                    spacing: 8
                    Text {
                      Layout.fillWidth: true
                      color: subRow.modelData.enabled ? "#cdd6f4" : "#6c7086"
                      font.family: "Rubik"
                      font.pointSize: 11
                      elide: Text.ElideRight
                      text: subRow.modelData.text || ""
                    }
                    Text {
                      visible: subRow.modelData.hasChildren
                      color: "#cba6f7"
                      font.family: "JetBrainsMono Nerd Font Propo"
                      font.pointSize: 12
                      text: root.subExpandedEntry === subRow.modelData ? "\u{F107}" : "\u{F105}"
                    }
                  }
                  MouseArea {
                    id: subArea
                    anchors.fill: parent
                    enabled: !subRow.modelData.isSeparator && subRow.modelData.enabled
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                      const e = subRow.modelData;
                      if (e.hasChildren) {
                        root.subExpandedEntry = (root.subExpandedEntry === e) ? null : e;
                      } else {
                        e.triggered();
                        root.close();
                      }
                    }
                  }
                  ColumnLayout {
                    visible: !subRow.modelData.isSeparator && root.subExpandedEntry === subRow.modelData
                    anchors.top: subRow.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    spacing: 2
                    Repeater {
                      model: subSubOpener.children
                      delegate: Item {
                        id: subSubRow
                        required property var modelData
                        Layout.fillWidth: true
                        implicitHeight: modelData.isSeparator ? 9 : 30
                        Rectangle {
                          visible: subSubRow.modelData.isSeparator
                          anchors.centerIn: parent
                          width: parent.width - 32
                          height: 1
                          color: "#45475a"
                        }
                        Rectangle {
                          visible: !subSubRow.modelData.isSeparator
                          anchors.fill: parent
                          anchors.leftMargin: 32
                          radius: 8
                          color: subSubArea.containsMouse && subSubRow.modelData.enabled ? "#45475a" : "transparent"
                        }
                        RowLayout {
                          visible: !subSubRow.modelData.isSeparator
                          anchors.fill: parent
                          anchors.leftMargin: 42
                          anchors.rightMargin: 10
                          Text {
                            Layout.fillWidth: true
                            color: subSubRow.modelData.enabled ? "#cdd6f4" : "#6c7086"
                            font.family: "Rubik"
                            font.pointSize: 11
                            elide: Text.ElideRight
                            text: subSubRow.modelData.text || ""
                          }
                        }
                        MouseArea {
                          id: subSubArea
                          anchors.fill: parent
                          enabled: !subSubRow.modelData.isSeparator && subSubRow.modelData.enabled
                          hoverEnabled: true
                          cursorShape: Qt.PointingHandCursor
                          onClicked: {
                            subSubRow.modelData.triggered();
                            root.close();
                          }
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        }

      }
    }
  }
}
