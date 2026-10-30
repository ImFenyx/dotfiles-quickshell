import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland

// Moldura (modelo caelestia ContentWindow, sem o plugin SDF): filetes laterais e
// inferior + os quatro cantos internos num so Shape (GPU, CurveRenderer), comecando
// na base da barra (sem sobrepor a barra: com vidro, sobreposicao dobra o alfa).
// Cantos em arco circular de raio Theme.frameR, concentricos ao canto das janelas.
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

  property color bg: Theme.surface
  readonly property int e: Theme.edge
  readonly property int top: Theme.barH
  readonly property int r: Theme.frameR

  Shape {
    id: frame
    anchors.fill: parent
    preferredRendererType: Shape.CurveRenderer

    ShapePath {
      strokeWidth: 0
      strokeColor: "transparent"
      fillColor: root.bg
      pathHints: ShapePath.PathSolid | ShapePath.PathNonIntersecting

      startX: 0
      startY: root.top
      // base da barra ate o canto superior esquerdo
      PathLine { x: root.e + root.r; y: root.top }
      PathArc { x: root.e; y: root.top + root.r; radiusX: root.r; radiusY: root.r; direction: PathArc.Counterclockwise }
      // filete esquerdo e canto inferior esquerdo
      PathLine { x: root.e; y: frame.height - root.e - root.r }
      PathArc { x: root.e + root.r; y: frame.height - root.e; radiusX: root.r; radiusY: root.r; direction: PathArc.Counterclockwise }
      // filete inferior e canto inferior direito
      PathLine { x: frame.width - root.e - root.r; y: frame.height - root.e }
      PathArc { x: frame.width - root.e; y: frame.height - root.e - root.r; radiusX: root.r; radiusY: root.r; direction: PathArc.Counterclockwise }
      // filete direito e canto superior direito
      PathLine { x: frame.width - root.e; y: root.top + root.r }
      PathArc { x: frame.width - root.e - root.r; y: root.top; radiusX: root.r; radiusY: root.r; direction: PathArc.Counterclockwise }
      // base da barra ate a borda e contorno externo
      PathLine { x: frame.width; y: root.top }
      PathLine { x: frame.width; y: frame.height }
      PathLine { x: 0; y: frame.height }
      PathLine { x: 0; y: root.top }
    }
  }
}
