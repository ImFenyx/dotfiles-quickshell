pragma Singleton

import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick

// Workspaces compartilhados por todas as telas: lista ordenada + qual
// special workspace (scratchpad "magic" etc.) esta aberto.
// A lista e reativa por si so: Hyprland.workspaces.values muda ao criar/fechar
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

  // ---- special workspace aberto ----
  // O special aparece POR CIMA do workspace normal: o workspace focado nao muda,
  // entao o botao do special nunca acendia. O evento activespecial diz qual
  // special esta visivel em cada monitor ("special:magic,DP-1"; fechar manda
  // o nome vazio: ",DP-1"). Sem processo: so eventos (+ 1 leitura no inicio).
  property var specialByMonitor: ({})
  // special visivel no monitor focado ("" = nenhum). Acompanha o workspace normal
  // ativo, que tambem e o do monitor focado.
  readonly property string activeSpecial: {
    const m = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : "";
    return specialByMonitor[m] || "";
  }

  Connections {
    target: Hyprland
    function onRawEvent(event) {
      if (event.name !== "activespecial")
        return;
      const d = event.data;
      const i = d.lastIndexOf(",");
      const name = i >= 0 ? d.slice(0, i) : d;
      const mon = i >= 0 ? d.slice(i + 1) : "";
      const next = Object.assign({}, root.specialByMonitor);
      next[mon] = name;
      root.specialByMonitor = next;
    }
  }

  // estado inicial (se a shell reiniciar com um special aberto)
  Process {
    command: ["hyprctl", "-j", "monitors"]
    running: true
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          const next = {};
          for (const m of JSON.parse(text))
            next[m.name] = (m.specialWorkspace && m.specialWorkspace.name) || "";
          root.specialByMonitor = next;
        } catch (e) {}
      }
    }
  }
}
