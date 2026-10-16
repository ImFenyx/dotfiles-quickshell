import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.components

// Menu nativo do tray (StatusNotifierItem / DBusMenu): botao direito abre
// as opcoes que o app expoe. Submenus inline, ate 3 niveis (cobre menus
// reais de tray).
//
// Cada nivel e um ColumnLayout DENTRO do fluxo do layout: quando um submenu
// expande, a altura do painel cresce junto. Antes o submenu usava
// anchors.top: row.bottom, que nao ocupa espaco no layout (sobrepunha as
// linhas seguintes e era cortado pelo clip).
PopupBase {
  id: root

  panelWidth: 280
  panelX: Math.max(8, Math.min(root.width - panelWidth - 8, anchorX - panelWidth / 2))

  property var trayItem: null
  property real anchorX: 0

  function show(item, p) {
    trayItem = item;
    // multi-monitor: p vem de mapToGlobal (desktop). Converte p/ local da tela
    // (ShellScreen.x = origem do monitor, ex. HDMI em -1920).
    const sx = (root.screen && root.screen.x !== undefined) ? root.screen.x : 0;
    anchorX = p ? p.x - sx : root.width / 2;
    open = true;
  }
  onOpenChanged: {
    if (!open)
      trayItem = null;   // destroi os delegates: expansoes voltam fechadas
  }

  QsMenuOpener {
    id: mainOpener
    menu: root.trayItem ? root.trayItem.menu : null
  }

  Repeater {
    model: mainOpener.children
    delegate: ColumnLayout {
      id: l0
      required property var modelData
      property bool expanded: false
      Layout.fillWidth: true
      spacing: 2

      QsMenuOpener {
        id: op1
        menu: l0.expanded ? l0.modelData : null
      }
      TrayEntryRow {
        entry: l0.modelData
        indent: 0
        expanded: l0.expanded
        popup: root
        onExpandToggled: l0.expanded = !l0.expanded
      }

      // nivel 1
      ColumnLayout {
        visible: l0.expanded
        Layout.fillWidth: true
        spacing: 2
        Repeater {
          model: op1.children
          delegate: ColumnLayout {
            id: l1
            required property var modelData
            property bool expanded: false
            Layout.fillWidth: true
            spacing: 2

            QsMenuOpener {
              id: op2
              menu: l1.expanded ? l1.modelData : null
            }
            TrayEntryRow {
              entry: l1.modelData
              indent: 1
              expanded: l1.expanded
              popup: root
              onExpandToggled: l1.expanded = !l1.expanded
            }

            // nivel 2 (folhas)
            ColumnLayout {
              visible: l1.expanded
              Layout.fillWidth: true
              spacing: 2
              Repeater {
                model: op2.children
                delegate: TrayEntryRow {
                  required property var modelData
                  entry: modelData
                  indent: 2
                  popup: root
                }
              }
            }
          }
        }
      }
    }
  }
}
