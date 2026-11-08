import QtQuick

// Camada de estado do M3 (DESIGN.md › Estados): a cor do conteudo por cima do container,
// com o alpha do estado (tokens.json > state: hover 0,08, foco e press 0,10). O fundo do
// container nao muda; hover, foco de teclado e clique saem daqui em toda a shell.
// Uso: 1o filho do Rectangle do fundo (fica por baixo do conteudo):
//   StateLayer { hovered: area.containsMouse; pressed: area.pressed }
//   tint = a cor do conteudo (on_*): fgPrimary sobre primary, fgSurface sobre surface...
Rectangle {
  property bool hovered: false
  property bool pressed: false
  property bool focused: false          // foco de teclado (setas nos menus, PopupBase)
  property color tint: Theme.fgSurface

  anchors.fill: parent
  radius: parent && parent.radius !== undefined ? parent.radius : 0
  color: tint
  opacity: pressed ? Theme.stateAlpha.pressed : (focused ? Theme.stateAlpha.focus : (hovered ? Theme.stateAlpha.hover : 0))
  Behavior on opacity {
    NumberAnimation {
      duration: Theme.animFast
    }
  }
}
