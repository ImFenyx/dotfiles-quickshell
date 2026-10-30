import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Widgets
import qs.components
import qs.services

// Bluetooth: desce da barra (clique direito no atalho Bluetooth do centro).
// Liga/desliga, lista (conectados > pareados > novos), clique conecta/desconecta
// ou pareia; X esquece (1o clique arma, 2o confirma, como no Wi-Fi). Procura
// dispositivos so com o menu aberto. Os que so anunciam o endereco ficam de fora.
PopupBase {
  id: root

  panelWidth: 320
  panelX: root.width - panelWidth - 8
  spacing: 2

  property var forgetArmed: null

  function toggle() {
    open = !open;
  }
  onOpenChanged: {
    if (!open)
      forgetArmed = null;
  }

  readonly property var shown: Bt.devices.filter(d => Bt.rank(d) > 0).slice(0, 12)

  // scan so enquanto o menu aparece (o Binding devolve o valor anterior ao fechar)
  Binding {
    target: Bt.adapter
    property: "discovering"
    value: true
    when: root.visible && Bt.on
  }

  // cabecalho: titulo + interruptor
  RowLayout {
    Layout.fillWidth: true
    Layout.bottomMargin: 6
    UiText {
      Layout.fillWidth: true
      font.weight: Font.Bold
      text: "Bluetooth"
    }
    Rectangle {
      implicitWidth: 38
      implicitHeight: 22
      radius: height / 2
      color: Bt.on ? Theme.primary : Theme.surfaceContainerHighest
      Behavior on color {
        ColorAnimation {
          duration: Theme.animNormal
        }
      }
      Rectangle {
        width: 16
        height: 16
        radius: 8
        anchors.verticalCenter: parent.verticalCenter
        x: Bt.on ? parent.width - width - 3 : 3
        color: Bt.on ? Theme.fgPrimary : Theme.fgSurfaceVariant
        Behavior on x {
          NumberAnimation {
            duration: Theme.animNormal
            easing.type: Easing.OutCubic
          }
        }
      }
      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: Bt.toggle()
      }
    }
  }

  MenuRow {
    visible: !Bt.on || root.shown.length === 0
    popup: root
    keepOpen: true
    icon: Bt.scanning ? Icons.netScan : Icons.bluetooth
    label: !Bt.on ? "Bluetooth desligado" : (Bt.scanning ? "Procurando…" : "Nenhum dispositivo")
    labelColor: Theme.outline
  }

  Repeater {
    model: Bt.on && root.visible ? root.shown : []
    delegate: Item {
      id: dev
      required property var modelData
      readonly property bool armed: root.forgetArmed === modelData
      readonly property string status: {
        const d = modelData;
        if (d.pairing)
          return "Pareando…";
        if (d.state === BluetoothDeviceState.Connecting)
          return "Conectando…";
        if (d.state === BluetoothDeviceState.Disconnecting)
          return "Desconectando…";
        if (d.connected)
          return "Conectado" + (d.batteryAvailable ? "  ·  " + Math.round(d.battery * 100) + "%" : "");
        return d.paired ? "Pareado" : "Disponível";
      }

      Layout.fillWidth: true
      implicitHeight: 42

      Rectangle {
        anchors.fill: parent
        radius: 8
        color: (rowArea.containsMouse || forgetArea.containsMouse) ? Theme.surfaceContainerHighest : "transparent"
      }
      RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 10
        anchors.rightMargin: 6
        spacing: 10
        Item {
          Layout.preferredWidth: 22
          Layout.preferredHeight: 22
          IconImage {
            id: devIcon
            anchors.fill: parent
            source: dev.modelData.icon !== "" ? Quickshell.iconPath(dev.modelData.icon, true) : ""
            // nome existe no tema mas nao desenha (ou nao existe): cai no glifo
            visible: source !== "" && status === Image.Ready
          }
          Glyph {
            anchors.centerIn: parent
            visible: !devIcon.visible
            color: dev.modelData.connected ? Theme.success : Theme.primary
            text: Icons.bluetooth
          }
        }
        ColumnLayout {
          Layout.fillWidth: true
          spacing: 0
          UiText {
            Layout.fillWidth: true
            color: dev.armed ? Theme.error : (dev.modelData.connected ? Theme.success : Theme.fgSurface)
            elide: Text.ElideRight
            textFormat: Text.PlainText
            text: dev.armed ? "Esquecer " + Bt.label(dev.modelData) + "?" : Bt.label(dev.modelData)
          }
          UiText {
            Layout.fillWidth: true
            color: Theme.outline
            font.pixelSize: Theme.type.label_m
            elide: Text.ElideRight
            text: dev.status
          }
        }
        // esquecer (so pareados): 1o clique arma, 2o confirma
        Item {
          Layout.preferredWidth: 26
          Layout.fillHeight: true
          visible: dev.modelData.paired
          Glyph {
            anchors.centerIn: parent
            color: dev.armed ? Theme.error : Theme.outline
            font.pixelSize: Theme.icon.s
            text: Icons.close
          }
          MouseArea {
            id: forgetArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              if (dev.armed) {
                dev.modelData.forget();
                root.forgetArmed = null;
              } else {
                root.forgetArmed = dev.modelData;
              }
            }
          }
        }
      }
      MouseArea {
        id: rowArea
        anchors.fill: parent
        anchors.rightMargin: dev.modelData.paired ? 32 : 0
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
          root.forgetArmed = null;
          Bt.activate(dev.modelData);
        }
      }
    }
  }

  Rectangle {
    Layout.fillWidth: true
    Layout.topMargin: 4
    Layout.bottomMargin: 4
    height: 1
    color: Theme.surfaceContainerHighest
  }
  MenuRow {
    popup: root
    icon: Icons.bluetooth
    label: "Abrir blueman"
    onFired: Quickshell.execDetached([Config.bluetoothManager])
  }
}
