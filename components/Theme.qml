pragma Singleton

import QtQuick
import Quickshell

// Fonte unica de cores, fontes e geometria (Catppuccin Mocha).
// Antes: hex e "Rubik" copiados em todo arquivo, menuBg redefinido 5x e
// barH espelhado a mao (shRoot.barH vs barWin.barH).
Singleton {
  // ---- cores ----
  readonly property color base: "#1e1e2e"
  readonly property color surface0: "#313244"
  readonly property color surface1: "#45475a"
  readonly property color overlay0: "#6c7086"
  readonly property color subtext0: "#a6adc8"
  readonly property color text: "#cdd6f4"
  readonly property color mauve: "#cba6f7"
  readonly property color lavender: "#b4befe"
  readonly property color blue: "#89b4fa"
  readonly property color green: "#a6e3a1"
  readonly property color peach: "#fab387"
  readonly property color red: "#f38ba8"
  readonly property color rosewater: "#f5e0dc"

  // ---- fontes ----
  readonly property string uiFont: "Rubik"
  readonly property string iconFont: "JetBrainsMono Nerd Font Propo"

  // ---- geometria ----
  // Medidas derivadas do gaps_out do Hyprland (modules/look.lua).
  // Troque gap junto com o gaps_out para manter a proporcao.
  readonly property int gap: 16
  readonly property int barH: gap * 3
  readonly property int scoop: gap
  readonly property int edge: gap / 2          // largura do filete lateral/inferior
  readonly property int bendR: scoop - edge    // raio interno da dobra inferior
  readonly property int topH: barH + scoop     // faixa da barra (barra + scoop)

  // aba colada no filete direito (toasts + centro de notificacoes)
  readonly property int sideTabTop: topH + gap / 2   // y onde a concordancia comeca, abaixo do scoop da barra
  readonly property int sideTabW: 380                // largura do corpo (sem o filete)
}
