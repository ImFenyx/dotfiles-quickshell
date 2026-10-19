pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// "Cafeina": impede a ociosidade (hypridle/logind) enquanto estiver ligada.
// Segura um inhibitor do systemd num processo que fica lendo o stdin: se a
// shell morrer o pipe fecha, o `read` termina e o inhibitor cai junto (sem
// processo orfao).
Singleton {
  id: root

  property bool on: false

  function toggle() {
    on = !on;
  }

  Process {
    command: ["systemd-inhibit", "--what=idle", "--who=quickshell", "--why=Cafeina ligada", "--mode=block", "sh", "-c", "read _"]
    stdinEnabled: true
    running: root.on
    // morreu sozinho (sem systemd-inhibit, p.ex.): apaga o botao
    onExited: {
      if (root.on)
        root.on = false;
    }
  }
}
