pragma Singleton

import Quickshell
import QtQuick

// Relogio unico da shell (antes: um SystemClock por barra).
Singleton {
  id: root

  readonly property var date: clock.date
  readonly property var weekdaysShort: ["dom", "seg", "ter", "qua", "qui", "sex", "sáb"]
  readonly property var weekdaysLong: ["domingo", "segunda-feira", "terça-feira", "quarta-feira", "quinta-feira", "sexta-feira", "sábado"]

  readonly property string clockText: Qt.formatDateTime(date, "hh:mm")
  readonly property string barText: weekdaysShort[date.getDay()] + Qt.formatDateTime(date, " dd/MM hh:mm")
  readonly property string longDate: weekdaysLong[date.getDay()] + Qt.formatDateTime(date, " dd/MM/yyyy")

  // Volta do suspend (IPC time.sync, chamado pelo after_sleep_cmd do hypridle): o
  // timer do SystemClock conta tempo monotonico, que para no suspend, entao ele
  // seguia mostrando a hora de antes de dormir. Desligar/religar faz reler a hora real.
  function sync() {
    clock.enabled = false;
    clock.enabled = true;
  }

  SystemClock {
    id: clock
    precision: SystemClock.Minutes
  }
}
