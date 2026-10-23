import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.components

// Powermenu (substitui rofi/extensions/powermenu.sh).
// 2 cliques p/ acao destrutiva: arma, confirma. Ao armar checa o que se perderia
// (scripts/power-check.sh) e o confirmar vira aviso; continua 2 cliques.
PopupBase {
  id: root

  panelWidth: 270
  panelX: root.width - panelWidth - 8

  property string armed: ""
  property var warns: []     // saida do power-check: o mais importante 1o

  function toggle() {
    if (open) {
      close();
    } else {
      armed = "";
      warns = [];
      open = true;
    }
  }
  onOpenChanged: {
    if (!open)
      armed = "";
  }
  // Dormir checa igual: suspender derruba a rede (download falha) e deixa o
  // pacman congelado no meio, dependendo da bateria aguentar.
  // Ja rodando = no-op (o resultado nao depende de qual acao armou).
  onArmedChanged: {
    if (armed !== "")
      check.running = true;
  }

  Process {
    id: check
    command: ["sh", Quickshell.shellPath("scripts/power-check.sh")]
    stdout: StdioCollector {
      onStreamFinished: root.warns = text.split("\n").filter(l => l !== "")
    }
  }

  Repeater {
    model: [
      {
        id: "shutdown",
        label: "Desligar",
        icon: Icons.shutdown,
        cmd: ["systemctl", "poweroff"]
      },
      {
        id: "reboot",
        label: "Reiniciar",
        icon: Icons.reboot,
        cmd: ["systemctl", "reboot"]
      },
      {
        id: "suspend",
        label: "Dormir",
        icon: Icons.suspend,
        cmd: ["systemctl", "suspend"]
      },
      {
        id: "logout",
        label: "Sair",
        icon: Icons.logout,
        cmd: ["sh", "-c", "uwsm check is-active >/dev/null 2>&1 && uwsm stop || hyprctl dispatch 'hl.dsp.exit()'"]
      }
    ]
    delegate: MenuRow {
      id: row
      required property var modelData
      popup: root
      keepOpen: true
      armed: root.armed === modelData.id
      icon: modelData.icon
      // com aviso: o mais importante (+ quantos mais) em cima, a pergunta embaixo
      label: {
        const w = root.warns;
        if (!armed)
          return modelData.label;
        if (w.length === 0)
          return "Confirmar " + modelData.label.toLowerCase() + "?";
        return w[0] + (w.length > 1 ? ` (+${w.length - 1})` : "") + "\n" + modelData.label + " mesmo assim?";
      }
      onFired: {
        if (armed) {
          Quickshell.execDetached(modelData.cmd);
          root.close();
        } else {
          root.armed = modelData.id;
        }
      }
    }
  }
}
