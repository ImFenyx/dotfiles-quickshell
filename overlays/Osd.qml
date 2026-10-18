import QtQuick
import QtQuick.Layouts
import qs.components
import qs.services

// OSD fundido na barra (centro, como NetMenu/TrayMenu): slide por altura, sem fade.
// Linha unica compacta: glyph nerd font + % + barra longa. Sem imagens.
// Uma instancia so serve volume, mic e brilho (antes eram 3 janelas, cada uma
// com seu proprio monitor de fullscreen).
PopupBase {
  id: root

  interactive: false       // click-through
  compact: true            // janela do tamanho do OSD, nao de tela cheia
  asyncShape: false
  tuck: 1                  // 1px p/ dentro da barra (mesma cor opaca = sem hairline de AA)
  padTop: 12
  padBottom: 7
  padX: 22
  panelWidth: contentImplicitWidth + 2 * padX
  // barra coberta (fullscreen): OSD vira pill solta, sem notch/fuse
  pill: Fullscreen.barHidden

  property int vol: 0
  property bool muted: false
  property string glyph: ""
  readonly property bool boosted: !muted && vol > 100

  function show(v, m, g) {
    vol = v;
    muted = m;
    glyph = g;
    open = true;
    hideTimer.restart();
  }

  Timer {
    id: hideTimer
    interval: 650
    repeat: false
    onTriggered: root.close()
  }

  RowLayout {
    spacing: 10
    Glyph {
      font.weight: Font.DemiBold
      text: root.glyph
    }
    UiText {
      color: root.boosted ? Theme.red : Theme.text
      font.weight: Font.DemiBold
      text: root.muted ? "Mudo" : root.vol + "%"
    }
    Rectangle {
      Layout.preferredWidth: 300
      Layout.preferredHeight: 10
      Layout.alignment: Qt.AlignVCenter
      radius: 5
      color: Theme.surface1
      Rectangle {
        width: parent.width * (root.muted ? 0 : Math.min(root.vol, 100) / 100)
        height: parent.height
        radius: 5
        color: root.boosted ? Theme.red : Theme.blue
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
