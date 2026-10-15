import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland

// Moldura de janela unica (modelo caelestia ContentWindow, sem o plugin
// SDF): filetes laterais + inferior + dobras internas arredondadas num so
// Shape (GPU, CurveRenderer). Mesma geometria do Canvas anterior, mas sem
// repaint na CPU: o path e binding e so re-triangula ao redimensionar.
// Click-through.
PanelWindow {
  id: root
  anchors.top: true
  anchors.bottom: true
  anchors.left: true
  anchors.right: true
  exclusionMode: ExclusionMode.Ignore
  mask: Region {}
  color: "transparent"

  property color bg: "#ff1e1e2e"
  property int edge: 8
  property int topH: 64 // barH + scoop: a faixa da barra e dela, aqui recorta
  property int bendR: 8 // raio interno da dobra inferior (= scoop - edge)

  Shape {
    id: frame
    anchors.fill: parent
    preferredRendererType: Shape.CurveRenderer

    ShapePath {
      strokeWidth: 0
      strokeColor: "transparent"
      fillColor: root.bg
      pathHints: ShapePath.PathSolid & ShapePath.PathNonIntersecting

      startX: 0
      startY: root.topH
      // filete esquerdo (desce ate a dobra)
      PathLine {
        x: root.edge
        y: root.topH
      }
      PathLine {
        x: root.edge
        y: frame.height - root.edge - root.bendR
      }
      // dobra inferior esquerda
      PathQuad {
        x: root.edge + root.bendR
        y: frame.height - root.edge
        controlX: root.edge
        controlY: frame.height - root.edge
      }
      // filete inferior
      PathLine {
        x: frame.width - root.edge - root.bendR
        y: frame.height - root.edge
      }
      // dobra inferior direita
      PathQuad {
        x: frame.width - root.edge
        y: frame.height - root.edge - root.bendR
        controlX: frame.width - root.edge
        controlY: frame.height - root.edge
      }
      // filete direito (sobe ate a barra)
      PathLine {
        x: frame.width - root.edge
        y: root.topH
      }
      PathLine {
        x: frame.width
        y: root.topH
      }
      // contorno externo: desce a lateral, fecha por baixo e volta
      PathLine {
        x: frame.width
        y: frame.height
      }
      PathLine {
        x: 0
        y: frame.height
      }
      PathLine {
        x: 0
        y: root.topH
      }
    }
  }
}
