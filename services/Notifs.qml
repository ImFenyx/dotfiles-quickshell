pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Contador do swaync (swaync-client -swb). Volta sozinho se o swaync reiniciar.
Singleton {
  id: root

  property string count: ""

  function toggle() {
    Quickshell.execDetached(["swaync-client", "-t", "-sw"]);
  }

  Process {
    id: proc
    command: ["sh", "-c", "command -v swaync-client >/dev/null || exit 127; exec swaync-client -swb"]
    running: true
    stdout: SplitParser {
      onRead: data => {
        try {
          const j = JSON.parse(data);
          const n = parseInt(j.text, 10);
          root.count = isNaN(n) ? "" : String(n);
        } catch (e) {}
      }
    }
    // 127 = swaync-client nao instalado: nao insiste
    onExited: code => {
      if (code !== 127)
        respawn.start();
    }
  }
  Timer {
    id: respawn
    interval: 5000
    onTriggered: proc.running = true
  }
}
