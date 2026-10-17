pragma Singleton

import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick

// Barra coberta (fullscreen)? So muda o formato do OSD (pill solta x notch).
//
// Antes: a cada troca de foco um "hyprctl -j activewindow" (fork+exec+parse).
// Agora o estado de cada janela fica em cache e so se consulta quando nao da
// para saber. O cache e exato porque TODA mudanca de fullscreen emite o evento
// "fullscreen": ele incrementa uma "epoca" e invalida o cache inteiro (as
// proximas janelas focadas sao consultadas de novo). Entre eventos de
// fullscreen, alternar foco entre janelas ja vistas nao abre processo nenhum.
// toplevels.lastIpcObject e snapshot STALE no qs 0.3.1, por isso o hyprctl.
Singleton {
  id: root

  property bool barHidden: false

  property string addr: ""          // janela ativa (endereco sem 0x)
  property int epoch: 0             // sobe a cada evento "fullscreen"
  property var cache: ({})          // endereco -> { fs: bool, epoch: int }

  function remember(address, fs) {
    if (address === "")
      return;
    root.cache[address] = {
      fs: fs,
      epoch: root.epoch
    };
  }

  Connections {
    target: Hyprland
    function onRawEvent(event) {
      const n = event.name;
      if (n === "activewindowv2") {
        root.addr = event.data;
        if (root.addr === "") {
          root.barHidden = false;     // sem janela focada
          return;
        }
        const c = root.cache[root.addr];
        if (c && c.epoch === root.epoch)
          root.barHidden = c.fs;      // conhecido: sem processo
        else
          debounce.restart();
      } else if (n === "fullscreen") {
        root.epoch++;
        root.barHidden = event.data === "1";
        root.remember(root.addr, root.barHidden);
      } else if (n === "closewindow") {
        delete root.cache[event.data];
      }
    }
  }

  Timer {
    id: debounce
    interval: 150
    onTriggered: {
      query.running = false;
      query.running = true;
    }
  }

  Process {
    id: query
    command: ["hyprctl", "-j", "activewindow"]
    running: true     // estado inicial
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          const j = JSON.parse(text);
          const a = (j.address || "").replace(/^0x/, "");
          // so vale se ainda for a janela ativa (o foco pode ter mudado)
          if (root.addr === "" || a === root.addr) {
            root.addr = a;
            root.barHidden = (j.fullscreen ?? 0) > 1;
            root.remember(a, root.barHidden);
          }
        } catch (e) {}
      }
    }
  }
}
