import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.components

// Powermenu (substitui rofi/extensions/powermenu.sh).
// 2 cliques p/ acao destrutiva: arma, confirma.
PopupBase {
  id: root

  panelWidth: 270
  panelX: root.width - panelWidth - 8

  property string armed: ""

  function toggle() {
    if (open) {
      close();
    } else {
      armed = "";
      open = true;
    }
  }
  onOpenChanged: {
    if (!open)
      armed = "";
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
      label: armed ? "Confirmar " + modelData.label.toLowerCase() + "?" : modelData.label
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
