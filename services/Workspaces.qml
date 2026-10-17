pragma Singleton

import Quickshell
import Quickshell.Hyprland
import QtQuick

// Lista ordenada de workspaces, calculada uma vez para todas as telas.
// Reativa por si so: Hyprland.workspaces.values muda ao criar/fechar
// workspace e cada w.name e propriedade observavel.
Singleton {
  id: root

  readonly property var sorted: {
    const ws = [...Hyprland.workspaces.values];
    const key = w => {
      if (w.name.startsWith("special:"))
        return 1e9;
      const n = parseInt(w.name, 10);
      return isNaN(n) ? 1e9 - 1 : n;
    };
    ws.sort((a, b) => (key(a) - key(b)) || ((a.name < b.name) ? -1 : 1));
    return ws;
  }
}
