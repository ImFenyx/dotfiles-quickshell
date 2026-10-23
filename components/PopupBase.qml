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
// Tres formatos de fundo: notch pendurado na barra (padrao), colado embaixo
// (`fromBottom`) e aba colada no filete direito (`fromRight`, EdgeTab: slide
// horizontal; padTop/padBottom devem incluir a orelha da concordancia).
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
  property bool fromRight: false       // true = aba no filete direito, abre p/ a esquerda
  property bool asyncShape: true
  property bool pill: false            // fundo em pilula solta (sem notch)

  property int topY: Theme.barH
  property int tuck: 0                 // 1px p/ dentro da borda (mesma cor = sem hairline)
  property real panelWidth: 270
  property real panelX: (width - panelWidth) / 2
  property int padTop: 14
  property int padBottom: 10
  property int padX: 18
  property int padRight: padX          // fromRight: some o filete aqui (edge + respiro)
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
    if (fromBottom)
      return `M0,${h} L${w},${h} C${w - 2},${h} ${bx},${h - k * 0.25} ${bx},${h - k} L${bx},${r} Q${bx},0 ${bx - r},0 L${f + r},0 Q${f},0 ${f},${r} L${f},${h - k} C${f},${h - k * 0.25} 2,${h} 0,${h} Z`;
    return `M0,0 L${w},0 C${w - 2},0 ${bx},${k * 0.25} ${bx},${k} L${bx},${h - r} Q${bx},${h} ${bx - r},${h} L${f + r},${h} Q${f},${h} ${f},${h - r} L${f},${k} C${f},${k * 0.25} 2,0 0,0 Z`;
  }

  anchors.top: true
  anchors.bottom: true
  anchors.left: true
  anchors.right: true
  margins.top: 0
  implicitWidth: 0
  implicitHeight: 0
  WlrLayershell.layer: WlrLayer.Overlay
  // teclado (Esc, campos de texto): com interatividade None o foco depende do
  // focus grab ganhar a corrida com o 1o commit, e um app do tray pode roubar o
  // teclado ao abrir o menu dele (OnDemand nao bastou). Exclusive enquanto aberto:
  // o popup e modal (backdrop), entao segurar o teclado e o comportamento certo.
  WlrLayershell.keyboardFocus: (interactive && open) ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
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

  // Focus grab so depois de mapear: com a camada Exclusive o Hyprland, ao mapear,
  // derruba um grab que ainda nao contem a superficie -> onCleared fechava o menu
  // na hora ("abre e fecha"). 50ms = alguns quadros depois do 1o commit.
  property bool grabArmed: false
  onOpenChanged: {
    grabArmed = false;
    if (open)
      grabDelay.restart();
  }
  Timer {
    id: grabDelay
    interval: 50
    onTriggered: root.grabArmed = root.open
  }

  HyprlandFocusGrab {
    active: root.interactive && root.open && root.grabArmed
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
    x: root.panelX
    y: root.fromBottom ? root.height - height + root.tuck : root.topY - root.tuck
    visible: root.offsetScale < 1

    Item {
      width: parent.width
      height: parent.height
      x: root.fromRight ? width * root.offsetScale : 0
      y: root.fromRight ? 0 : (root.fromBottom ? 1 : -1) * height * root.offsetScale

      Shape {
        id: bgShape
        anchors.fill: parent
        visible: !root.fromRight && !root.pill
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

      // pill solta: circulo de verdade (o Q do path era parabola, ~1px fora)
      Rectangle {
        anchors.fill: parent
        visible: root.pill
        radius: height / 2
        color: root.menuBg
      }

      EdgeTab {
        anchors.fill: parent
        visible: root.fromRight
        color: root.menuBg
      }

      ColumnLayout {
        id: slot
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: root.padTop
        anchors.leftMargin: root.padX
        anchors.rightMargin: root.padRight
        spacing: 2
      }
    }
  }
}
