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
  panelX: root.width - panelWidth - Theme.edge
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
  // o Repeater recebe linhas {address}, nao o BluetoothDevice (o BlueZ tira e poe
  // dispositivos durante a busca; mesmo cuidado de Audio.sinkRows). Saem no ciclo
  // seguinte do loop, depois que a remocao terminou.
  property var shownRows: []
  onShownChanged: shownLater.restart()
  Timer {
    id: shownLater
    interval: 0
    onTriggered: root.shownRows = root.shown.filter(d => d && d.address).map(d => ({
            address: d.address
          }))
  }
  Component.onCompleted: shownLater.start()

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
    // interruptor: clique ou, no teclado, e a 1a parada (Enter/Espaco alternam)
    Rectangle {
      id: btSwitch
      property bool navigable: Bt.available
      property bool kbFocus: false
      function navActivate() {
        Bt.toggle();
      }
      implicitWidth: 38
      implicitHeight: 22
      radius: height / 2
      color: Bt.on ? Theme.primary : Theme.surfaceContainerHighest
      // foco de teclado: anel do M3 (secondary), por fora do trilho
      Rectangle {
        anchors.fill: parent
        anchors.margins: -3
        radius: height / 2
        color: "transparent"
        border.width: 2
        border.color: Theme.secondary
        visible: btSwitch.kbFocus
      }
      Behavior on color {
        ColorAnimation {
          duration: Theme.animNormal
        }
      }
      Rectangle {
        width: 16
        height: 16
        radius: Theme.shape.sm
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
    navigable: false   // so informa (ligar = o interruptor)
    popup: root
    keepOpen: true
    icon: Bt.scanning ? Icons.netScan : Icons.bluetooth
    label: !Bt.on ? "Bluetooth desligado" : (Bt.scanning ? "Procurando…" : "Nenhum dispositivo")
    labelColor: Theme.outline
  }

  Repeater {
    model: Bt.on && root.visible ? root.shownRows : []
    delegate: Item {
      id: dev
      required property var modelData
      readonly property var dv: Bt.deviceFor(modelData)
      readonly property bool armed: dv !== null && root.forgetArmed === dv
      visible: dv !== null
      property bool navigable: true
      property bool kbFocus: false
      function navActivate() {
        root.forgetArmed = null;
        if (dev.dv)
          Bt.activate(dev.dv);
      }
      // esquecer (so pareados), pelo X ou Delete: 1o arma, 2o esquece
      function navForget() {
        if (!dev.dv || !dev.dv.paired)
          return;
        if (dev.armed) {
          dev.dv.forget();
          root.forgetArmed = null;
        } else {
          root.forgetArmed = dev.dv;
        }
      }
      readonly property string status: {
        const d = dv;
        if (!d)
          return "";
        if (d.pairing)
          return "Pareando…";
        if (d.state === BluetoothDeviceState.Connecting)
          return "Conectando…";
        if (d.state === BluetoothDeviceState.Disconnecting)
          return "Desconectando…";
        const hint = dev.kbFocus && d.paired ? "  ·  Del esquece" : "";
        if (d.connected)
          return "Conectado" + (d.batteryAvailable ? "  ·  " + Math.round(d.battery * 100) + "%" : "") + hint;
        return (d.paired ? "Pareado" : "Disponível") + hint;
      }

      Layout.fillWidth: true
      implicitHeight: 42

      Rectangle {
        anchors.fill: parent
        radius: Theme.shape.sm
        color: "transparent"
        StateLayer { hovered: rowArea.containsMouse || forgetArea.containsMouse; pressed: rowArea.pressed || forgetArea.pressed; focused: dev.kbFocus }
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
            source: dev.dv && dev.dv.icon !== "" ? Quickshell.iconPath(dev.dv.icon, true) : ""
            // nome existe no tema mas nao desenha (ou nao existe): cai no glifo
            visible: source !== "" && status === Image.Ready
          }
          Glyph {
            anchors.centerIn: parent
            visible: !devIcon.visible
            color: dev.dv && dev.dv.connected ? Theme.success : Theme.primary
            text: Icons.bluetooth
          }
        }
        ColumnLayout {
          Layout.fillWidth: true
          spacing: 0
          UiText {
            Layout.fillWidth: true
            color: dev.armed ? Theme.error : (dev.dv && dev.dv.connected ? Theme.success : Theme.fgSurface)
            elide: Text.ElideRight
            textFormat: Text.PlainText
            text: !dev.dv ? "" : (dev.armed ? "Esquecer " + Bt.label(dev.dv) + "?" + (dev.kbFocus ? "  Del confirma" : "") : Bt.label(dev.dv))
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
          visible: !!dev.dv && dev.dv.paired
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
              dev.navForget();
            }
          }
        }
      }
      MouseArea {
        id: rowArea
        anchors.fill: parent
        anchors.rightMargin: dev.dv && dev.dv.paired ? 32 : 0
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: dev.navActivate()
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
    onFired: Quickshell.execDetached(Config.app([Config.bluetoothManager]))
  }
}
