import QtQuick
import QtQuick.Layouts
import Quickshell

// Um nivel do menu do tray (DBusMenu). Recursivo: cada entrada com filhos
// instancia outro TrayMenuLevel para o submenu (profundidade arbitraria).
//
// Cada submenu fica num "reveal" (Item com clip) cuja altura anima entre 0 e
// a altura natural do conteudo. Como a altura do popup e a soma dos filhos do
// layout, o painel inteiro cresce/encolhe junto, quadro a quadro.
// O conteudo fica num Item (nao num layout) para nao ser espremido enquanto
// a altura do reveal ainda e menor que a natural.
ColumnLayout {
  id: level

  property var menu: null     // QsMenuHandle (trayItem.menu) ou QsMenuEntry (submenu)
  property var popup: null    // PopupBase que fecha ao acionar uma folha
  property int depth: 0

  Layout.fillWidth: true
  spacing: 2

  QsMenuOpener {
    id: opener
    menu: level.menu
  }

  Repeater {
    model: opener.children
    delegate: ColumnLayout {
      id: ent
      required property var modelData
      property bool expanded: false
      // ja expandiu alguma vez: mantem os filhos carregados p/ animar o fechamento
      property bool opened: false
      onExpandedChanged: {
        if (expanded)
          opened = true;
      }

      Layout.fillWidth: true
      spacing: 0

      TrayEntryRow {
        entry: ent.modelData
        indent: Math.min(level.depth, 5)
        expanded: ent.expanded
        popup: level.popup
        onExpandToggled: ent.expanded = !ent.expanded
      }

      Item {
        id: reveal
        // "expanded ||": o layout escondido nao calcula implicitHeight, entao
        // ficar visivel so quando a altura > 0 travaria a 1a expansao
        visible: ent.expanded || Layout.preferredHeight > 0.5
        Layout.fillWidth: true
        Layout.preferredHeight: ent.expanded && sub.item ? sub.item.implicitHeight + 2 : 0   // +2 = respiro sob a linha
        clip: true

        Behavior on Layout.preferredHeight {
          NumberAnimation {
            duration: 180
            easing.type: Easing.OutCubic
          }
        }

        // O QML nao deixa um tipo se instanciar direto ("instantiated
        // recursively"); o Loader adia a compilacao e permite a recursao.
        Loader {
          id: sub
          y: 2
          width: reveal.width
          active: ent.opened
          source: "TrayMenuLevel.qml"
          onLoaded: {
            sub.item.menu = Qt.binding(() => ent.modelData);
            sub.item.popup = Qt.binding(() => level.popup);
            sub.item.depth = level.depth + 1;
          }
        }
      }
    }
  }
}
