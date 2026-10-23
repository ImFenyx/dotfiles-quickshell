import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.components
import qs.services

// "Status bar" do centro: so atalhos. Hora, data, Wi-Fi, som e bateria ja
// estao na barra, entao aqui ficam os interruptores (e o Wi-Fi saiu do NetMenu).
// Clique liga/desliga; clique direito abre o app de configuracao quando ha um
// (Wi-Fi, Bluetooth, mixer, tlpui).
// Os que dependem de hardware/programa (Bluetooth, luz noturna, energia,
// microfone) somem quando nao existem.
GridLayout {
  id: root

  Layout.fillWidth: true
  columns: 4
  columnSpacing: 8
  rowSpacing: 8
  uniformCellWidths: true

  // clique direito em Mudo/Mic mudo/Bluetooth: abre o menu da shell (NotifCenter repassa)
  signal audioRequested
  signal bluetoothRequested

  NotifQuickTile {
    icon: Wifi.on ? Icons.netWifi : Icons.wifiOff
    label: "Wi-Fi"
    active: Wifi.on
    onClicked: Wifi.toggle()
    onSecondary: Quickshell.execDetached([Config.connectionEditor])
  }
  NotifQuickTile {
    visible: Bt.available
    icon: Icons.bluetooth
    label: "Bluetooth"
    sub: Bt.deviceName
    active: Bt.on
    onClicked: Bt.toggle()
    onSecondary: root.bluetoothRequested()
  }
  NotifQuickTile {
    icon: Notifs.dnd ? Icons.bellSlash : Icons.bell
    label: "Não perturbe"
    active: Notifs.dnd
    onClicked: Notifs.toggleDnd()
  }
  NotifQuickTile {
    icon: Audio.muted ? Icons.volumeMuted : Icons.volumeDefault
    label: "Mudo"
    active: Audio.muted
    onClicked: {
      if (Audio.sinkOk)
        Audio.sink.audio.muted = !Audio.sink.audio.muted;
    }
    onSecondary: root.audioRequested()
  }
  NotifQuickTile {
    visible: Audio.sourceOk
    icon: Icons.micOff
    label: "Mic mudo"
    active: Audio.sourceOk && Audio.source.audio.muted
    onClicked: {
      if (Audio.sourceOk)
        Audio.source.audio.muted = !Audio.source.audio.muted;
    }
    onSecondary: root.audioRequested()
  }
  NotifQuickTile {
    icon: Icons.coffee
    label: "Cafeína"
    active: Caffeine.on
    onClicked: Caffeine.toggle()
  }
  NotifQuickTile {
    visible: NightLight.available
    icon: Icons.moon
    label: "Luz noturna"
    sub: NightLight.on ? NightLight.kelvin + "K" : ""
    active: NightLight.on
    onClicked: NightLight.toggle()
  }
  NotifQuickTile {
    visible: Energy.available
    icon: Energy.icon
    label: "Energia"
    sub: Energy.label
    active: Energy.profile !== "" && !Energy.balanced
    onClicked: Energy.cycle()
    onSecondary: Quickshell.execDetached([Config.powerManager])
  }
  // so com video de wallpaper: aceso = pausa na bateria (retoma na tomada)
  NotifQuickTile {
    visible: Wallpapers.video !== ""
    icon: Icons.pause
    label: "Pausar vídeo"
    sub: !Wallpapers.pauseOnBattery ? "desligado" : (Wallpapers.paused ? "pausado agora" : "na bateria")
    active: Wallpapers.pauseOnBattery
    onClicked: Wallpapers.togglePauseOnBattery()
  }
  // so com video de wallpaper: som do video (o volume fica no mixer, como app)
  NotifQuickTile {
    visible: Wallpapers.video !== ""
    icon: Wallpapers.audio ? Icons.volumeDefault : Icons.volumeMuted
    label: "Som do vídeo"
    sub: Wallpapers.audio ? "ligado" : "mudo"
    active: Wallpapers.audio
    onClicked: Wallpapers.toggleAudio()
  }
}
