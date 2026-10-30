import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import qs.components
import qs.services

// Midia tocando (MPRIS, services/Media): capa + titulo + play/pause. Clique toca/pausa,
// roda troca de faixa, clique direito abre o centro (player completo). Some sem player.
// `room` = largura livre na barra: o titulo encolhe para nao invadir o bloco do centro e
// some abaixo de 60 px (fica capa + play); sem espaco nem para isso, a pill some.
Pill {
  id: root

  property var tip: null
  property real room: 9999
  signal centerRequested

  readonly property real titleMax: room - hpad - 18 - 16 - 2 * spacing

  visible: Media.has && room >= 70
  color: Theme.secondary
  spacing: 6
  hpad: 20
  clickable: true
  tipWindow: root.tip
  tipText: Media.artist !== "" ? Media.title + " — " + Media.artist : Media.title
  onClicked: Media.togglePlaying()

  ClippingRectangle {
    visible: Media.art !== ""
    Layout.preferredWidth: 18
    Layout.preferredHeight: 18
    radius: 9
    color: Theme.fgPrimary
    Image {
      anchors.fill: parent
      source: Media.art
      fillMode: Image.PreserveAspectCrop
      sourceSize: Qt.size(36, 36)
      asynchronous: true
    }
  }
  PillGlyph {
    visible: Media.art === ""
    text: Media.kindIcon
  }
  PillText {
    visible: root.titleMax >= 60
    Layout.maximumWidth: root.titleMax
    elide: Text.ElideRight
    text: Media.title || Media.player
  }
  PillGlyph {
    text: Media.playing ? Icons.pause : Icons.play
  }

  WheelHandler {
    property real acc: 0
    onWheel: event => {
      acc += event.angleDelta.y;
      if (Math.abs(acc) < 120)
        return;
      if (acc > 0)
        Media.previous();
      else
        Media.next();
      acc = 0;
    }
  }
  TapHandler {
    acceptedButtons: Qt.RightButton
    onTapped: root.centerRequested()
  }
}
