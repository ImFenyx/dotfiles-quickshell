import QtQuick
import QtQuick.Shapes
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

// Base de todos os popups (NetMenu, TrayMenu, PowerMenu, Osd, Launcher).
// Antes cada um copiava ~60 linhas iguais: janela fullscreen Overlay, mascara
// vazia/cheia, HyprlandFocusGrab, MouseArea de click-fora + Esc, spring do
// offsetScale e o mesmo path SVG do fundo.
//
// Modelo: mascara fixa (clip) + conteudo rigido que desliza dentro dela.
// Filhos declarados em quem usa vao para um ColumnLayout interno (slot).
//
// Desmapeada quando fechada (menos RAM): layerrule noanim p/ namespace
// quickshell evita o fadeLayersIn do Hyprland, o slide continua 100% QML.
// offsetScale<1 mantem mapeada durante a animacao de saida.
PanelWindow {
  id: root

  default property alias content: slot.data
  // Painéis flutuantes (ex.: submenus em cascata): ficam numa camada do tamanho
  // da janela, FORA do clip do painel principal, e atras dele (slide "de tras").
  property alias floating: floatHost.data
  property alias floatLayer: floatHost
  property alias spacing: slot.spacing
  readonly property real contentImplicitWidth: slot.implicitWidth
  readonly property real panelHeight: slot.implicitHeight + padTop + padBottom

  property bool open: false
  property bool interactive: true      // false = click-through (OSD)
  property bool backdropFocus: true    // false = quem usa cuida do foco (Launcher, senha)
  property bool fromBottom: false      // true = colado embaixo, abre p/ cima
  property bool asyncShape: true
  property bool pill: false            // fundo em pilula solta (sem notch)
  // true = a janela tem o tamanho do painel (layer-shell: so topo, centralizada,
  // margem = topY). Para popups sem clique-fora/float (OSD): em vez de uma
  // superficie de tela cheia, ~80x menos pixels por frame de animacao.
  property bool compact: false

  property int topY: Theme.barH
  property int tuck: 0                 // 1px p/ dentro da borda (mesma cor = sem hairline)
  property real panelWidth: 270
  property real panelX: (width - panelWidth) / 2
  property int padTop: 14
  property int padBottom: 10
  property int padX: 18
  property real bendK: 10              // altura da curva do notch
  property color menuBg: Theme.base

  // 0 = aberto, 1 = fechado. close direto: o spring resolve o colapso.
  property real offsetScale: open ? 0 : 1
  Behavior on offsetScale {
    SpringAnimation {
      spring: 6
      damping: 0.8
      epsilon: 0.001
    }
  }

  function close() {
    open = false;
  }

  // Fundo: topo (ou base) reto com notch curvo nas laterais + cantos redondos.
  function shapePath(w, h) {
    const r = 16, f = 8, k = bendK;
    const bx = w - f;
    if (pill) {
      // pill de verdade: radius = meia-altura (cantos totalmente redondos)
      const pr = Math.min(w, h) / 2;
      return `M${pr},0 L${w - pr},0 Q${w},0 ${w},${pr} L${w},${h - pr} Q${w},${h} ${w - pr},${h} L${pr},${h} Q0,${h} 0,${h - pr} L0,${pr} Q0,0 ${pr},0 Z`;
    }
    if (fromBottom)
      return `M0,${h} L${w},${h} C${w - 2},${h} ${bx},${h - k * 0.25} ${bx},${h - k} L${bx},${r} Q${bx},0 ${bx - r},0 L${f + r},0 Q${f},0 ${f},${r} L${f},${h - k} C${f},${h - k * 0.25} 2,${h} 0,${h} Z`;
    return `M0,0 L${w},0 C${w - 2},0 ${bx},${k * 0.25} ${bx},${k} L${bx},${h - r} Q${bx},${h} ${bx - r},${h} L${f + r},${h} Q${f},${h} ${f},${h - r} L${f},${k} C${f},${k * 0.25} 2,0 0,0 Z`;
  }

  anchors.top: true
  anchors.bottom: !compact
  anchors.left: !compact
  anchors.right: !compact
  margins.top: compact ? topY - tuck : 0
  implicitWidth: compact ? panelWidth : 0
  implicitHeight: compact ? panelHeight : 0
  WlrLayershell.layer: WlrLayer.Overlay
  exclusionMode: ExclusionMode.Ignore
  mask: (interactive && open) ? fullMask : emptyMask
  color: "transparent"
  visible: open || offsetScale < 0.999

  Region {
    id: emptyMask
  }
  Region {
    id: fullMask
    x: 0
    y: 0
    width: root.width
    height: root.height
  }

  HyprlandFocusGrab {
    active: root.interactive && root.open
    windows: [QsWindow.window]
    onCleared: root.close()
  }

  MouseArea {
    anchors.fill: parent
    z: -2   // abaixo da camada flutuante (cliques nos submenus nao chegam aqui)
    enabled: root.interactive
    focus: root.open && root.backdropFocus
    Keys.onEscapePressed: root.close()
    onClicked: root.close()
  }

  Item {
    id: floatHost
    anchors.fill: parent
    z: -1   // abaixo do painel principal
  }

  Item {
    width: root.panelWidth
    height: root.panelHeight
    clip: true
    x: root.compact ? 0 : root.panelX
    y: root.compact ? 0 : (root.fromBottom ? root.height - height + root.tuck : root.topY - root.tuck)
    visible: root.offsetScale < 1

    Item {
      width: parent.width
      height: parent.height
      y: (root.fromBottom ? 1 : -1) * height * root.offsetScale

      Shape {
        id: bgShape
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        asynchronous: root.asyncShape
        ShapePath {
          strokeWidth: 0
          strokeColor: "transparent"
          fillColor: root.menuBg
          PathSvg {
            path: root.shapePath(bgShape.width, bgShape.height)
          }
        }
      }

      ColumnLayout {
        id: slot
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: root.padTop
        anchors.leftMargin: root.padX
        anchors.rightMargin: root.padX
        spacing: 2
      }
    }
  }
}
