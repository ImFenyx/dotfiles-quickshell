import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.components

// Menu nativo do tray (StatusNotifierItem / DBusMenu), como um menu de
// contexto: o painel principal (colado na barra) lista o 1o nivel; entradas
// com submenu abrem outro painel AO LADO (hover ou clique), em cascata, na
// profundidade que o app expuser (ate maxFly niveis). Cada nivel e um
// TrayFlyout na camada flutuante do PopupBase (fora do clip do painel
// principal); abrem e fecham com o efeito magic lamp.
PopupBase {
  id: root

  panelWidth: 280
  panelX: Math.max(8, Math.min(root.width - panelWidth - 8, anchorX - panelWidth / 2))

  property var trayItem: null
  property real anchorX: 0

  // Cascata: chain[i] = { entry, y } -> o painel flutuante i mostra o submenu
  // de "entry", alinhado a y (topo da linha, coordenadas da janela).
  // Os paineis sao um conjunto FIXO (maxFly): cada um recebe "request" (ou null)
  // e anima sozinho a entrada/saida; trocar a entrada de um nivel reaproveita
  // o painel (ele so segue a nova linha).
  property var chain: []
  readonly property int depth: chain.length
  readonly property int maxFly: 8
  readonly property int flyWidth: 240
  readonly property int flyGap: 4

  function show(item, p) {
    chain = [];
    trayItem = item;
    // multi-monitor: p vem de mapToGlobal (desktop). Converte p/ local da tela
    // (ShellScreen.x = origem do monitor, ex. HDMI em -1920).
    const sx = (root.screen && root.screen.x !== undefined) ? root.screen.x : 0;
    anchorX = p ? p.x - sx : root.width / 2;
    open = true;
  }
  onOpenChanged: {
    if (!open) {
      trayItem = null;
      chain = [];
    }
  }

  // abre (ou troca) o submenu do nivel pai "parentLevel" (0 = painel principal)
  function openSubmenu(parentLevel, entry, anchorY) {
    const cur = chain[parentLevel];
    if (cur && cur.entry === entry)
      return;
    chain = chain.slice(0, parentLevel).concat([
      {
        entry: entry,
        y: anchorY
      }
    ]);
  }
  // fecha o submenu do nivel pai e todos os mais fundos
  function closeSubmenusFrom(parentLevel) {
    if (chain.length > parentLevel)
      chain = chain.slice(0, parentLevel);
  }

  // x final e lado do painel i: abre a direita do pai; sem espaco, inverte p/ a
  // esquerda. Niveis mais fundos herdam o lado e so invertem se nao couber.
  function flyPlace(i) {
    let left = panelX, right = panelX + panelWidth, dir = 1, x = 0;
    for (let k = 0; k <= i; k++) {
      if (dir > 0) {
        x = right + flyGap;
        if (x + flyWidth > width - 8) {
          dir = -1;
          x = left - flyGap - flyWidth;
        }
      } else {
        x = left - flyGap - flyWidth;
        if (x < 8) {
          dir = 1;
          x = right + flyGap;
        }
      }
      left = x;
      right = x + flyWidth;
    }
    return {
      x: x,
      dir: dir
    };
  }

  TrayMenuList {
    menu: root.trayItem ? root.trayItem.menu : null
    popup: root
    activeEntry: root.chain.length > 0 ? root.chain[0].entry : null
    onSubmenuRequested: (entry, row) => root.openSubmenu(0, entry, row.mapToItem(root.floatLayer, 0, 0).y)
    onSubmenuDismissed: root.closeSubmenusFrom(0)
  }

  // os paineis (e o menu do app em cada um) so existem com o menu visivel
  floating: Repeater {
    model: root.visible ? root.maxFly : 0
    delegate: TrayFlyout {
      id: fly
      required property int index
      request: index < root.chain.length ? root.chain[index] : null
      activeEntry: root.chain[index + 1] ? root.chain[index + 1].entry : null
      place: root.flyPlace(index)
      popup: root
      width: root.flyWidth
      gap: root.flyGap
      layerHeight: root.height
      minY: root.topY
      z: -index   // niveis mais fundos ficam atras (cada um nasce de tras do pai)
      onSubmenuRequested: (e, y) => root.openSubmenu(index + 1, e, y)
      onSubmenuDismissed: root.closeSubmenusFrom(index + 1)
    }
  }
}
