import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.components

// Barra colada no topo. Os cantos que descem para as laterais sao da EdgeFrame
// (comeca na base da barra, sem sobrepor). Medidas em Theme (DESIGN.md).
//
// Os widgets vivem em bar/*.qml; esta janela so compoe. Os cliques que abrem
// menus saem como sinais — quem coordena os menus e o shell.qml.
PanelWindow {
  id: root
  WlrLayershell.namespace: "quickshell:bar"

  required property var tip   // TipWindow desta tela

  signal trayMenuRequested(var item, var pos)
  signal netMenuRequested
  signal powerMenuRequested
  signal notifCenterRequested
  signal audioMenuRequested

  anchors.top: true
  anchors.left: true
  anchors.right: true
  // a propria barra reserva a altura dela (exclusionMode Auto): janela a gaps_out abaixo
  implicitHeight: Theme.barH
  color: "transparent"

  // fundo da barra: faixa total, topo reto colado na tela.
  // Sem tiras de borda sobrepostas: com fundo translucido elas dobram
  // o alfa e viram linha visivel.
  Item {
    anchors.fill: parent

    Rectangle {
      id: barContent
      anchors.top: parent.top
      anchors.left: parent.left
      anchors.right: parent.right
      height: Theme.barH
      color: Theme.surface
    }
  }

  // Tres blocos ancorados: esquerda/direita colados nas bordas,
  // centro no meio exato da tela (spacers dividiam o espaco livre
  // e o lado mais largo, SSID longo, deslocava o centro).
  Item {
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    height: Theme.barH
    anchors.leftMargin: 6
    anchors.rightMargin: 6
    anchors.topMargin: 2
    anchors.bottomMargin: 2

    // ---- esquerda: updates + tray ----
    Item {
      id: leftBlock
      height: 36
      width: leftRow.implicitWidth + 24
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      // bloco secundario: Number barato (spring fica so nas pills e no workspace ativo)
      Behavior on width {
        NumberAnimation {
          duration: Theme.animNormal
          easing.type: Easing.OutCubic
        }
      }
      RowLayout {
        id: leftRow
        anchors.centerIn: parent
        spacing: 8
        UpdatesPill {
          tip: root.tip
        }
        TrayItems {
          tip: root.tip
          onMenuRequested: (item, pos) => root.trayMenuRequested(item, pos)
        }
      }
    }

    // ---- centro: clock + workspaces + audio + backlight ----
    Item {
      id: centerBlock
      height: 36
      width: centerRow.implicitWidth + 24
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.verticalCenter: parent.verticalCenter
      RowLayout {
        id: centerRow
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 8
        ClockLabel {
          tip: root.tip
        }
        WorkspaceStrip {
          screen: root.screen
        }
        AudioPill {
          tip: root.tip
          onClicked: root.audioMenuRequested()
        }
        BacklightPill {
          tip: root.tip
        }
      }
    }

    // ---- direita: rede + bateria + notif + lock + power ----
    Item {
      height: 36
      width: rightRow.implicitWidth + 24
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      Behavior on width {
        NumberAnimation {
          duration: Theme.animNormal
          easing.type: Easing.OutCubic
        }
      }
      RowLayout {
        id: rightRow
        anchors.centerIn: parent
        spacing: 10
        RecordIndicator {
          tip: root.tip
        }
        WifiStatus {
          tip: root.tip
          onClicked: root.netMenuRequested()
        }
        BatteryPill {
          tip: root.tip
        }
        NotifButton {
          onClicked: root.notifCenterRequested()
        }
        SessionButtons {
          onPowerClicked: root.powerMenuRequested()
        }
      }
    }
  }
}
