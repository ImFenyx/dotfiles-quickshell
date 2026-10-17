import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.components
import qs.services

// Menu interativo da rede: abre no clique, fecha no clique fora.
// Opaco, com acoes em scripts/ + toggles nmcli.
PopupBase {
  id: root

  panelWidth: 270
  panelX: root.width - panelWidth - 8
  // cede foco p/ senha quando aberta (senao digitacao falha)
  backdropFocus: pwSSID === ""

  property bool netOn: true
  property bool netsExpanded: false
  property bool netsScanning: false
  property bool hasScanned: false
  property var wifiNets: []
  property string pwSSID: ""
  property string forgetArmed: ""
  property string rescanArg: ""

  function runScan(mode) {
    rescanArg = mode;
    netsScanning = true;
    scanProc.running = false;
    scanProc.running = true;
  }
  function toggle() {
    if (open) {
      close();
    } else {
      open = true;
      stateProc.running = false;
      stateProc.running = true;
      runScan("");
    }
  }
  // close() vem do PopupBase; o reset de estado fica aqui
  onOpenChanged: {
    if (!open) {
      netsExpanded = false;
      pwSSID = "";
      forgetArmed = "";
      wifiNets = [];
      hasScanned = false;
    }
  }

  Process {
    id: scanProc
    command: ["sh", Quickshell.shellPath("scripts/wifi-scan.sh"), root.rescanArg]
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

  // Conexao com senha: a senha vai por stdin (nunca por argv, que e legivel em
  // /proc/*/cmdline). O Process vive na janela, entao sobrevive ao fechar o menu.
  function connectWithPassword(ssid, password) {
    connectProc.ssid = ssid;
    connectProc.password = password;
    connectProc.running = true;
  }
  Process {
    id: connectProc
    property string ssid: ""
    property string password: ""
    stdinEnabled: true
    command: ["sh", Quickshell.shellPath("scripts/wifi-connect.sh"), ssid, "--stdin"]
    onStarted: {
      write(password + "\n");
      password = "";
    }
  }

  // o estado do Wi-Fi vem de services/Wifi; aqui so o "networking" geral
  Process {
    id: stateProc
    command: ["nmcli", "networking"]
    stdout: StdioCollector {
      onStreamFinished: root.netOn = text.trim() === "enabled"
    }
  }

  UiText {
    Layout.fillWidth: true
    Layout.bottomMargin: 6
    font.weight: Font.DemiBold
    elide: Text.ElideRight
    text: Wifi.strength === "" ? Wifi.name : Wifi.name + " \u00b7 " + Wifi.strength
  }

  MenuRow {
    visible: Wifi.on
    popup: root
    icon: Icons.netWifi
    label: "Redes disponíveis"
    arrow: root.netsExpanded ? Icons.arrowUp : Icons.arrowDown
    keepOpen: true
    onFired: root.netsExpanded = !root.netsExpanded
  }
  ColumnLayout {
    visible: root.netsExpanded && Wifi.on
    Layout.fillWidth: true
    spacing: 2

    MenuRow {
      visible: root.netsScanning
      popup: root
      icon: Icons.netScan
      label: "Procurando…"
      keepOpen: true
    }
    MenuRow {
      visible: !root.netsScanning && root.hasScanned && root.wifiNets.length === 0
      popup: root
      icon: Icons.netNone
      label: "Nenhuma rede encontrada"
      keepOpen: true
    }

    Repeater {
      model: root.wifiNets
      delegate: Item {
        id: net
        required property var modelData
        property bool secured: modelData.sec !== "" && modelData.sec !== "--"
        property bool armed: root.forgetArmed === modelData.ssid

        Layout.fillWidth: true
        implicitHeight: 32

        Rectangle {
          anchors.fill: parent
          radius: 8
          color: (ssidArea.containsMouse || lockArea.containsMouse) ? Theme.surface1 : "transparent"
        }
        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: 10
          anchors.rightMargin: 6
          spacing: 8
          Glyph {
            text: Icons.level(net.modelData.sig, Icons.wifi)
          }
          Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            UiText {
              anchors.verticalCenter: parent.verticalCenter
              width: parent.width
              color: net.modelData.inuse ? Theme.green : Theme.text
              elide: Text.ElideRight
              text: net.armed ? "Esquecer " + net.modelData.ssid + "?" : net.modelData.ssid
            }
            MouseArea {
              id: ssidArea
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                const m = net.modelData;
                if (m.inuse) {
                  root.close();
                  return;
                }
                if (m.saved) {
                  Quickshell.execDetached(["sh", Quickshell.shellPath("scripts/wifi-connect.sh"), m.ssid]);
                  root.close();
                  return;
                }
                root.pwSSID = m.ssid;
              }
            }
          }
          // cadeado: rede nova -> pede senha; salva -> 1o clique arma, 2o esquece
          Item {
            Layout.preferredWidth: 30
            Layout.fillHeight: true
            Glyph {
              anchors.centerIn: parent
              visible: net.secured
              color: net.armed ? Theme.red : Theme.mauve
              text: Icons.padlock
            }
            MouseArea {
              id: lockArea
              anchors.fill: parent
              enabled: net.secured
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                const m = net.modelData;
                if (!m.saved) {
                  root.pwSSID = m.ssid;
                  return;
                }
                if (root.forgetArmed === m.ssid) {
                  Quickshell.execDetached(["sh", Quickshell.shellPath("scripts/wifi-forget.sh"), m.ssid]);
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
        color: Theme.surface1
      }
      TextInput {
        id: pwInput
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        verticalAlignment: TextInput.AlignVCenter
        color: Theme.text
        font.family: Theme.uiFont
        font.pointSize: 11
        echoMode: TextInput.Password
        focus: root.pwSSID !== ""
        Keys.onEscapePressed: root.close()
        onAccepted: {
          if (text === "")
            return;
          root.connectWithPassword(root.pwSSID, text);
          text = "";
          root.pwSSID = "";
          root.close();
        }
      }
      UiText {
        visible: pwInput.text === ""
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 10
        verticalAlignment: Text.AlignVCenter
        color: Theme.overlay0
        elide: Text.ElideRight
        text: "Senha p/ " + root.pwSSID + "… (Enter conecta)"
      }
    }

    MenuRow {
      visible: !root.netsScanning
      popup: root
      icon: Icons.netScan
      label: "Procurar novamente"
      keepOpen: true
      onFired: root.runScan("--rescan")
    }
  }

  MenuRow {
    popup: root
    icon: Icons.netDisconnect
    label: "Desconectar"
    onFired: Quickshell.execDetached(["sh", Quickshell.shellPath("scripts/wifi-disconnect.sh")])
  }
  Rectangle {
    Layout.fillWidth: true
    Layout.topMargin: 4
    Layout.bottomMargin: 4
    height: 1
    color: Theme.surface1
  }
  MenuRow {
    popup: root
    icon: Wifi.on ? Icons.netWifi : Icons.wifiOff
    label: "Alternar Wi-Fi"
    checkable: true
    checked: Wifi.on
    onFired: Quickshell.execDetached(["nmcli", "radio", "wifi", Wifi.on ? "off" : "on"])
  }
  MenuRow {
    popup: root
    icon: Icons.netGlobe
    label: "Alternar rede"
    checkable: true
    checked: root.netOn
    onFired: Quickshell.execDetached(["nmcli", "networking", root.netOn ? "off" : "on"])
  }
  MenuRow {
    popup: root
    icon: Icons.netInfo
    label: "Info da conexão"
    onFired: Quickshell.execDetached(["sh", Quickshell.shellPath("scripts/netinfo.sh")])
  }
  MenuRow {
    popup: root
    icon: Icons.netEdit
    label: "Editar conexões"
    onFired: Quickshell.execDetached([Config.connectionEditor])
  }
}
