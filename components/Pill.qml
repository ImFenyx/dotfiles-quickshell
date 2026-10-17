import QtQuick
import QtQuick.Layouts

// Pill colorida: largura acompanha o conteudo com spring. Os filhos vao
// para um RowLayout interno (default alias). Tooltip/clique embutidos via
// tipWindow/tipText/clickable — o MouseArea fica FORA do layout (anchors
// dentro de RowLayout e comportamento indefinido).
Rectangle {
  id: root

  default property alias content: row.data
  property alias spacing: row.spacing
  property int hpad: 28

  property var tipWindow: null
  property string tipText: ""
  property bool tipMono: false
  property bool clickable: false
  signal clicked
  signal tipRequested   // hover: quem usa pode atualizar o dado antes do tooltip

  radius: 99
  implicitHeight: 28
  implicitWidth: row.implicitWidth + hpad

  Behavior on implicitWidth {
    SpringAnimation {
      spring: 9
      damping: 3.5
      epsilon: 0.5
    }
  }
  Behavior on color {
    ColorAnimation {
      duration: 150
    }
  }

  RowLayout {
    id: row
    anchors.centerIn: parent
    spacing: 5
  }

  TipArea {
    anchors.fill: parent
    // desabilitado = nao rouba clique dos filhos (ex.: workspaces)
    enabled: root.clickable || root.tipText !== ""
    cursorShape: root.clickable ? Qt.PointingHandCursor : Qt.ArrowCursor
    tipWindow: root.tipWindow
    tipText: root.tipText
    mono: root.tipMono
    onClicked: root.clicked()
    onTipRequested: root.tipRequested()
  }
}
