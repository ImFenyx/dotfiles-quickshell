import QtQuick
import QtQuick.Shapes

// Cotovelo solido estendido da barra (estilo caelestia/noctalia/end-4).
// Topo cheio encostado na barra, curva concava ate a base na largura
// do filete (tail) que continua na lateral da tela. Sem vao.
Item {
  id: root

  enum CornerEnum { TopLeft, TopRight }
  property var corner: RoundCorner.CornerEnum.TopLeft
  property int implicitSize: 16
  property int tail: 6
  property color color: Theme.base
  property color borderColor: "transparent"
  property int borderWidth: 0

  implicitWidth: implicitSize
  implicitHeight: implicitSize

  property bool isLeft: corner === RoundCorner.CornerEnum.TopLeft

  Shape {
    anchors {
      top: parent.top
      left: root.isLeft ? parent.left : undefined
      right: root.isLeft ? undefined : parent.right
    }
    width: root.implicitSize
    height: root.implicitSize
    preferredRendererType: Shape.CurveRenderer

    ShapePath {
      strokeWidth: root.borderWidth
      strokeColor: root.borderColor
      fillColor: root.color
      pathHints: ShapePath.PathSolid | ShapePath.PathNonIntersecting

      // canto interno (topo, lado da tela)
      startX: root.isLeft ? 0 : root.implicitSize
      startY: 0
      // topo cheio ate a ponta da barra
      PathLine {
        x: root.isLeft ? root.implicitSize : 0
        y: 0
      }
      // curva concava descendo ate a largura do filete
      PathQuad {
        x: root.isLeft ? root.tail : root.implicitSize - root.tail
        y: root.implicitSize
        controlX: root.isLeft ? root.tail : root.implicitSize - root.tail
        controlY: 0
      }
      // base cheia (encontra o filete) e lateral da tela
      PathLine {
        x: root.isLeft ? 0 : root.implicitSize
        y: root.implicitSize
      }
      PathLine {
        x: root.isLeft ? 0 : root.implicitSize
        y: 0
      }
    }
  }
}
