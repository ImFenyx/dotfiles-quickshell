import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import qs.components
import qs.services

// Workspaces (ordenados em services/Workspaces). O ativo estica com spring.
Pill {
  id: root

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
      // sincronizado entre monitores: destaca o focado global. O special (ex.:
      // magic) acende junto com o workspace normal enquanto estiver aberto.
      readonly property bool isActive: isSpecial ? Workspaces.activeSpecial === wsName : (Hyprland.focusedWorkspace != null && Hyprland.focusedWorkspace.name === wsName)

      Layout.preferredWidth: isActive ? 48 : 26
      Layout.preferredHeight: 26
      radius: 99
      color: isActive ? Theme.mauve : (occupied && !isSpecial ? Theme.overlay0 : Theme.base)

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

      UiText {
        anchors.centerIn: parent
        text: ws.isSpecial ? Icons.workspaceSpecial : ws.wsName
        color: ws.isActive ? Theme.base : Theme.text
        font.family: ws.isSpecial ? Theme.iconFont : Theme.uiFont
        font.weight: ws.isActive ? Font.DemiBold : Font.Medium
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
