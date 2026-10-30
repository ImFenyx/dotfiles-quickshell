pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Estado de runtime que sobrevive a restart e reboot (modelo ii Persistent.qml):
// ~/.local/state/quickshell/state.json via FileView + JsonAdapter. Mudou aqui ->
// grava (debounce); mudou o arquivo -> relê; sem arquivo -> cria com os padroes.
// So estado que o usuario escolheu (nao cache): DND, som, tom do emoji, wallpaper em video,
// protecao de volume.
Singleton {
  id: root

  property alias dnd: adapter.dnd
  property alias sound: adapter.sound
  property alias emojiTone: adapter.emojiTone
  property alias wallpaperVideo: adapter.wallpaperVideo
  property alias wallpaperPauseOnBattery: adapter.wallpaperPauseOnBattery
  property alias wallpaperVideoAudio: adapter.wallpaperVideoAudio
  property alias volumeGuard: adapter.volumeGuard
  // captura e gravacao (barra da tela de captura)
  property alias captureCopy: adapter.captureCopy
  property alias captureSave: adapter.captureSave
  property alias captureTimer: adapter.captureTimer
  property alias captureDir: adapter.captureDir
  property alias recQuality: adapter.recQuality
  property alias recFps: adapter.recFps
  property alias recCursor: adapter.recCursor
  property alias recDir: adapter.recDir
  property alias recSys: adapter.recSys
  property alias recMic: adapter.recMic
  property alias recApp: adapter.recApp
  property alias recCodec: adapter.recCodec
  property alias recFpsMode: adapter.recFpsMode
  property alias recScale: adapter.recScale
  property alias recColor: adapter.recColor
  property alias recEncoder: adapter.recEncoder
  property alias recKeyint: adapter.recKeyint
  property alias recAudioCodec: adapter.recAudioCodec
  property alias recAudioBitrate: adapter.recAudioBitrate
  property alias recFormat: adapter.recFormat
  property alias recWebcam: adapter.recWebcam
  property alias recReplay: adapter.recReplay
  property alias recReplayStorage: adapter.recReplayStorage
  // o arquivo ja foi lido: antes disso os valores sao os padroes (quem restaura algo na partida espera)
  readonly property bool ready: file.loaded

  FileView {
    id: file
    path: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/quickshell/state.json"
    watchChanges: true
    onFileChanged: reload()
    onAdapterUpdated: writeLater.restart()
    onLoadFailed: error => {
      if (error === FileViewError.FileNotFound)
        writeAdapter();
    }

    JsonAdapter {
      id: adapter
      property bool dnd: false
      property bool sound: true
      property int emojiTone: 0       // 0 = padrao, 1..5 = tons de pele
      property string wallpaperVideo: ""   // video em uso como wallpaper ("" = imagem do awww)
      property bool wallpaperPauseOnBattery: true   // atalho "Pausar video" no centro
      property bool wallpaperVideoAudio: false      // atalho "Som do video" no centro
      property bool volumeGuard: true               // "Protecao de volume" no mixer (services/Audio)
      property bool captureCopy: true               // captura vai para o clipboard
      property bool captureSave: true               // captura salva em captureDir
      property int captureTimer: 0                  // s de espera depois de escolher a area
      property string captureDir: ""                // "" = ~/Imagens/Screenshots
      property string recQuality: "very_high"       // medium | high | very_high | ultra
      property int recFps: 60
      property bool recCursor: true
      property string recDir: ""                    // "" = ~/Videos
      property string recSys: "default_output"      // som do sistema: "" = nenhum, ou dispositivo
      property string recMic: ""                    // microfone: "" = nenhum, ou dispositivo
      property string recApp: ""                    // so o audio deste app ("" = nao usa)
      property string recCodec: "auto"              // auto | h264 | hevc | hevc_10bit | vp9
      property string recFpsMode: "vfr"             // vfr | cfr
      property string recScale: "0x0"               // 0x0 = original, ou limite WxH
      property string recColor: "limited"           // limited | full
      property string recEncoder: "gpu"             // gpu | cpu (cpu so h264)
      property real recKeyint: 2
      property string recAudioCodec: "opus"         // opus | aac | flac
      property int recAudioBitrate: 128
      property string recFormat: "mp4"              // mp4 | mkv | webm | mov
      property string recWebcam: "none"             // none | br | bl | tr | tl (so tela inteira)
      property int recReplay: 0                     // s do replay instantaneo (0 = gravacao normal)
      property string recReplayStorage: "ram"       // ram | disk
    }
  }

  Timer {
    id: writeLater
    interval: 200
    onTriggered: file.writeAdapter()
  }
}
