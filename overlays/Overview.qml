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
// para o workspace. Setas escolhem o workspace, Enter vai, Esc fecha. As capturas so
// existem com o painel visivel.
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

  GridLayout {
    Layout.alignment: Qt.AlignHCenter
    columns: root.cols
    columnSpacing: root.gap
    rowSpacing: root.gap

    Repeater {
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
              anchors.fill: parent
              captureSource: win.modelData.wayland
              live: root.open
            }
            MouseArea {
              id: winArea
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onEntered: root.sel = tile.index
              onClicked: root.focusWindow(win.modelData)
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
}
