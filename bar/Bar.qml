import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.components

// Barra colada no topo + scoops invertidos (RoundCorner) nas pontas, fluindo
// para as laterais da tela. Tudo dentro da propria janela.
// Medidas em Theme (derivadas do gaps_out do Hyprland, modules/look.lua).
//
// Os widgets vivem em bar/*.qml; esta janela so compoe. Os cliques que abrem
// menus saem como sinais — quem coordena os menus e o shell.qml.
PanelWindow {
  id: root

  required property var tip   // TipWindow desta tela

  signal trayMenuRequested(var item, var pos)
  signal netMenuRequested
  signal powerMenuRequested

  anchors.top: true
  anchors.left: true
  anchors.right: true
  // a propria barra reserva barH + scoop (exclusionMode Auto)
  implicitHeight: Theme.barH + Theme.scoop
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
      color: Theme.base
    }

    // decoradores: curva concava da ponta da barra ate a lateral da tela.
    // Encaixe exato, sem stroke e sem sobrepor (o fundo pode ser translucido:
    // qualquer sobreposicao dobra o alfa e vira linha).
    Item {
      anchors.top: barContent.bottom
      anchors.left: parent.left
      anchors.right: parent.right
      height: Theme.scoop
      RoundCorner {
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        implicitSize: Theme.scoop
        tail: Theme.edge
        color: Theme.base
        borderWidth: 0
        corner: RoundCorner.CornerEnum.TopLeft
      }
      RoundCorner {
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        implicitSize: Theme.scoop
        tail: Theme.edge
        color: Theme.base
        borderWidth: 0
        corner: RoundCorner.CornerEnum.TopRight
      }
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
      height: 36
      width: leftRow.implicitWidth + 24
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      // bloco secundario: Number barato (spring fica so nas pills e no workspace ativo)
      Behavior on width {
        NumberAnimation {
          duration: 150
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
        WorkspaceStrip {}
        AudioPill {
          tip: root.tip
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
          duration: 150
          easing.type: Easing.OutCubic
        }
      }
      RowLayout {
        id: rightRow
        anchors.centerIn: parent
        spacing: 10
        WifiStatus {
          tip: root.tip
          onClicked: root.netMenuRequested()
        }
        BatteryPill {
          tip: root.tip
        }
        NotifButton {}
        SessionButtons {
          onPowerClicked: root.powerMenuRequested()
        }
      }
    }
  }
}
