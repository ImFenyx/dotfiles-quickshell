import QtQuick
import Quickshell

// Zonas de exclusao invisiveis (modelo caelestia Exclusions.qml): janelas
// 1x1 com mascara vazia que so reservam espaco para o tiling. O visual
// continua Ignore (posicao exata); a reserva vive aqui, entao baixar o
// gaps_out abaixo de edge nao deixa a janela invadir o filete. O topo
// dispensa fantasma: a propria barra ja reserva barH + scoop.
Scope {
  id: root

  required property var screen

  Variants {
    model: ["left", "right", "bottom"]
    delegate: Component {
      PanelWindow {
        required property string modelData
        screen: root.screen
        anchors.left: modelData === "left"
        anchors.right: modelData === "right"
        anchors.bottom: modelData === "bottom"
        implicitWidth: 1
        implicitHeight: 1
        exclusiveZone: Theme.edge
        mask: Region {}
        color: "transparent"
      }
    }
  }
}
