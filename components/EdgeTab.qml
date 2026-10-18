import QtQuick
import QtQuick.Shapes

// Aba colada no filete direito da moldura (toasts e centro de notificacoes).
// O corpo nasce do filete e, em cima e embaixo, concorda com ele por uma
// curva concava ("orelha") do mesmo tipo do scoop da barra: PathQuad com o
// controle no canto interno. Fica a `ear` de altura acima e abaixo do corpo,
// entao a altura util do conteudo e height - 2 * ear.
//
// Geometria (x cresce para a direita; a borda da tela e x = width):
//   [ corpo ......... ][ filete ]   o filete (`edge`) sobrepoe o da EdgeFrame,
//                                   mesma cor opaca = sem emenda.
Shape {
  id: root

  property color color: Theme.base
  property real edge: Theme.edge     // largura do filete da moldura
  property real ear: Theme.scoop     // raio da concordancia com o filete
  property real radius: 18           // cantos do lado de dentro da tela

  // borda interna do filete
  readonly property real bx: width - edge

  preferredRendererType: Shape.CurveRenderer

  ShapePath {
    strokeWidth: 0
    strokeColor: "transparent"
    fillColor: root.color

    // topo, sobre o filete
    startX: root.width
    startY: 0
    PathLine {
      x: root.bx
      y: 0
    }
    // orelha superior: do filete para o topo do corpo
    PathQuad {
      x: root.bx - root.ear
      y: root.ear
      controlX: root.bx
      controlY: root.ear
    }
    // topo do corpo e canto superior esquerdo
    PathLine {
      x: root.radius
      y: root.ear
    }
    PathQuad {
      x: 0
      y: root.ear + root.radius
      controlX: 0
      controlY: root.ear
    }
    // lateral esquerda
    PathLine {
      x: 0
      y: root.height - root.ear - root.radius
    }
    // canto inferior esquerdo e base do corpo
    PathQuad {
      x: root.radius
      y: root.height - root.ear
      controlX: 0
      controlY: root.height - root.ear
    }
    PathLine {
      x: root.bx - root.ear
      y: root.height - root.ear
    }
    // orelha inferior: da base do corpo de volta ao filete
    PathQuad {
      x: root.bx
      y: root.height
      controlX: root.bx
      controlY: root.height - root.ear
    }
    // base, sobre o filete, e fecha
    PathLine {
      x: root.width
      y: root.height
    }
    PathLine {
      x: root.width
      y: 0
    }
  }
}
