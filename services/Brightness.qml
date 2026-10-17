pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import qs.components

// Brilho via sysfs. Poll de 30s + leitura sob demanda (IPC osd.showBright).
Singleton {
  id: root

  property string text: "--"
  property string icon: ""
  property bool armed: false         // IPC pediu OSD: mostra assim que ler

  signal shown(int pct, string icon)

  function refresh() {
    proc.running = true;
  }
  // chamado pelo atalho de brilho (IPC): le de novo e mostra o OSD
  function showOsd() {
    armed = true;
    proc.running = false;
    proc.running = true;
  }

  Process {
    id: proc
    command: ["sh", "-c", "d=$(echo /sys/class/backlight/*/ | cut -d' ' -f1); echo $((100 * $(cat ${d}brightness) / $(cat ${d}max_brightness)))"]
    stdout: SplitParser {
      onRead: data => {
        const p = parseInt(data.trim(), 10);
        if (isNaN(p))
          return;
        root.text = p + "%";
        root.icon = Icons.level(p, Icons.backlight);
        if (root.armed) {
          root.armed = false;
          root.shown(p, root.icon || Icons.backlightDefault);
        }
      }
    }
  }

  // Mudancas pelo atalho chamam showOsd (IPC) e o hover na pill relê; este
  // poll so cobre alteracoes externas. Cada refresh abre um sh + 3 cat, entao
  // 30s -> 5min corta ~110 processos/hora em idle.
  Timer {
    interval: 300000
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }
}
