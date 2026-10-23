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
  readonly property var battery: ["\uf244", "\uf243", "\uf242", "\uf241", "\uf240"]

  // OSD de teclas de trava (Material Design do Nerd Font, conferidos desenhando)
  readonly property string capsLock: "\u{F0632}"
  readonly property string numLock: "\u{F03A0}"
  readonly property string fnLock: "\u{F0295}"

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

  // centro de notificacoes
  readonly property string bellSlash: "\uf1f6"
  readonly property string close: "\uf00d"
  readonly property string trash: "\uf1f8"
  readonly property string play: "\uf04b"
  readonly property string pause: "\uf04c"
  readonly property string prev: "\uf048"
  readonly property string next: "\uf051"
  readonly property string music: "\uf001"
  readonly property string video: "\uf03d"
  readonly property string mediaGeneric: "\uf144"
  readonly property string chevronUp: "\uf106"
  readonly property string send: "\uf1d8"
  readonly property string micOff: "\uf131"

  // atalhos do centro
  readonly property string bluetooth: "\uf293"
  readonly property string coffee: "\uf0f4"
  readonly property string moon: "\uf186"
  readonly property string bolt: "\uf0e7"
  readonly property string leaf: "\uf06c"
  readonly property string balance: "\uf24e"

  // launcher / menus
  readonly property string search: "\uf002"
  readonly property string calculator: "\uf1ec"
  readonly property string smile: "\uf118"
  readonly property string kaomoji: "\uf075"
  readonly property string clipboard: "\uf0ea"
  readonly property string window: "\uf2d0"
  readonly property string image: "\uf03e"
  readonly property string check: "\uf00c"
  readonly property string chevronRight: "\uf105"
  readonly property string chevronDown: "\uf107"
  readonly property string arrowUp: "\u{F0143}"
  readonly property string arrowDown: "\u{F0140}"
  readonly property string padlock: "\u{F033E}"
  readonly property string wifiOff: "\u{F092E}"
  readonly property string shield: "\uf132"

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
