pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Estado de runtime que sobrevive a restart e reboot (modelo ii Persistent.qml):
// ~/.local/state/quickshell/state.json via FileView + JsonAdapter. Mudou aqui ->
// grava (debounce); mudou o arquivo -> relê; sem arquivo -> cria com os padroes.
// So estado que o usuario escolheu (nao cache): DND, som, tom do emoji.
Singleton {
  id: root

  property alias dnd: adapter.dnd
  property alias sound: adapter.sound
  property alias emojiTone: adapter.emojiTone

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
    }
  }

  Timer {
    id: writeLater
    interval: 200
    onTriggered: file.writeAdapter()
  }
}
