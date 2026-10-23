import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import qs.components
import qs.services

// Workspaces (ordenados em services/Workspaces). O ativo estica com spring.
// Cada um mostra o numero + icones dos apps abertos (um por app, ate
// Config.wsIcons; o resto vira "+N"). A faixa nao passa de Theme.wsStripMax:
// sem espaco, os outros workspaces perdem icones antes do ativo.
Pill {
  id: root

  readonly property int dot: 26          // workspace sem icones
  readonly property int dotActive: 48    // ativo: mais largo
  readonly property int slot: Theme.wsIcon + 3   // icone (ou "+N") + espaco antes dele

  // sincronizado entre monitores: destaca o focado global. O special (ex.:
  // magic) acende junto com o workspace normal enquanto estiver aberto.
  function active(w) {
    const name = String(w.name);
    return name.startsWith("special:") ? Workspaces.activeSpecial === name : (Hyprland.focusedWorkspace != null && Hyprland.focusedWorkspace.name === name);
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
    const ws = Workspaces.sorted.map(w => [active(w), apps(w).length]);
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

  color: Theme.surface1
  implicitHeight: 30
  hpad: 12
  spacing: 4

  Repeater {
    model: Workspaces.sorted

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
      radius: 99
      color: isActive ? Theme.mauve : (occupied && !isSpecial ? Theme.overlay0 : Theme.base)
      // icones entram antes da largura assentar
      clip: true

      Behavior on Layout.preferredWidth {
        SpringAnimation {
          spring: 6
          damping: 2.2
          epsilon: 0.5
        }
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
          color: ws.isActive ? Theme.base : Theme.text
          font.family: ws.isSpecial ? Theme.iconFont : Theme.uiFont
          font.weight: ws.isActive ? Font.DemiBold : Font.Medium
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
              color: ws.isActive ? Theme.base : Theme.text
              font.pointSize: 9
              font.weight: Font.DemiBold
            }
          }
        }
        UiText {
          visible: ws.apps.length > ws.shown.length && ws.cap > 0
          Layout.preferredWidth: Theme.wsIcon
          horizontalAlignment: Text.AlignHCenter
          text: "+" + (ws.apps.length - ws.shown.length)
          color: ws.isActive ? Theme.base : Theme.text
          font.pointSize: 8
          font.weight: Font.DemiBold
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
