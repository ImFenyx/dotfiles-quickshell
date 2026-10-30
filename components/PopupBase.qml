import QtQuick
import QtQuick.Shapes
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

// Base de todos os popups (NetMenu, TrayMenu, Osd, Launcher, centro, cheatsheet...).
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
  // panelWidth/panelX = corpo; as abas de encaixe (flare) ficam fora dele.
  // Padding conta da borda do corpo: menu de lista 8 (padrao, linhas de raio 8
  // concentricas ao popup 16), painel 16, dialogo 24 (DESIGN.md).
  property real panelWidth: 270
  property real panelX: (width - panelWidth) / 2
  property int padTop: Theme.space.sm
  property int padBottom: Theme.space.sm
  property int padX: Theme.space.sm
  property int padRight: padX          // fromRight: some o filete aqui (edge + respiro)
  property color menuBg: Theme.surface
  property string layerName: "menu"    // namespace quickshell:<layerName> (regras do Hyprland)
  // Abas de encaixe na barra/filete: arco do raio dos cantos da moldura. Lado colado
  // no filete (dock): sem aba e com canto convexo de raio frameR, que completa o canto
  // interno da moldura (mesmo centro) sem sobrepor a moldura.
  readonly property bool dockLeft: !fromRight && !pill && panelX <= Theme.edge + 0.5
  readonly property bool dockRight: !fromRight && !pill && panelX + panelWidth >= width - Theme.edge - 0.5
  readonly property real flareL: (fromRight || pill || dockLeft) ? 0 : Theme.frameR
  readonly property real flareR: (fromRight || pill || dockRight) ? 0 : Theme.frameR

  // 0 = aberto, 1 = fechado. close direto: o spring resolve o colapso.
  property real offsetScale: open ? 0 : 1
  Behavior on offsetScale {
    SpringPanel {}
  }

  function close() {
    open = false;
  }

  // Fundo, tudo em arco circular: lado encaixado = aba concava (flare); lado colado no
  // filete = canto convexo de raio frameR; base = cantos shape.popup. w inclui as abas.
  // fromBottom = o mesmo desenho espelhado (y -> h - y, sentido dos arcos invertido).
  function shapePath(w, h) {
    const r = Theme.shape.popup, lim = Math.max(0, h - r);
    const R = Math.min(Theme.frameR, lim), fl = Math.min(flareL, lim), fr = Math.min(flareR, lim);
    const bl = fl, br = w - fr;   // bordas do corpo
    const Y = y => fromBottom ? h - y : y;
    const s = v => fromBottom ? 1 - v : v;
    let p = fl > 0 ? `M0,${Y(0)}` : `M0,${Y(R)} A${R},${R} 0 0 ${s(1)} ${R},${Y(0)}`;
    p += fr > 0 ? ` L${w},${Y(0)} A${fr},${fr} 0 0 ${s(0)} ${br},${Y(fr)}` : ` L${w - R},${Y(0)} A${R},${R} 0 0 ${s(1)} ${w},${Y(R)}`;
    p += ` L${br},${Y(h - r)} A${r},${r} 0 0 ${s(1)} ${br - r},${Y(h)} L${bl + r},${Y(h)} A${r},${r} 0 0 ${s(1)} ${bl},${Y(h - r)}`;
    p += fl > 0 ? ` L${bl},${Y(fl)} A${fl},${fl} 0 0 ${s(0)} 0,${Y(0)} Z` : ` L0,${Y(R)} Z`;
    return p;
  }

  anchors.top: true
  anchors.bottom: true
  anchors.left: true
  anchors.right: true
  margins.top: 0
  implicitWidth: 0
  implicitHeight: 0
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.namespace: "quickshell:" + layerName
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
    width: root.panelWidth + root.flareL + root.flareR
    height: root.panelHeight
    clip: true
    x: root.panelX - root.flareL
    // fromBottom: para no topo do filete de baixo (a moldura continua por baixo)
    y: root.fromBottom ? root.height - Theme.edge - height + root.tuck : root.topY - root.tuck
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
        anchors.leftMargin: root.padX + root.flareL
        anchors.rightMargin: root.padRight + root.flareR
        spacing: 2
      }
    }
  }
}
