pragma Singleton

import Quickshell
import Quickshell.Bluetooth
import QtQuick

// Bluetooth (BlueZ via Quickshell.Bluetooth) p/ o atalho do centro. Sem
// adaptador (desktop sem dongle) `available` e false e o atalho some.
Singleton {
  id: root

  readonly property var adapter: Bluetooth.defaultAdapter
  readonly property bool available: adapter !== null
  readonly property bool on: available && adapter.enabled
  // dispositivos conectados, de todos os adaptadores
  readonly property var connected: Bluetooth.devices.values.filter(d => d.connected)
  readonly property string deviceName: {
    if (!on || connected.length === 0)
      return "";
    const d = connected[0];
    const name = d.name || d.deviceName || "";
    return connected.length > 1 ? name + " +" + (connected.length - 1) : name;
  }

  function toggle() {
    if (available)
      adapter.enabled = !adapter.enabled;
  }
}
