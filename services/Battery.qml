pragma Singleton

import Quickshell
import Quickshell.Services.UPower
import QtQuick
import qs.components

// Bateria (UPower). A heuristica 0..1 vs 0..100 vivia copiada 3x.
// Aviso de bateria baixa: um por limite (Config.batteryWarn) ao descer na
// bateria, pelo proprio daemon (notify-send -> toast, som, historico). Ligar o
// carregador zera.
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

  property int warned: 101          // menor limite ja avisado nesta descarga
  onPercentChanged: checkLow()
  onOnBatteryChanged: checkLow()

  function checkLow() {
    if (!present || !onBattery) {
      warned = 101;
      return;
    }
    // so o menor limite cruzado (ex.: 25% -> 8% depois de suspender = 1 aviso)
    const hit = Config.batteryWarn.filter(t => percent <= t);
    if (hit.length === 0)
      return;
    const t = Math.min(...hit);
    if (t >= warned)
      return;
    warned = t;
    const crit = t <= 10;
    Quickshell.execDetached(["notify-send", "-a", "Bateria", "-u", crit ? "critical" : "normal", "-i", crit ? "battery-caution" : "battery-low", "Bateria baixa", percent + "% restantes: conecte o carregador"]);
  }
}
