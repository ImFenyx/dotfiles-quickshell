import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets
import qs.components
import qs.services

// Overview (SUPER+A): os workspaces do monitor focado em miniatura, com as janelas ao
// vivo (ScreencopyView) na posicao real. Clique na janela foca nela; clique no fundo vai
// para o workspace; arrastar a janela para outro workspace move (sem seguir). Setas
// escolhem o workspace, Enter vai, Esc fecha. As capturas so existem com o painel visivel.
PopupBase {
  id: root
  layerName: "overview"

  // pela tela: a largura da janela so existe depois de mapear (0 no toggle)
  panelWidth: Math.min((screen ? screen.width : 1366) - 2 * (Theme.edge + Theme.frameR), 1180)
  padTop: Theme.space.lg
  padBottom: Theme.space.lg
  padX: Theme.space.lg
  backdropFocus: false     // o foco e do item de teclado abaixo

  readonly property var monitor: Hyprland.focusedMonitor
  readonly property real monX: monitor ? monitor.x : 0
  readonly property real monY: monitor ? monitor.y : 0
  readonly property real monW: monitor ? monitor.width / monitor.scale : 1366
  readonly property real monH: monitor ? monitor.height / monitor.scale : 768
  readonly property var list: Workspaces.sorted.filter(w => !String(w.name).startsWith("special:") && (!monitor || !w.monitor || w.monitor === monitor))
  readonly property int cols: list.length <= 2 ? 2 : 3
  readonly property real gap: Theme.space.lg
  readonly property real tileW: (panelWidth - 2 * padX - (cols - 1) * gap) / cols
  readonly property real s: tileW / monW
  property int sel: 0
  // A captura nao acompanha a janela que muda de tamanho (fica cinza). Depois de mover,
  // abrir ou fechar janela, o layout muda na hora mas cada app redesenha no seu tempo
  // (navegador ~0,5 s): desliga e religa as capturas aos 0,2 s e de novo a 1 s.
  property bool capturing: true

  function recapture() {
    Hyprland.refreshToplevels();
    capturing = false;
    recaptureOn.restart();
  }

  function wsArg(w) {
    return isNaN(Number(w.name)) ? JSON.stringify(String(w.name)) : String(w.name);
  }
  function toggle() {
    if (open) {
      close();
      return;
    }
    Hyprland.refreshToplevels();   // posicoes (lastIpcObject) atualizadas
    const cur = monitor && monitor.activeWorkspace ? monitor.activeWorkspace.name : "";
    sel = Math.max(0, list.findIndex(w => w.name === cur));
    open = true;
  }
  function go(w) {
    close();
    Hyprland.dispatch("hl.dsp.focus({ workspace = " + wsArg(w) + " })");
  }
  function focusWindow(t) {
    close();
    Hyprland.dispatch("hl.dsp.focus({ window = \"address:0x" + t.address + "\" })");
  }
  function moveWindow(t, w) {
    Hyprland.dispatch("hl.dsp.window.move({ window = \"address:0x" + t.address + "\", workspace = " + wsArg(w) + ", follow = false })");
  }
  // miniatura sob o ponto p (coordenadas do board)
  function tileAt(p) {
    for (let i = 0; i < tiles.count; i++) {
      const t = tiles.itemAt(i);
      if (t && t.contains(t.mapFromItem(board, p.x, p.y)))
        return t;
    }
    return null;
  }

  Connections {
    target: Hyprland
    function onRawEvent(event) {
      if (root.open && ["movewindowv2", "openwindow", "closewindow"].includes(event.name)) {
        recaptureSoon.restart();
        recaptureLate.restart();
      }
    }
  }
  Timer {
    id: recaptureSoon
    interval: 200
    onTriggered: root.recapture()
  }
  Timer {
    id: recaptureLate
    interval: 1000
    onTriggered: root.recapture()
  }
  Timer {
    id: recaptureOn
    interval: 50
    onTriggered: root.capturing = true
  }

  Item {
    focus: root.open
    Keys.onEscapePressed: root.close()
    Keys.onPressed: event => {
      const n = root.list.length;
      if (n === 0)
        return;
      if (event.key === Qt.Key_Left)
        root.sel = Math.max(0, root.sel - 1);
      else if (event.key === Qt.Key_Right)
        root.sel = Math.min(n - 1, root.sel + 1);
      else if (event.key === Qt.Key_Up)
        root.sel = Math.max(0, root.sel - root.cols);
      else if (event.key === Qt.Key_Down)
        root.sel = Math.min(n - 1, root.sel + root.cols);
      else if (event.key === Qt.Key_Enter || event.key === Qt.Key_Return)
        root.go(root.list[root.sel]);
      else
        return;
      event.accepted = true;
    }
  }

  Item {
    id: board
    Layout.alignment: Qt.AlignHCenter
    implicitWidth: grid.implicitWidth
    implicitHeight: grid.implicitHeight

    GridLayout {
      id: grid
      columns: root.cols
      columnSpacing: root.gap
      rowSpacing: root.gap

      Repeater {
        id: tiles
        model: root.visible ? root.list : []

        Rectangle {
          id: tile
          required property var modelData
          required property int index
          readonly property bool current: root.monitor && root.monitor.activeWorkspace && root.monitor.activeWorkspace.name === modelData.name

          Layout.preferredWidth: root.tileW
          Layout.preferredHeight: root.monH * root.s
          radius: Theme.shape.md
          color: Theme.surfaceContainer
          border.width: root.sel === index ? 2 : 0
          border.color: Theme.primary
          clip: true

          MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: root.sel = tile.index
            onClicked: root.go(tile.modelData)
          }

          Repeater {
            model: tile.modelData.toplevels ? tile.modelData.toplevels.values : []

            ClippingRectangle {
              id: win
              required property var modelData
              readonly property var ipc: modelData.lastIpcObject
              visible: !!(ipc && ipc.at && ipc.size) && !ipc.hidden
              x: visible ? (ipc.at[0] - root.monX) * root.s : 0
              y: visible ? (ipc.at[1] - root.monY) * root.s : 0
              width: visible ? ipc.size[0] * root.s : 0
              height: visible ? ipc.size[1] * root.s : 0
              z: visible && ipc.floating ? 2 : 1
              radius: Theme.shape.xs
              color: Theme.surfaceContainerHighest
              border.width: winArea.containsMouse ? 2 : 0
              border.color: Theme.primary

              ScreencopyView {
                id: shot
                anchors.fill: parent
                captureSource: root.capturing ? win.modelData.wayland : null
                live: root.open
              }
              MouseArea {
                id: winArea
                property point grab
                property bool dragged: false
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: dragged && pressed ? Qt.ClosedHandCursor : Qt.PointingHandCursor
                onEntered: root.sel = tile.index
                onPressed: m => {
                  grab = Qt.point(m.x, m.y);
                  dragged = false;
                }
                onPositionChanged: m => {
                  if (!pressed)
                    return;
                  if (!dragged && Math.hypot(m.x - grab.x, m.y - grab.y) > 6) {
                    dragged = true;
                    ghost.width = win.width;
                    ghost.height = win.height;
                    ghost.shot = shot;
                  }
                  if (dragged) {
                    const p = win.mapToItem(board, m.x, m.y);
                    ghost.x = p.x - grab.x;
                    ghost.y = p.y - grab.y;
                    const t = root.tileAt(p);
                    if (t)
                      root.sel = t.index;
                  }
                }
                onReleased: m => {
                  if (!dragged)
                    return;
                  const t = root.tileAt(win.mapToItem(board, m.x, m.y));
                  ghost.shot = null;
                  if (t && t.modelData !== tile.modelData)
                    root.moveWindow(win.modelData, t.modelData);
                }
                onClicked: {
                  if (!dragged)
                    root.focusWindow(win.modelData);
                }
              }
            }
          }

          // numero do workspace por cima das janelas
          Rectangle {
            z: 10
            x: Theme.space.sm
            y: Theme.space.sm
            implicitWidth: label.implicitWidth + 2 * Theme.space.sm
            implicitHeight: 22
            radius: height / 2
            color: tile.current ? Theme.primary : Theme.surface
            UiText {
              id: label
              anchors.centerIn: parent
              color: tile.current ? Theme.fgPrimary : Theme.fgSurface
              font.pixelSize: Theme.type.label_m
              font.weight: Font.Bold
              text: tile.modelData.name
            }
          }
        }
      }
    }

    // fantasma da janela arrastada: por cima de todas as miniaturas (fora do recorte
    // delas). Copia a textura da propria miniatura: uma 2a captura da mesma janela
    // derrubava a primeira.
    ClippingRectangle {
      id: ghost
      property Item shot: null
      visible: shot !== null
      z: 100
      radius: Theme.shape.xs
      opacity: 0.85
      color: Theme.surfaceContainerHighest
      border.width: 2
      border.color: Theme.primary
      ShaderEffectSource {
        anchors.fill: parent
        sourceItem: ghost.shot
        live: true
      }
    }
  }
}
