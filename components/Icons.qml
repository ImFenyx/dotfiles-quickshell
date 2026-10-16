pragma Singleton

import QtQuick
import Quickshell

// Glifos Nerd Font + helper de nivel. Sempre via escape (\u...): glifos
// literais da Private Use Area somem facilmente ao copiar/colar ou formatar.
Singleton {
  // niveis (do menor p/ o maior)
  readonly property var volume: ["\uf026", "\uf027", "\uf028"]
  readonly property var backlight: ["\ue38d", "\ue3d3", "\ue3d1", "\ue3cf", "\ue3ce", "\ue3cd", "\ue3ca", "\ue3c8", "\ue39b"]
  readonly property var wifi: ["\u{F091F}", "\u{F0922}", "\u{F0925}", "\u{F0928}"]

  // barra
  readonly property string volumeMuted: "\uf026"
  readonly property string volumeDefault: "\uf028"
  readonly property string backlightDefault: "\ue38d"
  readonly property string mic: "\uf130"
  readonly property string plug: "\u{F140B}"
  readonly property string updatesAvailable: "\u{F1377}"
  readonly property string updatesNone: "\u{F00AA}"
  readonly property string workspaceSpecial: "\uef3e"
  readonly property string bell: "\uf0a2"
  readonly property string lock: "\uf023"
  readonly property string power: "\u23fb"

  // launcher / menus
  readonly property string search: "\uf002"
  readonly property string check: "\uf00c"
  readonly property string chevronRight: "\uf105"
  readonly property string chevronDown: "\uf107"
  readonly property string arrowUp: "\u{F0143}"
  readonly property string arrowDown: "\u{F0140}"
  readonly property string padlock: "\u{F033E}"
  readonly property string wifiOff: "\u{F092E}"

  // powermenu
  readonly property string shutdown: "\u{F0425}"
  readonly property string reboot: "\u{F0709}"
  readonly property string suspend: "\u{F0904}"
  readonly property string logout: "\u{F0343}"

  // netmenu (no repo original esses icones estavam vazios: o glifo se perdeu)
  readonly property string netWifi: "\uf1eb"
  readonly property string netScan: "\uf021"
  readonly property string netNone: "\uf05e"
  readonly property string netDisconnect: "\uf127"
  readonly property string netGlobe: "\uf0ac"
  readonly property string netInfo: "\uf05a"
  readonly property string netEdit: "\uf040"

  // pct (0..100) -> um item da lista, clamp nas pontas
  function level(pct, icons) {
    const i = Math.max(0, Math.min(icons.length - 1, Math.floor(pct / 100 * icons.length)));
    return icons[i];
  }
}
