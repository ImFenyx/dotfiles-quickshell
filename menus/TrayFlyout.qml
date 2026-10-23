import QtQuick
import QtQuick.Layouts
import qs.components

// Painel de submenu flutuante, ao lado do pai (estilo menu de contexto).
// Vive na camada flutuante do PopupBase, em coordenadas da janela.
//
// Existe sempre (o TrayMenu cria um conjunto fixo) e so aparece enquanto
// "request" != null. Abrir e fechar usam o efeito magic lamp (Genie): o painel
// nasce da linha do pai, vira funil e abre; ao fechar e sugado de volta.
// Fechado, mantem o ultimo conteudo ate a animacao de saida acabar.
Item {
  id: fly

  property var request: null        // { entry, y } do TrayMenu; null = nao quer aberto
  property var popup: null
  property var activeEntry: null    // entrada deste painel com submenu aberto
  property var place: ({
      x: 0,
      dir: 1
    })                              // x final e lado (+1 direita, -1 esquerda)
  property real gap: 4
  property real layerHeight: 0
  property real minY: 0

  readonly property bool wanted: request !== null
  readonly property int padding: 8
  readonly property real rowHeight: 32   // altura da linha do pai (origem do funil)

  // ultimo conteudo/ancora, retidos durante a animacao de saida
  property var shownEntry: null
  property real anchorY: 0
  onRequestChanged: {
    if (request) {
      shownEntry = request.entry;
      anchorY = request.y;
    }
  }

  signal submenuRequested(var entry, real anchorY)
  signal submenuDismissed

  // 0 = recolhido na origem, 1 = aberto. Abrir: desacelera ao chegar;
  // fechar: acelera ao ser sugado.
  property real progress: wanted ? 1 : 0
  Behavior on progress {
    NumberAnimation {
      duration: fly.wanted ? 320 : 240
      easing.type: fly.wanted ? Easing.OutCubic : Easing.InOutQuad
    }
  }
  onProgressChanged: {
    if (progress === 0 && !wanted)
      shownEntry = null;   // libera o menu do app
  }

  visible: progress > 0.001
  width: 240
  height: list.implicitHeight + 2 * padding
  x: place.x
  // seguir a nova linha so com o painel ja aberto (na abertura ele ja nasce no lugar)
  y: Math.max(minY, Math.min(layerHeight - height - 8, anchorY - padding))
  Behavior on y {
    enabled: fly.progress > 0.999
    NumberAnimation {
      duration: Theme.animFast
      easing.type: Easing.OutCubic
    }
  }

  Item {
    id: content
    anchors.fill: parent
    // sem hover/clique enquanto o painel anima
    enabled: fly.wanted && fly.progress > 0.999

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
      menu: fly.shownEntry
      popup: fly.popup
      activeEntry: fly.activeEntry
      onSubmenuRequested: (e, row) => {
        if (fly.parent)
          fly.submenuRequested(e, row.mapToItem(fly.parent, 0, 0).y);
      }
      onSubmenuDismissed: fly.submenuDismissed()
    }
  }

  Genie {
    source: content
    // abrindo: conteudo ainda pode chegar (menu do app); fechando: estatico
    live: fly.wanted
    progress: fly.progress
    dir: fly.place.dir
    // a origem fica um pouco por baixo do pai (que e opaco e fica por cima)
    originX: fly.place.dir > 0 ? -fly.gap - 6 : fly.width + fly.gap + 6
    originY: fly.anchorY + fly.rowHeight / 2 - fly.y
    originHeight: fly.rowHeight
  }
}
