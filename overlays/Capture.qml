import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs.components
import qs.services

// Captura (Print) e gravacao (Shift+Print): a tela congela (grim) e escurece; arrastar =
// regiao, mouse sobre uma janela destaca e clique captura ela, Enter = tela toda, Esc ou
// clique direito cancela. Screenshot: recorta, copia e salva em ~/Imagens/Screenshots.
// Gravacao: a mesma escolha vira a area do gpu-screen-recorder (services/Recorder).
PanelWindow {
  id: root

  WlrLayershell.namespace: "quickshell:capture"
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
  exclusionMode: ExclusionMode.Ignore
  anchors.top: true
  anchors.bottom: true
  anchors.left: true
  anchors.right: true
  color: "transparent"
  visible: open

  property bool open: false
  property string mode: "shot"          // shot | record
  property rect sel: Qt.rect(0, 0, 0, 0)
  property bool dragging: false
  property point origin: Qt.point(0, 0)
  property var windows: []              // janelas visiveis neste monitor (coordenadas da tela)

  readonly property var monitor: screen ? Hyprland.monitorFor(screen) : null
  readonly property real scaleF: monitor ? monitor.scale : 1
  readonly property string tmp: Quickshell.env("XDG_RUNTIME_DIR") + "/eco-captura.png"
  readonly property string outDir: Quickshell.env("HOME") + "/Imagens/Screenshots"

  function start(m) {
    if (open) {          // o mesmo atalho de novo cancela
      close();
      return;
    }
    mode = m;
    sel = Qt.rect(0, 0, 0, 0);
    dragging = false;
    Hyprland.refreshToplevels();
    grim.command = ["grim", "-o", screen.name, tmp];
    grim.running = true;
  }
  // tela inteira na hora, sem escolher
  function quick() {
    save(["grim", "-o", screen.name, "$out"]);
  }
  function close() {
    open = false;
  }

  function visibleWindows() {
    const ws = monitor && monitor.activeWorkspace ? monitor.activeWorkspace.name : "";
    const out = [];
    for (const t of Hyprland.toplevels.values) {
      const i = t.lastIpcObject;
      if (!i || !i.at || !i.workspace || i.workspace.name !== ws || i.hidden)
        continue;
      out.push({ r: Qt.rect(i.at[0] - monitor.x, i.at[1] - monitor.y, i.size[0], i.size[1]), floating: i.floating });
    }
    // flutuantes por cima: testadas primeiro
    return out.sort((a, b) => (b.floating ? 1 : 0) - (a.floating ? 1 : 0));
  }
  function windowAt(x, y) {
    for (const w of windows) {
      if (x >= w.r.x && x < w.r.x + w.r.width && y >= w.r.y && y < w.r.y + w.r.height)
        return w.r;
    }
    return null;
  }

  // salva + copia + avisa; $out vira o arquivo final
  function save(cmd) {
    const sh = 'out="' + outDir + '/captura_$(date +%F_%H-%M-%S).png"; mkdir -p "' + outDir + '" && ' + cmd.join(" ") + ' && wl-copy -t image/png < "$out" && notify-send -a Captura -i "$out" "Captura copiada" "Salva em ~/Imagens/Screenshots"';
    Quickshell.execDetached(["sh", "-c", sh]);
  }
  function finish(r) {
    close();
    if (r.width < 4 || r.height < 4)
      return;
    if (mode === "record") {
      const full = r.x <= 0 && r.y <= 0 && r.width >= width && r.height >= height;
      if (full)
        Recorder.startMonitor(screen.name);
      else
        Recorder.startRegion(Math.round(monitor.x + r.x), Math.round(monitor.y + r.y), Math.round(r.width), Math.round(r.height));
      return;
    }
    const s = scaleF;
    const geo = Math.round(r.width * s) + "x" + Math.round(r.height * s) + "+" + Math.round(r.x * s) + "+" + Math.round(r.y * s);
    save(["magick", '"' + tmp + '"', "-crop", geo, "+repage", '"$out"']);
  }

  Process {
    id: grim
    onExited: code => {
      if (code !== 0)
        return;
      frozen.source = "";
      frozen.source = "file://" + root.tmp;
      root.windows = root.visibleWindows();
      root.open = true;
    }
  }

  // tela congelada
  Image {
    id: frozen
    anchors.fill: parent
    cache: false
    fillMode: Image.Stretch
  }

  // escurece fora da selecao (4 faixas; sem selecao, a tela toda)
  readonly property color dim: Qt.alpha(Theme.scrim, 0.5)
  Rectangle {
    color: root.dim
    x: 0
    y: 0
    width: parent.width
    height: root.sel.width > 0 ? root.sel.y : parent.height
  }
  Rectangle {
    visible: root.sel.width > 0
    color: root.dim
    x: 0
    y: root.sel.y + root.sel.height
    width: parent.width
    height: parent.height - y
  }
  Rectangle {
    visible: root.sel.width > 0
    color: root.dim
    x: 0
    y: root.sel.y
    width: root.sel.x
    height: root.sel.height
  }
  Rectangle {
    visible: root.sel.width > 0
    color: root.dim
    x: root.sel.x + root.sel.width
    y: root.sel.y
    width: parent.width - x
    height: root.sel.height
  }
  // borda da selecao + tamanho
  Rectangle {
    visible: root.sel.width > 0
    x: root.sel.x - 2
    y: root.sel.y - 2
    width: root.sel.width + 4
    height: root.sel.height + 4
    color: "transparent"
    border.width: 2
    border.color: root.mode === "record" ? Theme.error : Theme.primary
  }
  Rectangle {
    visible: root.sel.width > 0
    x: Math.min(root.sel.x, parent.width - width - Theme.space.sm)
    y: root.sel.y + root.sel.height + Theme.space.sm + height > parent.height ? root.sel.y - height - Theme.space.sm : root.sel.y + root.sel.height + Theme.space.sm
    implicitWidth: size.implicitWidth + 2 * Theme.space.md
    implicitHeight: 26
    radius: height / 2
    color: Theme.surface
    UiText {
      id: size
      anchors.centerIn: parent
      font.pixelSize: Theme.type.label_l
      text: Math.round(root.sel.width * root.scaleF) + " × " + Math.round(root.sel.height * root.scaleF)
    }
  }

  // dica embaixo
  Rectangle {
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: parent.bottom
    anchors.bottomMargin: Theme.space.xxl
    implicitWidth: hint.implicitWidth + 2 * Theme.space.lg
    implicitHeight: 36
    radius: height / 2
    color: Theme.surface
    UiText {
      id: hint
      anchors.centerIn: parent
      color: root.mode === "record" ? Theme.error : Theme.fgSurface
      text: (root.mode === "record" ? "Gravar: " : "") + "arraste uma região · clique numa janela · Enter tela toda · Esc cancela"
    }
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    cursorShape: Qt.CrossCursor
    onPressed: m => {
      if (m.button === Qt.RightButton) {
        root.close();
        return;
      }
      root.origin = Qt.point(m.x, m.y);
      root.dragging = false;
    }
    onPositionChanged: m => {
      if (pressed && (root.dragging || Math.hypot(m.x - root.origin.x, m.y - root.origin.y) > 4)) {
        root.dragging = true;
        root.sel = Qt.rect(Math.min(m.x, root.origin.x), Math.min(m.y, root.origin.y), Math.abs(m.x - root.origin.x), Math.abs(m.y - root.origin.y));
      } else if (!pressed) {
        root.sel = root.windowAt(m.x, m.y) ?? Qt.rect(0, 0, 0, 0);
      }
    }
    onReleased: m => {
      if (m.button !== Qt.LeftButton)
        return;
      if (root.dragging)
        root.finish(root.sel);
      else {
        const w = root.windowAt(m.x, m.y);
        if (w)
          root.finish(w);
      }
    }
  }

  Item {
    focus: root.open
    Keys.onPressed: event => {
      if (event.key === Qt.Key_Escape)
        root.close();
      else if (event.key === Qt.Key_Enter || event.key === Qt.Key_Return)
        root.finish(Qt.rect(0, 0, root.width, root.height));
      else
        return;
      event.accepted = true;
    }
  }
}
