pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import qs.components

// Luz noturna via hyprsunset, falando com o daemon pelo IPC do hyprctl: serve o
// servico do systemd/exec-once que voce ja roda, e o estado e SEMPRE o do
// daemon (nada guardado aqui), entao sobrevive a reload/reinicio da shell.
//   ligar    = hyprctl hyprsunset temperature <Config.nightTemp>
//   desligar = hyprctl hyprsunset identity            (sem filtro de cor)
//   estado   = hyprctl hyprsunset identity get + temperature (leitura ao vivo)
// "Ligada" = filtro ativo e mais quente que os 6000 K que o hyprsunset aplica
// por padrao (o daemon puro ja sobe em 6000 K). Se nao houver daemon nenhum,
// ao ligar a shell sobe um desacoplado (`hyprsunset -t`). Precisa de um
// hyprsunset com leitura por IPC (a 0.4.0 tem). So aparece se estiver instalado.
Singleton {
  id: root

  property bool available: false     // hyprsunset instalado
  property bool daemon: false        // daemon respondendo no IPC
  property bool on: false
  property int kelvin: 0             // temperatura atual (0 = sem daemon)

  function refresh() {
    if (available && !query.running)
      query.running = true;
  }

  function toggle() {
    if (!available)
      return;
    if (on)
      ctl(["identity"]);
    else if (daemon)
      ctl(["temperature", String(Config.nightTemp)]);
    else
      Quickshell.execDetached(["hyprsunset", "-t", String(Config.nightTemp)]);
    on = !on;       // otimista; a releitura confirma ou corrige
    settle.restart();
  }

  function ctl(args) {
    Quickshell.execDetached(["hyprctl", "hyprsunset"].concat(args));
  }

  Process {
    command: ["sh", "-c", "command -v hyprsunset >/dev/null 2>&1 && command -v hyprctl >/dev/null 2>&1"]
    running: true
    onExited: code => {
      root.available = code === 0;
      root.refresh();
    }
  }

  // "false 4000" / "true 6000"; qualquer outra coisa = daemon fora do ar
  Process {
    id: query
    command: ["sh", "-c", "i=$(hyprctl hyprsunset identity get 2>/dev/null); t=$(hyprctl hyprsunset temperature 2>/dev/null); printf '%s %s' \"$i\" \"$t\""]
    stdout: StdioCollector {
      onStreamFinished: {
        const m = text.trim().match(/^(true|false)\s+(\d+)$/);
        root.daemon = m !== null;
        root.kelvin = m ? Number(m[2]) : 0;
        root.on = m !== null && m[1] === "false" && root.kelvin < 6000;
      }
    }
  }

  // da tempo do daemon aplicar (ou do hyprsunset novo subir) antes de reler
  Timer {
    id: settle
    interval: 700
    onTriggered: root.refresh()
  }
}
