pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import qs.components

// Estado do Wi-Fi para a barra. Event-driven (nmcli monitor, com respawn e
// debounce) + fallback de 30s. Antes o monitor nunca voltava se morresse e o
// rádio so era relido a cada 30s.
Singleton {
  id: root

  property bool on: true
  property string name: "--"
  property string strength: ""       // "72%" ou "" (nao da p/ chamar de "signal": palavra reservada)
  property string icon: ""

  onOnChanged: refresh()

  function refresh() {
    connProc.running = true;
    radioProc.running = true;
  }

  Process {
    id: connProc
    command: ["sh", "-c", "nmcli -t -f IN-USE,SSID,SIGNAL dev wifi list --rescan no 2>/dev/null | grep '^\\*:' | head -n1"]
    // StdioCollector (e nao SplitParser): dispara mesmo com saida vazia,
    // senao ao desconectar o SSID antigo ficava preso na pill.
    stdout: StdioCollector {
      onStreamFinished: {
        const m = text.trim().match(/^\*:([^:]*):(\d+)/m);
        if (!root.on || !m) {
          root.name = root.on ? "--" : "off";
          root.strength = "";
          root.icon = "";
          return;
        }
        const sig = parseInt(m[2], 10);
        root.name = m[1] || "--";
        root.strength = isNaN(sig) ? "" : sig + "%";
        root.icon = isNaN(sig) ? "" : Icons.level(sig, Icons.wifi);
      }
    }
  }

  Process {
    id: radioProc
    command: ["nmcli", "radio", "wifi"]
    stdout: SplitParser {
      onRead: data => {
        root.on = data.trim() === "enabled";
      }
    }
  }

  // nmcli monitor cospe varias linhas por evento: debounce.
  Timer {
    id: debounce
    interval: 250
    onTriggered: root.refresh()
  }
  Process {
    id: monitor
    command: ["nmcli", "monitor"]
    running: true
    stdout: SplitParser {
      onRead: debounce.restart()
    }
    // se o monitor morrer (NetworkManager reiniciou), volta em 3s
    onExited: respawn.start()
  }
  Timer {
    id: respawn
    interval: 3000
    onTriggered: monitor.running = true
  }

  // fallback caso algum evento escape
  Timer {
    interval: 30000
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }
}
