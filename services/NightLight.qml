pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import qs.components

// Luz noturna via hyprsunset (programa em Config.nightLight): o daemon fica
// vivo enquanto a luz esta ligada, encerrar restaura a tela. So aparece se o
// programa existir.
Singleton {
  id: root

  property bool on: false
  property bool available: false

  function toggle() {
    if (available)
      on = !on;
  }

  Process {
    command: ["sh", "-c", "command -v \"$1\" >/dev/null 2>&1", "sh", Config.nightLight[0]]
    running: true
    onExited: code => root.available = code === 0
  }

  Process {
    command: Config.nightLight
    running: root.on
    onExited: {
      if (root.on)
        root.on = false;
    }
  }
}
