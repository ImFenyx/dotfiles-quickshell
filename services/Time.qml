pragma Singleton

import Quickshell
import QtQuick

// Relogio unico da shell (antes: um SystemClock por barra).
Singleton {
  id: root

  readonly property var date: clock.date
  readonly property var weekdaysShort: ["dom", "seg", "ter", "qua", "qui", "sex", "sáb"]
  readonly property var weekdaysLong: ["domingo", "segunda-feira", "terça-feira", "quarta-feira", "quinta-feira", "sexta-feira", "sábado"]

  readonly property string barText: weekdaysShort[date.getDay()] + Qt.formatDateTime(date, " dd/MM hh:mm")
  readonly property string longDate: weekdaysLong[date.getDay()] + Qt.formatDateTime(date, " dd/MM/yyyy")

  SystemClock {
    id: clock
    precision: SystemClock.Minutes
  }
}
