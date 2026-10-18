import QtQuick
import QtQuick.Layouts
import qs.components
import qs.services

// Contador + sino. Clique esquerdo abre o centro de notificacoes; clique
// direito liga/desliga o nao perturbe. O MouseArea fica fora do RowLayout.
Item {
  id: root

  signal clicked

  implicitWidth: row.implicitWidth
  implicitHeight: row.implicitHeight

  RowLayout {
    id: row
    spacing: 4
    UiText {
      color: Notifs.dnd ? Theme.overlay0 : Theme.mauve
      font.weight: Font.DemiBold
      text: Notifs.count
    }
    Glyph {
      color: Notifs.dnd ? Theme.overlay0 : Theme.mauve
      text: Notifs.dnd ? Icons.bellSlash : Icons.bell
    }
  }
  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    cursorShape: Qt.PointingHandCursor
    onClicked: mouse => {
      if (mouse.button === Qt.RightButton)
        Notifs.toggleDnd();
      else
        root.clicked();
    }
  }
}
