import QtQuick
import QtQuick.Layouts
import qs.components
import qs.services

// "Status bar" do centro (vocabulario do Android/iOS/macOS): hora grande e data
// a esquerda; indicadores de rede, som, bateria e nao perturbar a direita.
RowLayout {
  id: root

  Layout.fillWidth: true
  spacing: 12

  ColumnLayout {
    spacing: 0
    Text {
      color: Theme.text
      font.family: Theme.uiFont
      font.pixelSize: 36
      font.weight: Font.DemiBold
      text: Time.clockText
    }
    UiText {
      color: Theme.subtext0
      font.pointSize: 10
      text: Time.longDate
    }
  }

  Item {
    Layout.fillWidth: true
  }

  Rectangle {
    Layout.alignment: Qt.AlignTop
    implicitWidth: icons.implicitWidth + 24
    implicitHeight: 30
    radius: 15
    color: Theme.surface0

    RowLayout {
      id: icons
      anchors.centerIn: parent
      spacing: 12

      Glyph {
        visible: Notifs.dnd
        color: Theme.peach
        text: Icons.bellSlash
      }
      Glyph {
        color: Wifi.on ? Theme.text : Theme.overlay0
        text: Wifi.on ? (Wifi.icon || Icons.netWifi) : Icons.wifiOff
      }
      Glyph {
        color: Audio.muted ? Theme.overlay0 : Theme.text
        text: Audio.muted ? Icons.volumeMuted : (Audio.sinkIcon || Icons.volumeDefault)
      }
      RowLayout {
        visible: Battery.present
        spacing: 5
        Glyph {
          color: Battery.percent <= 20 ? Theme.red : (Battery.charging ? Theme.green : Theme.text)
          text: Battery.charging ? Icons.plug : Icons.level(Battery.percent, Icons.battery)
        }
        UiText {
          color: Battery.percent <= 20 ? Theme.red : Theme.text
          font.pointSize: 10
          font.weight: Font.DemiBold
          text: Battery.percent + "%"
        }
      }
    }
  }
}
