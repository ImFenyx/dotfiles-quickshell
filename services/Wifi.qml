pragma Singleton

import Quickshell
import Quickshell.Networking
import QtQuick
import qs.components

// Wi-Fi nativo (Quickshell.Networking = D-Bus do NetworkManager): sem nmcli e
// sem processo residente; estado e sinal ao vivo, senha direto pelo D-Bus.
// A lista de redes so enche com o scanner ligado (o NetMenu liga via `scan`
// enquanto aberto); fora disso so a conectada aparece, o que basta p/ a barra.
Singleton {
  id: root

  readonly property var dev: Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null
  readonly property bool on: Networking.wifiEnabled
  readonly property var networks: dev ? dev.networks.values : []
  readonly property var active: networks.find(n => n.connected) ?? null
  readonly property int sig: active ? Math.round(active.signalStrength * 100) : -1   // signalStrength: 0..1

  // sem dev = backend ainda carregando (partida): "--", nao "off"
  readonly property string name: !dev ? "--" : (!on ? "off" : (active ? active.name : "--"))
  readonly property string strength: sig < 0 ? "" : sig + "%"   // "72%" ou ""
  readonly property string icon: sig < 0 ? "" : Icons.level(sig, Icons.wifi)
  // menu: conectada primeiro, depois sinal (oculta = sem nome, fora)
  readonly property var top: networks.filter(n => n.name !== "").sort((a, b) => (b.connected - a.connected) || (b.signalStrength - a.signalStrength)).slice(0, 8)

  property bool scan: false     // NetMenu aberto
  property var pending: null    // rede sendo conectada: mantem o scanner e avisa se falhar

  function toggle() {
    Networking.wifiEnabled = !Networking.wifiEnabled;
  }
  // psk omitido = perfil salvo ou rede aberta
  function connect(n, psk) {
    pending = n;
    if (psk === undefined)
      n.connect();
    else
      n.connectWithPsk(psk);
  }
  function disconnect() {
    if (dev)
      dev.disconnect();
  }

  // scanner so enquanto alguem precisa da lista (desligado de novo = economia)
  Binding {
    target: root.dev
    property: "scannerEnabled"
    value: true
    when: root.dev !== null && (root.scan || root.pending !== null)
  }

  Connections {
    target: root.pending
    function onConnectionFailed(reason) {
      const why = reason === ConnectionFailReason.NoSecrets ? "senha incorreta ou ausente" : ConnectionFailReason.toString(reason);
      Quickshell.execDetached(["notify-send", "-h", "boolean:transient:true", "Wi-Fi", "Falha ao conectar a " + root.pending.name + "\n" + why]);
      root.pending = null;
    }
    function onConnectedChanged() {
      if (root.pending && root.pending.connected)
        root.pending = null;
    }
  }
}
