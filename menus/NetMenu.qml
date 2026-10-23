import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import qs.components
import qs.services

// Menu interativo da rede: abre no clique, fecha no clique fora.
// Wi-Fi pelo services/Wifi (Quickshell.Networking); o resto via nmcli/scripts.
PopupBase {
  id: root

  panelWidth: 270
  panelX: root.width - panelWidth - 8
  // cede foco p/ senha quando aberta (senao digitacao falha)
  backdropFocus: pwNet === null

  property bool netOn: true
  property bool netsExpanded: false
  property var pwNet: null           // rede pedindo senha
  property var forgetArmed: null     // rede salva com "esquecer?" armado

  function toggle() {
    if (open) {
      close();
    } else {
      open = true;
      stateProc.running = false;
      stateProc.running = true;
    }
  }
  // close() vem do PopupBase; o reset de estado fica aqui
  onOpenChanged: {
    Wifi.scan = open;
    if (!open) {
      netsExpanded = false;
      pwNet = null;
      forgetArmed = null;
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
    text: Wifi.strength === "" ? Wifi.name : Wifi.name + " · " + Wifi.strength
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

    // a lista e ao vivo (scanner ligado enquanto o menu esta aberto)
    MenuRow {
      visible: Wifi.top.length === 0
      popup: root
      icon: Icons.netScan
      label: "Procurando…"
      keepOpen: true
    }

    Repeater {
      model: Wifi.top
      delegate: Item {
        id: net
        required property var modelData
        property bool secured: modelData.security !== WifiSecurityType.Open && modelData.security !== WifiSecurityType.Owe
        property bool armed: root.forgetArmed === modelData

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
            text: Icons.level(net.modelData.signalStrength * 100, Icons.wifi)
          }
          Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            UiText {
              anchors.verticalCenter: parent.verticalCenter
              width: parent.width
              color: net.modelData.connected ? Theme.green : Theme.text
              elide: Text.ElideRight
              textFormat: Text.PlainText
              text: net.armed ? "Esquecer " + net.modelData.name + "?" : net.modelData.name
            }
            MouseArea {
              id: ssidArea
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                const m = net.modelData;
                if (m.connected) {
                  root.close();
                  return;
                }
                // salva ou aberta: conecta direto; senao pede a senha
                if (m.known || !net.secured) {
                  Wifi.connect(m);
                  root.close();
                  return;
                }
                root.pwNet = m;
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
                if (!m.known) {
                  root.pwNet = m;
                  return;
                }
                if (root.forgetArmed === m) {
                  m.forget();
                  root.close();
                } else {
                  root.forgetArmed = m;
                }
              }
            }
          }
        }
      }
    }

    Item {
      visible: root.pwNet !== null
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
        focus: root.pwNet !== null
        Keys.onEscapePressed: root.close()
        onAccepted: {
          if (text === "")
            return;
          Wifi.connect(root.pwNet, text);
          text = "";
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
        textFormat: Text.PlainText
        text: root.pwNet ? "Senha p/ " + root.pwNet.name + "… (Enter conecta)" : ""
      }
    }
  }

  MenuRow {
    visible: Wifi.active !== null
    popup: root
    icon: Icons.netDisconnect
    label: "Desconectar"
    onFired: Wifi.disconnect()
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
