import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire
import qs.components
import qs.services

// Mixer: desce da barra (clique na pill de audio ou clique direito em Mudo/Mic no
// centro). Volume e mudo de saida e entrada, escolha do dispositivo padrao e volume
// por app tocando. O pavucontrol fica no rodape p/ o resto (perfis, portas...).
PopupBase {
  id: root

  panelWidth: 380
  padTop: 16
  padBottom: 12
  padX: 20
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
    color: Theme.subtext0
    font.pointSize: 9
    font.weight: Font.DemiBold
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
  Repeater {
    model: Audio.sinks.length > 1 ? Audio.sinks : []
    delegate: MenuRow {
      required property var modelData
      popup: root
      keepOpen: true
      checkable: true
      checked: modelData === Audio.sink
      label: Audio.deviceName(modelData)
      onFired: Audio.setSink(modelData)
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
    model: Audio.sources.length > 1 ? Audio.sources : []
    delegate: MenuRow {
      required property var modelData
      popup: root
      keepOpen: true
      checkable: true
      checked: modelData === Audio.source
      label: Audio.deviceName(modelData)
      onFired: Audio.setSource(modelData)
    }
  }

  // ---- apps tocando ----
  Section {
    visible: Audio.streams.length > 0
    text: "Apps"
  }
  Repeater {
    model: root.visible ? Audio.streams : []
    delegate: ColumnLayout {
      id: app
      required property var modelData
      readonly property var props: modelData.properties || {}
      Layout.fillWidth: true
      spacing: 0
      UiText {
        Layout.fillWidth: true
        Layout.leftMargin: 32
        font.pointSize: 10
        elide: Text.ElideRight
        textFormat: Text.PlainText
        // "Firefox · titulo do video"
        text: Audio.appName(app.modelData) + (app.props["media.name"] ? "  ·  " + app.props["media.name"] : "")
      }
      VolumeRow {
        node: app.modelData
        image: Audio.appIcon(app.modelData)
      }
    }
  }

  Rectangle {
    Layout.fillWidth: true
    Layout.topMargin: 6
    Layout.bottomMargin: 2
    height: 1
    color: Theme.surface1
  }
  MenuRow {
    popup: root
    icon: Icons.volumeDefault
    label: "Abrir mixer completo"
    onFired: Quickshell.execDetached([Config.mixer])
  }
}
