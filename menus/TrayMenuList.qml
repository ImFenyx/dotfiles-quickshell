import QtQuick
import QtQuick.Layouts
import Quickshell

// Lista de entradas de UM nivel de menu do tray (usada pelo painel principal
// e por cada submenu flutuante). Nao abre painel nenhum: so avisa quem usa.
//
// Comportamento de menu de contexto:
//  - hover numa entrada COM submenu, parado por 140ms -> pede para abrir
//  - hover numa entrada SEM submenu, parado por 140ms -> pede para fechar o
//    submenu aberto (o atraso evita fechar ao cruzar linhas na diagonal)
//  - clique numa entrada com submenu abre na hora
ColumnLayout {
  id: list

  property var menu: null          // QsMenuHandle (trayItem.menu) ou QsMenuEntry (submenu)
  property var popup: null         // PopupBase que fecha ao acionar uma folha
  property var activeEntry: null   // entrada deste nivel cujo submenu esta aberto

  signal submenuRequested(var entry, Item row)
  signal submenuDismissed

  Layout.fillWidth: true
  spacing: 2

  QsMenuOpener {
    id: opener
    menu: list.menu
  }

  Timer {
    id: hoverTimer
    interval: 140
    property var entry: null
    property Item row: null
    onTriggered: {
      if (entry && entry.hasChildren && entry.enabled) {
        if (entry !== list.activeEntry)
          list.submenuRequested(entry, row);
      } else if (list.activeEntry !== null) {
        list.submenuDismissed();
      }
    }
  }

  Repeater {
    model: opener.children
    delegate: TrayEntryRow {
      id: row
      required property var modelData
      entry: modelData
      popup: list.popup
      active: list.activeEntry === modelData
      onHovered: {
        hoverTimer.entry = row.modelData;
        hoverTimer.row = row;
        hoverTimer.restart();
      }
      onUnhovered: hoverTimer.stop()
      onSubmenuClicked: {
        hoverTimer.stop();
        if (row.modelData !== list.activeEntry)
          list.submenuRequested(row.modelData, row);
      }
    }
  }
}
