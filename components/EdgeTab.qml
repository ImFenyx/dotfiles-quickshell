import QtQuick
import QtQuick.Shapes

// Aba colada no filete direito da moldura (toasts e centro de notificacoes).
// O corpo nasce do filete e, em cima e embaixo, concorda com ele por uma
// curva concava ("orelha") com o raio dos cantos da moldura, em arco circular.
// Fica a `ear` de altura acima e abaixo do corpo,
// entao a altura util do conteudo e height - 2 * ear.
//
// Geometria (x cresce para a direita; a borda da tela e x = width):
//   [ corpo ......... ][ filete ]   o filete (`edge`) sobrepoe o da EdgeFrame,
//                                   mesma cor opaca = sem emenda.
Shape {
  id: root

  property color color: Theme.surface
  property real edge: Theme.edge     // largura do filete da moldura
  property real ear: Theme.frameR    // raio da concordancia com o filete (= cantos da moldura)
  property real radius: Theme.shape.popup   // cantos do lado de dentro da tela

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
    PathArc {
      x: root.bx - root.ear
      y: root.ear
      radiusX: root.ear
      radiusY: root.ear
    }
    // topo do corpo e canto superior esquerdo
    PathLine {
      x: root.radius
      y: root.ear
    }
    PathArc {
      x: 0
      y: root.ear + root.radius
      radiusX: root.radius
      radiusY: root.radius
      direction: PathArc.Counterclockwise
    }
    // lateral esquerda
    PathLine {
      x: 0
      y: root.height - root.ear - root.radius
    }
    // canto inferior esquerdo e base do corpo
    PathArc {
      x: root.radius
      y: root.height - root.ear
      radiusX: root.radius
      radiusY: root.radius
      direction: PathArc.Counterclockwise
    }
    PathLine {
      x: root.bx - root.ear
      y: root.height - root.ear
    }
    // orelha inferior: da base do corpo de volta ao filete
    PathArc {
      x: root.bx
      y: root.height
      radiusX: root.ear
      radiusY: root.ear
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
