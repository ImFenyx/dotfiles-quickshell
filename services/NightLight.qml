pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import qs.components

// Luz noturna via hyprsunset (comando em Config.nightLight). O daemon e lancado
// DESACOPLADO da shell (execDetached): um Process filho morre junto com o
// Quickshell, e a luz apagava a cada reload/reinicio. O estado nao e guardado
// aqui: `on` e "existe um hyprsunset com exatamente esse comando rodando",
// relido ao iniciar a shell, ao abrir o centro e apos cada clique. Encerrar o
// processo restaura a tela. Nao sobrevive a logout/reboot (o processo morre
// com a sessao). So aparece se o programa existir.
Singleton {
  id: root

  property bool on: false
  property bool available: false

  // linha de comando exata: e o que o pgrep/pkill -x casam (nao mexe em
  // outro hyprsunset que voce rode por fora, com outros argumentos)
  readonly property string cmdLine: Config.nightLight.join(" ")

  function refresh() {
    if (available && !checker.running)
      checker.running = true;
  }

  function toggle() {
    if (!available)
      return;
    if (on)
      Quickshell.execDetached(["pkill", "-fx", cmdLine]);
    else
      Quickshell.execDetached(Config.nightLight);
    on = !on;       // otimista; a releitura corrige se o comando falhar
    settle.restart();
  }

  Process {
    command: ["sh", "-c", "command -v \"$1\" >/dev/null 2>&1", "sh", Config.nightLight[0]]
    running: true
    onExited: code => {
      root.available = code === 0;
      root.refresh();
    }
  }

  Process {
    id: checker
    command: ["pgrep", "-fx", root.cmdLine]
    onExited: code => root.on = code === 0
  }

  // da tempo do hyprsunset subir/cair antes de conferir
  Timer {
    id: settle
    interval: 700
    onTriggered: root.refresh()
  }
}
