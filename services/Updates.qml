pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import qs.components

// Badge de atualizacoes. Processo unico atomico (scripts/updates.sh):
// 1a linha=total, resto=lista 16. Unico por vez: dois checkupdates
// simultaneos disputam o lock de /tmp/checkup-db e um morre -> badge
// parcial (foi o bug do "7"). Falha -> sem saida -> mantem valor.
Singleton {
  id: root

  property bool known: false
  property bool failed: false        // sem resposta em 25s (offline sem cache): para a animacao
  readonly property bool loading: !known && !failed
  property string count: ""
  property string icon: ""
  property string tip: "…"

  function parse(text) {
    const lines = text.trim().split("\n").filter(l => l.length > 0);
    if (lines.length < 1)
      return;
    const n = parseInt(lines[0], 10);
    if (isNaN(n))
      return;
    known = true;
    failed = false;
    count = String(n);
    icon = n > 0 ? Icons.updatesAvailable : Icons.updatesNone;
    const pkgs = lines.slice(1);
    tip = n === 0 ? "Sistema atualizado" : pkgs.join("\n") + (n > pkgs.length ? "\n+" + (n - pkgs.length) + " outros" : "");
  }

  Process {
    id: poll
    command: ["sh", Quickshell.shellPath("scripts/updates.sh")]
    stdout: StdioCollector {
      onStreamFinished: root.parse(text)
    }
  }

  // Estreia instantanea: le o cache do ultimo poll antes do primeiro check.
  Process {
    command: ["sh", "-c", "cat \"${XDG_STATE_HOME:-$HOME/.local/state}/quickshell/updates-cache\" 2>/dev/null"]
    running: true
    stdout: StdioCollector {
      onStreamFinished: root.parse(text)
    }
  }

  Timer {
    interval: 1800000
    repeat: true
    running: true
    triggeredOnStart: true
    // sem "= false" antes: se um check ainda roda, pula em vez de matar
    // (matar no meio gerava badge parcial).
    onTriggered: poll.running = true
  }

  // sem resposta nem cache: para os pontinhos e mostra "?"
  Timer {
    interval: 25000
    running: root.loading
    onTriggered: {
      root.failed = true;
      root.count = "?";
    }
  }
}
