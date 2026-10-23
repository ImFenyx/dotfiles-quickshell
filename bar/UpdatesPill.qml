import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.components
import qs.services

// Badge de atualizacoes (repo + AUR). Enquanto carrega: onda de 3 pontos.
Pill {
  id: root

  property var tip: null
  property int tick: 0

  color: Theme.mauve
  spacing: 5
  tipWindow: root.tip
  tipText: Updates.tip
  clickable: true
  onClicked: Quickshell.execDetached(Config.updater)

  // onda deterministica: um relogio so (tick), fase por aritmetica.
  // Cada ponto ativo 360ms exclusivo, periodo 1080ms. Sem Animation =
  // sem risco de fases iguais. So roda enquanto carrega.
  Timer {
    id: wave
    interval: 120
    running: Updates.loading
    repeat: true
    onTriggered: root.tick++
  }
  Repeater {
    model: [0, 3, 6]
    Item {
      required property int modelData
      visible: Updates.loading
      Layout.preferredWidth: 6
      Layout.preferredHeight: 16
      Text {
        property int ph: (root.tick + parent.modelData) % 9
        anchors.horizontalCenter: parent.horizontalCenter
        y: 5 - 5 * (ph < 3 ? Math.sin(Math.PI * ph / 3) : 0)
        // interpola entre ticks (= intervalo do timer): movimento fluido, sem salto
        Behavior on y {
          NumberAnimation {
            duration: wave.interval
          }
        }
        color: Theme.base
        font.family: Theme.uiFont
        font.pointSize: 11
        font.weight: Font.DemiBold
        text: "\u2022"
      }
    }
  }
  PillText {
    visible: !Updates.loading
    text: Updates.count
  }
  PillGlyph {
    text: Updates.icon
  }
}
