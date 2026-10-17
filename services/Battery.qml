pragma Singleton

import Quickshell
import Quickshell.Services.UPower
import QtQuick

// Bateria (UPower). A heuristica 0..1 vs 0..100 vivia copiada 3x.
Singleton {
  id: root

  readonly property var dev: UPower.displayDevice
  // true = na bateria (usado p/ espacar tarefas periodicas)
  readonly property bool onBattery: UPower.onBattery === true
  readonly property bool present: dev !== null && dev.isPresent !== false
  readonly property int percent: {
    const p = dev ? dev.percentage : 0;
    return Math.round(p > 1 ? p : p * 100);
  }
  readonly property int chargeState: dev ? dev.state : 0
  readonly property bool charging: chargeState === 1 || chargeState === 4
  readonly property string tooltip: {
    const s = chargeState === 1 ? "carregando" : chargeState === 2 ? "descarregando" : chargeState === 4 ? "cheia" : "";
    return s === "" ? percent + "%" : percent + "% \u00b7 " + s;
  }
}
