pragma Singleton

import QtQuick
import Quickshell

// Programas externos chamados pela shell. Troque aqui, nao nos widgets.
Singleton {
  readonly property var terminal: ["kitty", "-e"]   // prefixo p/ rodar um comando em terminal
  readonly property var updater: terminal.concat(["paru"])
  readonly property string mixer: "pavucontrol"
  readonly property var locker: ["qs", "ipc", "call", "lock", "lock"]   // overlays/Lock; fallback: ["hyprlock"]
  readonly property string connectionEditor: "nm-connection-editor"
  readonly property string bluetoothManager: "blueman-manager"
  readonly property string powerManager: "tlpui"
  readonly property int nightTemp: 4000                            // luz noturna (K); hyprsunset: 1000-20000
  readonly property var batteryWarn: [20, 10, 5]                   // % que avisam ao descer na bateria; <= 10 = critica
  // protecao de volume (services/Audio): subir mais que isso (%) de uma vez, de fora da
  // shell, volta ao nivel anterior (as teclas sobem 5%); teto em %, 0 = sem teto (as
  // teclas vao ate 150: -l 1.5 no keybindings.lua; o teto vale p/ elas e p/ o mixer)
  readonly property int volumeGuardStep: 10
  readonly property int volumeGuardMax: 0
  // seletor de wallpaper (Super+Shift+W): pasta e comando de aplicar (o caminho vai no fim)
  readonly property string wallpaperDir: "/mnt/dados/wallpapers"
  readonly property var wallpaperApply: ["awww", "img", "--transition-type", "center", "--transition-duration", "1.2", "--transition-fps", "60"]
  // video: "mpvpaper" (VA-API pelo mpv: ~28% de 1 nucleo medido) ou "gslapper" (sem o
  // gst-plugin-va decodifica na CPU: ~68%)
  readonly property string wallpaperVideoPlayer: "mpvpaper"
}
