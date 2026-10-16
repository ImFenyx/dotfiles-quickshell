import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs.components

// Icones do tray (SNI). Repeater: os itens entram no layout do pai.
Repeater {
  id: root

  property var tip: null
  signal menuRequested(var item, var pos)

  // passivos escondidos (paridade noctalia); NeedsAttention sempre visivel
  model: ScriptModel {
    values: [...SystemTray.items.values].filter(i => i.status !== Status.Passive)
  }

  TipArea {
    id: area
    required property var modelData

    implicitWidth: 22
    implicitHeight: 22
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    tipWindow: root.tip
    tipText: modelData.tooltipTitle || modelData.title || modelData.id || ""

    onClicked: mouse => {
      if (root.tip)
        root.tip.hide();
      const pos = mapToGlobal(width / 2, height / 2);
      if (mouse.button === Qt.RightButton) {
        if (modelData.hasMenu)
          root.menuRequested(modelData, pos);
        else
          modelData.secondaryActivate();
      } else {
        if (modelData.onlyMenu && modelData.hasMenu)
          root.menuRequested(modelData, pos);
        else
          modelData.activate();
      }
    }

    IconImage {
      anchors.fill: parent
      asynchronous: true
      // SNI ja entrega image:// pronto (pixmap/tema/path); iconPath()
      // embrulha 2x e quebra. Launcher (DesktopEntries) continua com iconPath.
      source: area.modelData.icon
    }
  }
}
