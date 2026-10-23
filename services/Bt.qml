pragma Singleton

import Quickshell
import Quickshell.Bluetooth
import QtQuick

// Bluetooth (BlueZ via Quickshell.Bluetooth) p/ o atalho do centro e o BtMenu.
// Sem adaptador (desktop sem dongle) `available` e false e o atalho some.
// Parear: a 0.3.2 nao registra agente BlueZ, entao dispositivo que pede PIN ou
// confirmacao precisa de um agente externo (blueman-applet, bluetoothctl).
Singleton {
  id: root

  readonly property var adapter: Bluetooth.defaultAdapter
  readonly property bool available: adapter !== null
  readonly property bool on: available && adapter.enabled
  readonly property bool scanning: on && adapter.discovering
  // dispositivos conectados, de todos os adaptadores
  readonly property var connected: Bluetooth.devices.values.filter(d => d.connected)
  readonly property string deviceName: {
    if (!on || connected.length === 0)
      return "";
    const d = connected[0];
    const name = d.name || d.deviceName || "";
    return connected.length > 1 ? name + " +" + (connected.length - 1) : name;
  }
  // menu: conectados, pareados, novos com nome, e por ultimo os que so tem endereco
  readonly property var devices: [...Bluetooth.devices.values].sort((a, b) => (rank(b) - rank(a)) || label(a).localeCompare(label(b)))

  property var pending: null        // pareando: conecta assim que parear

  function rank(d) {
    return d.connected ? 3 : d.paired ? 2 : named(d) ? 1 : 0;
  }
  // BlueZ poe o endereco no nome quando o dispositivo nao anuncia um ("AA-BB-...")
  function named(d) {
    const n = d.name || d.deviceName || "";
    return n !== "" && n.replace(/-/g, ":") !== d.address;
  }
  function label(d) {
    return named(d) ? (d.name || d.deviceName) : d.address;
  }

  function toggle() {
    if (available)
      adapter.enabled = !adapter.enabled;
  }
  // clique na linha: conectado -> desconecta; pareado -> conecta; novo -> pareia e conecta
  function activate(d) {
    if (d.connected)
      d.disconnect();
    else if (d.paired)
      d.connect();
    else {
      pending = d;
      d.trusted = true;   // reconecta sozinho depois, sem pedir de novo
      d.pair();
    }
  }

  Connections {
    target: root.pending
    // falhou ou foi cancelado: `pending` fica ate o proximo clique (inofensivo)
    function onPairedChanged() {
      if (root.pending.paired) {
        root.pending.connect();
        root.pending = null;
      }
    }
  }
}
