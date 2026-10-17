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

  // Sem "sh -c ... | grep | head": 1 processo em vez de 4. O nmcli -t escapa ':'
  // e '\\' dentro dos campos (SSID com ':' vem como "a\\:b"), por isso o parse.
  function parseConn(text) {
    for (const line of text.split("\n")) {
      const m = line.match(/^\*:((?:\\.|[^:\\])*):(\d+)/);
      if (m)
        return {
          ssid: m[1].replace(/\\(.)/g, "$1"),
          sig: parseInt(m[2], 10)
        };
    }
    return null;
  }

  Process {
    id: connProc
    command: ["nmcli", "-t", "-f", "IN-USE,SSID,SIGNAL", "dev", "wifi", "list", "--rescan", "no"]
    // StdioCollector (e nao SplitParser): dispara mesmo com saida vazia,
    // senao ao desconectar o SSID antigo ficava preso na pill.
    stdout: StdioCollector {
      onStreamFinished: {
        const c = root.parseConn(text);
        if (!root.on || !c) {
          root.name = root.on ? "--" : "off";
          root.strength = "";
          root.icon = "";
          return;
        }
        root.name = c.ssid || "--";
        root.strength = isNaN(c.sig) ? "" : c.sig + "%";
        root.icon = isNaN(c.sig) ? "" : Icons.level(c.sig, Icons.wifi);
      }
    }
    stderr: StdioCollector {}
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

  // Fallback caso algum evento escape. O nmcli monitor ja cobre tudo; 30s aqui
  // acordava a CPU e abria 3 processos 120x/hora sem necessidade. Alem disso o
  // hover no SSID releh na hora (WifiStatus -> Wifi.refresh).
  Timer {
    interval: 300000
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }
}
