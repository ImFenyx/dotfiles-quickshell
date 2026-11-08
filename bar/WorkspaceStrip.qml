import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import qs.components
import qs.services

// Workspaces DESTE monitor (ordenados em services/Workspaces) + os special, que
// abrem em qualquer um. O ativo estica com spring. Roda do mouse troca de workspace.
// Cada um mostra o numero + icones dos apps abertos (um por app, ate
// Config.wsIcons; o resto vira "+N"). A faixa nao passa de Theme.wsStripMax:
// sem espaco, os outros workspaces perdem icones antes do ativo.
Pill {
  id: root

  readonly property int dot: 26          // workspace sem icones
  readonly property int dotActive: 48    // ativo: mais largo
  readonly property int slot: Theme.wsIcon + 3   // icone (ou "+N") + espaco antes dele

  property var screen: null
  readonly property var monitor: screen ? Hyprland.monitorFor(screen) : null
  readonly property var list: Workspaces.sorted.filter(w => String(w.name).startsWith("special:") || !monitor || !w.monitor || w.monitor === monitor)

  // ativo = o workspace visivel NESTE monitor (cada barra mostra o seu). O special
  // (ex.: magic) acende junto enquanto estiver aberto aqui.
  function active(w) {
    const name = String(w.name);
    if (name.startsWith("special:"))
      return (monitor ? Workspaces.specialByMonitor[monitor.name] || "" : Workspaces.activeSpecial) === name;
    const cur = monitor ? monitor.activeWorkspace : Hyprland.focusedWorkspace;
    return cur != null && cur.name === name;
  }
  // appIds distintos das janelas, na ordem do modelo. Special fica so com o glifo.
  function apps(w) {
    if (String(w.name).startsWith("special:") || !w.toplevels)
      return [];
    const ids = [];
    for (const t of w.toplevels.values) {
      const id = t.wayland ? t.wayland.appId : "";
      if (!ids.includes(id))
        ids.push(id);
    }
    return ids;
  }
  // nivel l: ativo ate min(l, max) icones, os outros ate l - max
  function cap(isActive, l) {
    return isActive ? Math.min(l, Config.wsIcons) : Math.max(0, l - Config.wsIcons);
  }
  // icones + "+N" de um workspace com n apps e teto k
  function slots(n, k) {
    return Math.min(n, k) + (n > k && k > 0 ? 1 : 0);
  }
  // maior nivel que cabe em Theme.wsStripMax (larguras exatas: cada slot e fixo)
  readonly property int level: {
    const ws = list.map(w => [active(w), apps(w).length]);
    let base = hpad + spacing * (ws.length - 1);
    for (const [a] of ws)
      base += a ? dotActive : dot;
    for (let l = 2 * Config.wsIcons; l > 0; l--) {
      let w = base;
      for (const [a, n] of ws)
        w += slots(n, cap(a, l)) * slot;
      if (w <= Theme.wsStripMax)
        return l;
    }
    return 0;
  }

  color: Theme.surfaceContainerHighest
  implicitHeight: 30
  hpad: 12
  spacing: 4

  // roda: workspace anterior/proximo deste monitor (touchpad acumula ate um "clique")
  WheelHandler {
    property real acc: 0
    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
    onWheel: event => {
      acc += event.angleDelta.y;
      if (Math.abs(acc) < 120)
        return;
      Hyprland.dispatch("hl.dsp.focus({workspace=\"m" + (acc > 0 ? "-1" : "+1") + "\"})");
      acc = 0;
    }
  }

  Repeater {
    model: root.list

    Rectangle {
      id: ws
      required property var modelData
      readonly property string wsName: String(modelData.name)
      readonly property bool isSpecial: wsName.startsWith("special:")
      // HyprlandWorkspace nao tem "windows": conta os toplevels (fallback: ocupado)
      readonly property bool occupied: modelData.toplevels ? modelData.toplevels.values.length > 0 : true
      readonly property bool isActive: root.active(modelData)
      readonly property var apps: root.apps(modelData)
      readonly property int cap: root.cap(isActive, root.level)
      readonly property var shown: apps.slice(0, cap)

      Layout.preferredWidth: (isActive ? root.dotActive : root.dot) + root.slots(apps.length, cap) * root.slot
      Layout.preferredHeight: 26
      radius: height / 2
      color: isActive ? Theme.primary : (occupied && !isSpecial ? Theme.outline : Theme.surface)
      // icones entram antes da largura assentar
      clip: true

      Behavior on Layout.preferredWidth {
        enabled: !Theme.reduceMotion
        SpringPill {}
      }
      Behavior on color {
        ColorAnimation {
          duration: Theme.animNormal
        }
      }

      RowLayout {
        anchors.centerIn: parent
        spacing: root.slot - Theme.wsIcon

        UiText {
          // respiro antes dos icones: so encolhe as margens (a largura e fixa)
          Layout.rightMargin: ws.shown.length > 0 ? 2 : 0
          text: ws.isSpecial ? Icons.workspaceSpecial : ws.wsName
          color: ws.isActive ? Theme.fgPrimary : Theme.fgSurface
          font.family: ws.isSpecial ? Theme.iconFont : Theme.uiFont
          font.weight: ws.isActive ? Font.Bold : Font.DemiBold
        }
        Repeater {
          // ScriptModel reaproveita os icones que continuam (sem recarregar a cada janela)
          model: ScriptModel {
            values: ws.shown
          }
          Item {
            id: app
            required property string modelData
            // le applications p/ reavaliar: na partida os .desktop ainda nao
            // foram lidos (0 apps) e o lookup da null
            readonly property var entry: {
              DesktopEntries.applications.values;
              return DesktopEntries.heuristicLookup(modelData);
            }
            readonly property string icon: entry ? entry.icon : modelData

            Layout.preferredWidth: Theme.wsIcon
            Layout.preferredHeight: Theme.wsIcon

            IconImage {
              id: img
              anchors.fill: parent
              asynchronous: true
              source: app.icon.startsWith("/") ? app.icon : Quickshell.iconPath(app.icon, true)
              visible: status === Image.Ready
            }
            // sem icone no tema (ou falhou): inicial do app. Carregando = nada (sem piscar)
            UiText {
              anchors.centerIn: parent
              visible: img.status === Image.Null || img.status === Image.Error
              text: ((app.entry ? app.entry.name : app.modelData) || "?").charAt(0).toUpperCase()
              color: ws.isActive ? Theme.fgPrimary : Theme.fgSurface
              font.pixelSize: Theme.type.label_m
              font.weight: Font.Bold
            }
          }
        }
        UiText {
          visible: ws.apps.length > ws.shown.length && ws.cap > 0
          Layout.preferredWidth: Theme.wsIcon
          horizontalAlignment: Text.AlignHCenter
          text: "+" + (ws.apps.length - ws.shown.length)
          color: ws.isActive ? Theme.fgPrimary : Theme.fgSurface
          font.pixelSize: Theme.type.label_s
          font.weight: Font.Bold
        }
      }

      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
          if (ws.isSpecial)
            Hyprland.dispatch("hl.dsp.workspace.toggle_special(\"" + ws.wsName.slice(8) + "\")");
          else
            Hyprland.dispatch("hl.dsp.focus({workspace=" + (isNaN(Number(ws.wsName)) ? JSON.stringify(ws.wsName) : ws.wsName) + "})");
        }
      }
    }
  }
}
