import QtQuick
import QtQuick.Layouts
import qs.components

// Painel de submenu flutuante, ao lado do pai (estilo menu de contexto).
// Vive na camada flutuante do PopupBase, em coordenadas da janela. Entra
// deslizando de TRAS do pai (spring, como o painel principal sai da barra).
// Quem posiciona (x/lado) e o TrayMenu; aqui so o y (alinhado a linha ancora,
// preso as bordas) e a animacao.
Item {
  id: fly

  property var entry: null          // QsMenuEntry cujo submenu este painel mostra
  property var popup: null
  property var activeEntry: null    // entrada deste painel com submenu aberto
  property real anchorY: 0          // topo da linha ancora, em coordenadas da janela
  property var place: ({
      x: 0,
      dir: 1
    })                              // x final e lado (+1 direita, -1 esquerda)
  property real gap: 6
  property real layerHeight: 0
  property real minY: 0
  readonly property int padding: 8

  signal submenuRequested(var entry, real anchorY)
  signal submenuDismissed

  // 0 = escondido atras do pai, 1 = no lugar
  property real reveal: 0
  Component.onCompleted: reveal = 1
  Behavior on reveal {
    SpringAnimation {
      spring: 6
      damping: 0.8
      epsilon: 0.001
    }
  }

  width: 240
  height: list.implicitHeight + 2 * padding
  x: place.x - place.dir * (1 - reveal) * (width + gap)
  y: Math.max(minY, Math.min(layerHeight - height - 8, anchorY - padding))
  Behavior on y {
    NumberAnimation {
      duration: 120
      easing.type: Easing.OutCubic
    }
  }

  Rectangle {
    anchors.fill: parent
    radius: 16
    color: Theme.base
  }

  TrayMenuList {
    id: list
    x: fly.padding
    y: fly.padding
    width: fly.width - 2 * fly.padding
    menu: fly.entry
    popup: fly.popup
    activeEntry: fly.activeEntry
    onSubmenuRequested: (e, row) => {
      if (fly.parent)
        fly.submenuRequested(e, row.mapToItem(fly.parent, 0, 0).y);
    }
    onSubmenuDismissed: fly.submenuDismissed()
  }
}
