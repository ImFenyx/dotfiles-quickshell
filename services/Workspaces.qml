pragma Singleton

import Quickshell
import Quickshell.Hyprland
import QtQuick

// Lista ordenada de workspaces, calculada uma vez para todas as telas.
Singleton {
  id: root

  // so reordena quando o conjunto de workspaces pode ter mudado.
  // activewindow/fullscreen/focus disparam toda hora e nao afetam a ordem.
  // TODO: Hyprland.workspaces.values ja e reativo; testar remover o rev.
  property int rev: 0

  Connections {
    target: Hyprland
    function onRawEvent(event) {
      const n = event.name || "";
      if (n.indexOf("workspace") !== -1 || n.indexOf("special") !== -1 || n === "openwindow" || n === "closewindow" || n === "movewindowv2")
        root.rev++;
    }
  }

  readonly property var sorted: {
    void rev; // reordena ao adicionar/remover workspace
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
