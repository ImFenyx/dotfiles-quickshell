import QtQuick
import QtQuick.Shapes
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland

// Menu interativo da rede (equivale ao menu on-click do waybar):
// abre no clique, fecha no clique fora. Opaco, com as acoes do
// ~/.config/waybar/scripts + toggles nmcli.
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
  property bool wifiOn: true
  property bool netOn: true
  property bool netsExpanded: false
  property bool netsScanning: false
  property bool hasScanned: false
  property var wifiNets: []
  property string pwSSID: ""
  property string forgetArmed: ""
  property string rescanArg: ""

  function sigIcon(s) {
    if (s >= 75)
      return "\u{F0928}";
    if (s >= 50)
      return "\u{F0925}";
    if (s >= 25)
      return "\u{F0922}";
    return "\u{F091F}";
  }
  function runScan(mode) {
    rescanArg = mode;
    netsScanning = true;
    scanProc.running = false;
    scanProc.running = true;
  }
  property color menuBg: "#ff1e1e2e"
  property string netName: ""
  property string netSig: ""
  property int topY: 48
  // driver slide+fade (modelo caelestia offsetScale): 0=aberto, 1=fechado.
  // Conteudo move junto (sem clip-reveal = sem efeito slice).
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
      open = true;
      stateProc.running = false;
      stateProc.running = true;
      runScan("");
    }
  }
  // modelo OSD: close direto, spring resolve o colapso (sem estado closing)
  function close() {
    open = false;
    netsExpanded = false;
    pwSSID = "";
    forgetArmed = "";
    wifiNets = [];
    hasScanned = false;
  }

  Process {
    id: scanProc
    command: ["sh", "/home/fenyx/.config/quickshell/scripts/wifi-scan.sh", rescanArg]
    stdout: StdioCollector {
      onStreamFinished: {
        const lines = text.trim().split("\n").filter(l => l.length > 0);
        root.netsScanning = false;
        root.hasScanned = true;
        if (lines.length === 0)
          return;
        root.wifiNets = lines.map(l => {
          const q = l.split("|");
          return {
            ssid: q[0] || "",
            sig: parseInt(q[1], 10) || 0,
            sec: q[2] || "",
            inuse: q[3] === "1",
            saved: q[4] === "1"
          };
        }).filter(n => n.ssid !== "");
      }
    }
  }

  Process {
    id: stateProc
    command: ["sh", "-c", "nmcli radio wifi 2>/dev/null; echo ---; nmcli networking 2>/dev/null"]
    stdout: StdioCollector {
      onStreamFinished: {
        const lines = text.trim().split("\n");
        if (lines.length > 0)
          root.wifiOn = lines[0].trim() === "enabled";
        if (lines.length > 1)
          root.netOn = lines[lines.length - 1].trim() === "enabled";
      }
    }
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
    // cede foco p/ senha quando aberta (senao digitacao falha)
    focus: root.open && root.pwSSID === ""
    Keys.onEscapePressed: root.close()
    onClicked: root.close()
  }

  // Caixa fundida na barra: topo reto colado na base da barra (sem fresta),
  // base arredondada num fill unico de Canvas (Shape ignora o alfa do fill
  // e saia opaco; Canvas respeita, igual a barra). Mascara fixa + conteudo
  // rigido que desliza dentro: nunca cobre a barra, parece sair de dentro dela.
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

        Text {
          Layout.fillWidth: true
          Layout.bottomMargin: 6
          color: "#cdd6f4"
          font.family: "Rubik"
          font.pointSize: 11
          font.weight: Font.DemiBold
          elide: Text.ElideRight
          text: root.netSig === "" ? root.netName : root.netName + " · " + root.netSig
        }

        MenuRow {
          visible: root.wifiOn
          icon: ""
          label: "Redes disponíveis"
          arrow: root.netsExpanded ? "\u{F0143}" : "\u{F0140}"
          keepOpen: true
          onFired: root.netsExpanded = !root.netsExpanded
        }
        ColumnLayout {
          visible: root.netsExpanded && root.wifiOn
          Layout.fillWidth: true
          spacing: 2
          MenuRow {
            visible: root.netsScanning
            icon: ""
            label: "Procurando…"
            keepOpen: true
            onFired: {}
          }
          MenuRow {
            visible: !root.netsScanning && root.hasScanned && root.wifiNets.length === 0
            icon: ""
            label: "Nenhuma rede encontrada"
            keepOpen: true
            onFired: {}
          }
          Repeater {
            model: root.wifiNets
            delegate: Item {
              required property var modelData
              property bool secured: modelData.sec !== "" && modelData.sec !== "--"
              property bool armed: root.forgetArmed === modelData.ssid
              Layout.fillWidth: true
              implicitHeight: 32
              Rectangle {
                anchors.fill: parent
                radius: 8
                color: (ssidArea.containsMouse || lockArea.containsMouse) ? "#45475a" : "transparent"
              }
              RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 6
                spacing: 8
                Text {
                  color: "#cba6f7"
                  font.family: "JetBrainsMono Nerd Font Propo"
                  font.pointSize: 12
                  text: sigIcon(modelData.sig)
                }
                Item {
                  Layout.fillWidth: true
                  Layout.fillHeight: true
                  Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    color: modelData.inuse ? "#a6e3a1" : "#cdd6f4"
                    font.family: "Rubik"
                    font.pointSize: 11
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                    text: armed ? "Esquecer " + modelData.ssid + "?" : modelData.ssid
                  }
                  MouseArea {
                    id: ssidArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                      const m = modelData;
                      if (m.inuse) {
                        root.close();
                        return;
                      }
                      if (m.saved) {
                        Quickshell.execDetached(["sh", "/home/fenyx/.config/quickshell/scripts/wifi-connect.sh", m.ssid]);
                        root.close();
                        return;
                      }
                      root.pwSSID = m.ssid;
                    }
                  }
                }
                Item {
                  Layout.preferredWidth: 30
                  Layout.fillHeight: true
                  Text {
                    anchors.centerIn: parent
                    visible: secured
                    color: armed ? "#f38ba8" : "#cba6f7"
                    font.family: "JetBrainsMono Nerd Font Propo"
                    font.pointSize: 12
                    text: "\u{F033E}"
                  }
                  MouseArea {
                    id: lockArea
                    anchors.fill: parent
                    enabled: secured
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                      const m = modelData;
                      if (!m.saved) {
                        root.pwSSID = m.ssid;
                        return;
                      }
                      if (root.forgetArmed === m.ssid) {
                        Quickshell.execDetached(["sh", "/home/fenyx/.config/quickshell/scripts/wifi-forget.sh", m.ssid]);
                        root.forgetArmed = "";
                        root.close();
                      } else {
                        root.forgetArmed = m.ssid;
                      }
                    }
                  }
                }
              }
            }
          }
          Item {
            visible: root.pwSSID !== ""
            Layout.fillWidth: true
            implicitHeight: 32
            Rectangle {
              anchors.fill: parent
              radius: 8
              color: "#45475a"
            }
            TextInput {
              id: pwInput
              anchors.fill: parent
              anchors.leftMargin: 10
              anchors.rightMargin: 10
              verticalAlignment: TextInput.AlignVCenter
              color: "#cdd6f4"
              font.family: "Rubik"
              font.pointSize: 11
              echoMode: TextInput.Password
              focus: root.pwSSID !== ""
              Keys.onEscapePressed: root.close()
              onAccepted: {
                if (text === "")
                  return;
                Quickshell.execDetached(["sh", "/home/fenyx/.config/quickshell/scripts/wifi-connect.sh", root.pwSSID, text]);
                text = "";
                root.pwSSID = "";
                root.close();
              }
            }
            Text {
              visible: pwInput.text === ""
              anchors.fill: parent
              anchors.leftMargin: 10
              anchors.rightMargin: 10
              verticalAlignment: Text.AlignVCenter
              color: "#6c7086"
              font.family: "Rubik"
              font.pointSize: 11
              elide: Text.ElideRight
              text: "Senha p/ " + root.pwSSID + "… (Enter conecta)"
            }
          }
          MenuRow {
            visible: !root.netsScanning
            icon: ""
            label: "Procurar novamente"
            keepOpen: true
            onFired: root.runScan("--rescan")
          }
        }
        MenuRow {
          icon: ""
          label: "Desconectar"
          onFired: Quickshell.execDetached(["sh", "/home/fenyx/.config/waybar/scripts/wifi-selector.sh", "--disconnect"])
        }
        Rectangle {
          Layout.fillWidth: true
          Layout.topMargin: 4
          Layout.bottomMargin: 4
          height: 1
          color: "#45475a"
        }
        MenuRow {
          icon: root.wifiOn ? "" : "\u{F092E}"
          label: "Alternar Wi-Fi"
          checkable: true
          checked: root.wifiOn
          onFired: Quickshell.execDetached(["sh", "-c", "nmcli radio wifi | grep -q enabled && nmcli radio wifi off || nmcli radio wifi on"])
        }
        MenuRow {
          icon: ""
          label: "Alternar rede"
          checkable: true
          checked: root.netOn
          onFired: Quickshell.execDetached(["sh", "-c", "nmcli networking connectivity | grep -q none && nmcli networking on || nmcli networking off"])
        }
        MenuRow {
          icon: ""
          label: "Info da conexão"
          onFired: Quickshell.execDetached(["sh", "/home/fenyx/.config/waybar/scripts/netinfo.sh"])
        }
        MenuRow {
          icon: ""
          label: "Editar conexões"
          onFired: Quickshell.execDetached(["nm-connection-editor"])
        }
      }
    }

    component MenuRow: Item {
      id: row
      signal fired
      property string icon
      property string label
      property bool checkable: false
      property bool checked: false
      property bool keepOpen: false
      property color labelColor: "#cdd6f4"
      property string arrow: ""
      Layout.fillWidth: true
      implicitHeight: 32
      Rectangle {
        anchors.fill: parent
        radius: 8
        color: rowArea.containsMouse ? "#45475a" : "transparent"
      }
      RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        spacing: 8
        Text {
          color: "#cba6f7"
          font.family: "JetBrainsMono Nerd Font Propo"
          font.pointSize: 12
          text: row.icon
        }
        Text {
          Layout.fillWidth: true
          color: row.labelColor
          font.family: "Rubik"
          font.pointSize: 11
          font.weight: Font.Medium
          elide: Text.ElideRight
          text: row.label
        }
        Rectangle {
          visible: row.checkable
          Layout.preferredWidth: 18
          Layout.preferredHeight: 18
          radius: 9
          color: row.checked ? "#cba6f7" : "transparent"
          border.color: "#cba6f7"
          border.width: 1
          Rectangle {
            anchors.centerIn: parent
            width: 8
            height: 8
            radius: 4
            color: "#1e1e2e"
            visible: row.checked
          }
        }
        Text {
          visible: row.arrow !== ""
          color: "#cba6f7"
          font.family: "JetBrainsMono Nerd Font Propo"
          font.pointSize: 12
          text: row.arrow
        }
      }
      MouseArea {
        id: rowArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
          row.fired();
          if (!row.keepOpen)
            root.close();
        }
      }
    }
  }
}
