import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.components

// Menu nativo do tray (StatusNotifierItem / DBusMenu): botao direito abre
// as opcoes que o app expoe. Os niveis (e submenus, em qualquer profundidade)
// ficam em TrayMenuLevel, que e recursivo e anima a altura do painel.
PopupBase {
  id: root

  panelWidth: 280
  panelX: Math.max(8, Math.min(root.width - panelWidth - 8, anchorX - panelWidth / 2))
  // a altura anima quadro a quadro: o fundo e redesenhado a cada frame,
  // entao nada de shape assincrono (ficaria um quadro atras do conteudo)
  asyncShape: false

  property var trayItem: null
  property real anchorX: 0

  function show(item, p) {
    trayItem = item;
    // multi-monitor: p vem de mapToGlobal (desktop). Converte p/ local da tela
    // (ShellScreen.x = origem do monitor, ex. HDMI em -1920).
    const sx = (root.screen && root.screen.x !== undefined) ? root.screen.x : 0;
    anchorX = p ? p.x - sx : root.width / 2;
    open = true;
  }
  onOpenChanged: {
    if (!open)
      trayItem = null;   // destroi os niveis: expansoes voltam fechadas
  }

  TrayMenuLevel {
    menu: root.trayItem ? root.trayItem.menu : null
    popup: root
  }
}
