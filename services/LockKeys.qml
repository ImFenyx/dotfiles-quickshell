pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Caps/Num/Fn Lock p/ o OSD, lendo os LEDs do sysfs (sem processo por tecla).
// - Caps e Num: o bind do Hyprland (Caps_Lock/Num_Lock, sem consumir a tecla, no
//   release) chama o GlobalShortcut "lockkeys" -> check() relê os LEDs.
// - Fn Lock (Fn+Esc no IdeaPad) e do firmware, sem evento de tecla: o
//   ideapad_laptop avisa em brightness_hw_changed, vigiado por inotify.
// Mudou = emite `toggled`; na partida so le o estado (sem OSD).
Singleton {
  id: root

  property string capsPath: ""      // /sys/class/leds/inputN::capslock/brightness
  property string numPath: ""
  readonly property string fnDir: "/sys/class/leds/platform::fnlock/"

  property bool caps: false
  property bool num: false
  property bool fn: false

  signal toggled(string key, bool on)   // key: "caps" | "num" | "fn"

  // FileView.reload() e assincrono: o valor novo so existe no onLoaded (ler logo
  // depois do reload devolvia o anterior: OSD invertido e da tecla de antes).
  // 1o load de cada arquivo = estado inicial (sem OSD); os seguintes vao pro note().
  property var primed: ({})

  function lit(view) {
    return parseInt(view.text(), 10) > 0;
  }
  function loaded(key, view) {
    const on = lit(view);
    if (!primed[key]) {
      primed[key] = true;
      root[key] = on;
      return;
    }
    note(key, on);
  }
  function note(key, on) {
    if (root[key] === on)
      return;
    root[key] = on;
    toggled(key, on);
  }
  // o LED troca no press; o bind roda no release, mas espera um pouco por garantia
  function check() {
    checkLater.restart();
  }

  Timer {
    id: checkLater
    interval: 40
    onTriggered: {
      capsFile.reload();
      numFile.reload();
    }
  }

  // inputN muda conforme o teclado: acha o 1o de cada na partida (so o glob do sh)
  Process {
    command: ["sh", "-c", "for k in capslock numlock; do set -- /sys/class/leds/*::$k; [ -e \"$1\" ] && echo \"$k $1/brightness\"; done"]
    running: true
    stdout: SplitParser {
      onRead: line => {
        const [k, p] = line.split(" ");
        if (k === "capslock")
          root.capsPath = p;
        else if (k === "numlock")
          root.numPath = p;
      }
    }
  }
  FileView {
    id: capsFile
    path: root.capsPath
    onLoaded: root.loaded("caps", capsFile)
  }
  FileView {
    id: numFile
    path: root.numPath
    onLoaded: root.loaded("num", numFile)
  }
  // Fn Lock (so existe em IdeaPad): o estado vem do `brightness`, como Caps/Num.
  FileView {
    id: fnFile
    path: root.fnDir + "brightness"
    printErrors: false
    onLoaded: root.loaded("fn", fnFile)
  }
  // So gatilho, nunca lido: o driver mexe nele quando o firmware troca o Fn Lock.
  // preload: false porque ler da ENODATA ate a 1a troca (e reload() num FileView
  // que nunca carregou nao faz nada, entao quem recarrega e o fnFile).
  FileView {
    path: root.fnDir + "brightness_hw_changed"
    preload: false
    printErrors: false
    watchChanges: true
    onFileChanged: fnFile.reload()
  }
}
