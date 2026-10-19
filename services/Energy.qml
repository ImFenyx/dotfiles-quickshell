pragma Singleton

import Quickshell
import Quickshell.Services.UPower
import QtQuick
import qs.components

// Perfil de energia (power-profiles-daemon, via UPower). So em maquina com
// bateria; sem o daemon o clique simplesmente nao muda nada.
Singleton {
  id: root

  readonly property bool available: Battery.present
  readonly property int profile: PowerProfiles.profile
  readonly property bool balanced: profile === PowerProfile.Balanced
  readonly property string label: profile === PowerProfile.PowerSaver ? "Economia" : (profile === PowerProfile.Performance ? "Desempenho" : "Equilibrado")
  readonly property string icon: profile === PowerProfile.PowerSaver ? Icons.leaf : (profile === PowerProfile.Performance ? Icons.bolt : Icons.balance)

  // economia -> equilibrado -> desempenho (se existir) -> economia
  function cycle() {
    const p = PowerProfiles.profile;
    if (p === PowerProfile.PowerSaver)
      PowerProfiles.profile = PowerProfile.Balanced;
    else if (p === PowerProfile.Balanced)
      PowerProfiles.profile = PowerProfiles.hasPerformanceProfile ? PowerProfile.Performance : PowerProfile.PowerSaver;
    else
      PowerProfiles.profile = PowerProfile.PowerSaver;
  }
}
