pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import qs.components

// Perfil de energia do TLP (>= 1.9) via `tlpctl`, o cliente sem root do tlp-pd:
// o servico que o TLP traz no lugar do power-profiles-daemon (os dois nao
// convivem; ative com `systemctl enable --now tlp-pd`). So aparece em maquina
// com bateria e com `tlpctl` instalado; com o tlp-pd parado o atalho mostra
// "tlp-pd parado" e nao troca nada.
// O TLP tambem muda de perfil sozinho ao ligar/desligar o carregador, entao o
// estado e relido ao abrir o centro, ao mudar o carregador e apos cada troca.
Singleton {
  id: root

  property bool installed: false
  property string profile: ""          // performance | balanced | power-saver | "" (desconhecido)

  readonly property bool available: Battery.present && installed
  readonly property bool balanced: profile === "balanced"
  readonly property string label: profile === "power-saver" ? "Economia" : (profile === "performance" ? "Desempenho" : (profile === "balanced" ? "Equilibrado" : "tlp-pd parado"))
  readonly property string icon: profile === "power-saver" ? Icons.leaf : (profile === "performance" ? Icons.bolt : Icons.balance)

  function refresh() {
    if (installed && !reader.running)
      reader.running = true;
  }

  // economia -> equilibrado -> desempenho -> economia
  function cycle() {
    const next = profile === "power-saver" ? "balanced" : (profile === "balanced" ? "performance" : (profile === "performance" ? "power-saver" : "balanced"));
    Quickshell.execDetached(["tlpctl", "set", next]);
    profile = next;   // otimista; a releitura confirma (ou volta p/ "tlp-pd parado")
    settle.restart();
  }

  Process {
    command: ["sh", "-c", "command -v tlpctl >/dev/null 2>&1"]
    running: true
    onExited: code => {
      root.installed = code === 0;
      if (root.installed)
        root.refresh();
    }
  }

  Process {
    id: reader
    command: ["tlpctl", "get"]
    stdout: StdioCollector {
      onStreamFinished: {
        const t = text.trim();
        root.profile = ["performance", "balanced", "power-saver"].indexOf(t) >= 0 ? t : "";
      }
    }
    onExited: code => {
      if (code !== 0)
        root.profile = "";
    }
  }

  Timer {
    id: settle
    interval: 1200
    onTriggered: root.refresh()
  }

  Connections {
    target: Battery
    function onChargingChanged() {
      settle.restart();
    }
  }
}
