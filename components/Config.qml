pragma Singleton

import QtQuick
import Quickshell

// Programas externos chamados pela shell. Troque aqui, nao nos widgets.
Singleton {
  readonly property var terminal: ["kitty", "-e"]   // prefixo p/ rodar um comando em terminal
  readonly property var updater: terminal.concat(["paru"])
  readonly property string mixer: "pavucontrol"
  readonly property string locker: "hyprlock"
  readonly property string connectionEditor: "nm-connection-editor"
  readonly property string bluetoothManager: "blueman-manager"
  readonly property string powerManager: "tlpui"
  readonly property int nightTemp: 4000                            // luz noturna (K); hyprsunset: 1000-20000
}
