import QtQuick
import QtQuick.Layouts

// Linha de menu: icone + rotulo + (radio | seta). Usada por Net/Power/Audio/Bt.
// popup = janela PopupBase que fecha apos o clique (a menos de keepOpen).
// Teclado: o PopupBase anda pelas linhas (navigable) e Enter chama navActivate().
Item {
  id: row

  signal fired
  property var popup: null
  property string icon: ""
  property string label: ""
  property bool checkable: false
  property bool checked: false
  property bool keepOpen: false
  property bool armed: false          // estado "confirmar?" (vermelho)
  property string arrow: ""
  property color labelColor: Theme.fgSurface
  property bool navigable: true
  property bool kbFocus: false        // posto pelo PopupBase

  function navActivate() {
    row.fired();
    if (!row.keepOpen && row.popup)
      row.popup.close();
  }

  Layout.fillWidth: true
  implicitHeight: Math.max(32, lines.implicitHeight + 14)   // rotulo com \n cresce

  Rectangle {
    anchors.fill: parent
    radius: Theme.shape.sm
    color: row.armed ? Theme.error : "transparent"
    StateLayer { hovered: area.containsMouse; pressed: area.pressed; focused: row.kbFocus; tint: row.armed ? Theme.fgError : Theme.fgSurface }
  }
  RowLayout {
    anchors.fill: parent
    anchors.leftMargin: 10
    anchors.rightMargin: 10
    spacing: 8
    Glyph {
      visible: row.icon !== ""
      color: row.armed ? Theme.fgPrimary : Theme.primary
      text: row.icon
    }
    // uma linha por \n, cada uma com o seu elide (Text com \n nao elide)
    ColumnLayout {
      id: lines
      Layout.fillWidth: true
      spacing: 0
      Repeater {
        model: row.label.split("\n")
        UiText {
          required property string modelData
          Layout.fillWidth: true
          color: row.armed ? Theme.fgPrimary : row.labelColor
          elide: Text.ElideRight
          textFormat: Text.PlainText   // nome de dispositivo/app vem de fora
          text: modelData
        }
      }
    }
    Rectangle {
      visible: row.checkable
      Layout.preferredWidth: 18
      Layout.preferredHeight: 18
      radius: height / 2
      color: row.checked ? Theme.primary : "transparent"
      border.color: Theme.primary
      border.width: 1
      Rectangle {
        anchors.centerIn: parent
        width: 8
        height: 8
        radius: height / 2
        color: Theme.fgPrimary
        visible: row.checked
      }
    }
    Glyph {
      visible: row.arrow !== ""
      text: row.arrow
    }
  }
  MouseArea {
    id: area
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: row.navActivate()
  }
}
