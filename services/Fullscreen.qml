pragma Singleton

import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick

// Barra coberta (fullscreen)? Antes isso vivia dentro de cada Osd: 3 OSDs =
// 3 Connections + 3 hyprctl por evento activewindow. Agora e um so.
// toplevels.lastIpcObject e snapshot STALE no qs 0.3.1; evento raw "fullscreen"
// cobre o toggle, e troca de foco/workspace reconsulta via hyprctl (debounce).
Singleton {
  id: root

  property bool barHidden: false

  Connections {
    target: Hyprland
    function onRawEvent(event) {
      if (event.name === "fullscreen")
        root.barHidden = event.data === "1";
      else if (event.name === "activewindow" || event.name === "activewindowv2" || event.name === "workspace")
        debounce.restart();
    }
  }

  Timer {
    id: debounce
    interval: 150
    onTriggered: {
      query.running = false;
      query.running = true;
    }
  }

  Process {
    id: query
    command: ["hyprctl", "-j", "activewindow"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          const j = JSON.parse(text);
          root.barHidden = (j.fullscreen ?? 0) > 1;
        } catch (e) {}
      }
    }
  }
}
