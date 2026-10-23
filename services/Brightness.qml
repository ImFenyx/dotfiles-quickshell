pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import qs.components

// Brilho via sysfs com FileView: `brightness` e vigiado por inotify (escrever
// pelo brightnessctl/logind gera MODIFY; `actual_brightness` nao), entao o valor
// e ao vivo e sem processo. OSD so pelo IPC (osd.showBright), p/ nao pipocar
// quando o hypridle escurece a tela.
Singleton {
  id: root

  property string dir: ""           // /sys/class/backlight/<dev>/ ("" = sem backlight)
  readonly property int pct: {
    const b = parseInt(cur.text(), 10), m = parseInt(max.text(), 10);
    return (dir === "" || isNaN(b) || !(m > 0)) ? -1 : Math.round(100 * b / m);
  }
  readonly property string text: pct < 0 ? "--" : pct + "%"
  readonly property string icon: pct < 0 ? "" : Icons.level(pct, Icons.backlight)

  signal shown(int pct, string icon)

  // chamado pelo atalho de brilho (IPC): le na hora (o inotify pode chegar
  // depois) e mostra o OSD
  function showOsd() {
    cur.reload();
    if (pct >= 0)
      shown(pct, icon || Icons.backlightDefault);
  }

  // 1o dispositivo de /sys/class/backlight (so o glob do sh, sem ls/cut)
  Process {
    command: ["sh", "-c", "set -- /sys/class/backlight/*/; [ -d \"$1\" ] && printf %s \"$1\""]
    running: true
    stdout: StdioCollector {
      onStreamFinished: root.dir = text
    }
  }

  FileView {
    id: max
    path: root.dir === "" ? "" : root.dir + "max_brightness"
    blockLoading: true
  }
  FileView {
    id: cur
    path: root.dir === "" ? "" : root.dir + "brightness"
    blockLoading: true
    watchChanges: true
    onFileChanged: reload()
  }
}
