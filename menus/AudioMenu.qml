import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
import qs.components
import qs.services

// Mixer: desce da barra (clique na pill de audio ou clique direito em Mudo/Mic no
// centro). Volume e mudo de saida e entrada, escolha do dispositivo padrao e volume
// por app tocando. No rodape a protecao de volume (services/Audio) e o pavucontrol
// p/ o resto (perfis, portas...).
PopupBase {
  id: root

  panelWidth: 380
  padTop: Theme.space.lg
  padBottom: Theme.space.lg
  padX: Theme.space.lg
  spacing: 6

  function toggle() {
    open = !open;
  }

  // nos com propriedades vivas so enquanto aparece; OSD calado (o slider ja mostra)
  PwObjectTracker {
    objects: root.visible ? Audio.sinks.concat(Audio.sources, Audio.streams) : []
  }
  Binding {
    target: Audio
    property: "osdSuppressed"
    value: root.open
  }

  component Section: UiText {
    Layout.fillWidth: true
    Layout.topMargin: 6
    color: Theme.fgSurfaceVariant
    font.pixelSize: Theme.type.label_m
    font.weight: Font.Bold
  }

  // ---- saida ----
  Section {
    Layout.topMargin: 0
    text: "Saída"
  }
  VolumeRow {
    visible: Audio.sinkOk
    node: Audio.sink
  }
  // linhas {id, name} (Audio.sinkRows), nunca o PwNode no modelo; so com o menu aberto
  Repeater {
    model: root.visible && Audio.sinkRows.length > 1 ? Audio.sinkRows : []
    delegate: MenuRow {
      id: sinkRow
      required property var modelData
      readonly property var node: Audio.nodeFor(modelData)
      visible: node !== null
      popup: root
      keepOpen: true
      checkable: true
      checked: node !== null && node === Audio.sink
      label: node ? Audio.deviceName(node) : ""
      onFired: {
        if (sinkRow.node)
          Audio.setSink(sinkRow.node);
      }
    }
  }

  // ---- entrada ----
  Section {
    visible: Audio.sourceOk
    text: "Entrada"
  }
  VolumeRow {
    visible: Audio.sourceOk
    node: Audio.source
    glyph: Icons.mic
    glyphMuted: Icons.micOff
  }
  Repeater {
    model: root.visible && Audio.sourceRows.length > 1 ? Audio.sourceRows : []
    delegate: MenuRow {
      id: sourceRow
      required property var modelData
      readonly property var node: Audio.nodeFor(modelData)
      visible: node !== null
      popup: root
      keepOpen: true
      checkable: true
      checked: node !== null && node === Audio.source
      label: node ? Audio.deviceName(node) : ""
      onFired: {
        if (sourceRow.node)
          Audio.setSource(sourceRow.node);
      }
    }
  }

  // ---- apps tocando ----
  Section {
    visible: Audio.streams.length > 0
    text: "Apps"
  }
  Repeater {
    model: root.visible ? Audio.streamRows : []
    delegate: ColumnLayout {
      id: app
      required property var modelData
      readonly property var node: Audio.nodeFor(modelData)
      readonly property var props: node ? (node.properties || {}) : {}
      visible: node !== null
      Layout.fillWidth: true
      spacing: 0
      UiText {
        Layout.fillWidth: true
        Layout.leftMargin: 32
        font.pixelSize: Theme.type.body_m
        elide: Text.ElideRight
        textFormat: Text.PlainText
        // "Firefox · titulo do video"
        text: app.node ? Audio.appName(app.node) + (app.props["media.name"] ? "  ·  " + app.props["media.name"] : "") : ""
      }
      VolumeRow {
        node: app.node
        image: app.node ? Audio.appIcon(app.node) : ""
      }
    }
  }

  Rectangle {
    Layout.fillWidth: true
    Layout.topMargin: 6
    Layout.bottomMargin: 2
    height: 1
    color: Theme.surfaceContainerHighest
  }
  MenuRow {
    popup: root
    keepOpen: true
    checkable: true
    checked: Audio.guard
    icon: Icons.shield
    label: "Proteção de volume"
    onFired: Audio.toggleGuard()
  }
  MenuRow {
    popup: root
    icon: Icons.volumeDefault
    label: "Abrir mixer completo"
    onFired: Quickshell.execDetached(Config.app([Config.mixer]))
  }
}
