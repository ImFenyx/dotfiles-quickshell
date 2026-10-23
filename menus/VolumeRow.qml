import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import qs.components

// Volume de um no do PipeWire (dispositivo ou app): icone (clique = mudo) +
// slider + %. Quem usa mantem o no rastreado (PwObjectTracker).
RowLayout {
  id: root

  required property var node
  property string glyph: Icons.volumeDefault   // dispositivos
  property string glyphMuted: Icons.volumeMuted
  property string image: ""                    // icone do app (streams)

  readonly property bool ok: !!node && node.ready && !!node.audio
  readonly property bool muted: ok && node.audio.muted
  readonly property real vol: ok ? node.audio.volume : 0

  Layout.fillWidth: true
  spacing: 10

  Item {
    Layout.preferredWidth: 22
    Layout.preferredHeight: 22
    IconImage {
      id: appImage
      anchors.fill: parent
      visible: root.image !== "" && status === Image.Ready
      source: root.image
      opacity: root.muted ? 0.4 : 1
    }
    // dispositivo, ou app cujo icone nao carregou
    Glyph {
      anchors.centerIn: parent
      visible: !appImage.visible
      color: root.muted ? Theme.overlay0 : Theme.mauve
      text: root.muted ? root.glyphMuted : root.glyph
    }
    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      onClicked: {
        if (root.ok)
          root.node.audio.muted = !root.node.audio.muted;
      }
    }
  }
  Slider {
    Layout.fillWidth: true
    value: root.vol
    muted: root.muted
    onMoved: v => {
      if (root.ok)
        root.node.audio.volume = v;
    }
  }
  UiText {
    id: pct
    Layout.minimumWidth: pctMetrics.advanceWidth
    horizontalAlignment: Text.AlignRight
    color: root.muted ? Theme.overlay0 : Theme.subtext0
    font.pointSize: 9
    text: root.muted ? "mudo" : Math.round(root.vol * 100) + "%"
    TextMetrics {
      id: pctMetrics
      font: pct.font
      text: "100%"
    }
  }
}
