pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Cores e tokens do eco (~/eco/DESIGN.md). Cores = papeis M3 de
// ~/.local/state/eco/colors.json, gerado pelo `eco-theme` (Catppuccin ou wallpaper);
// tokens = ~/.config/eco/tokens.json. Os dois sao vigiados: trocar o tema troca a
// shell ao vivo. Nenhum hex fora daqui (o fallback e o mocha, so ate o primeiro eco-theme).
Singleton {
  id: root

  // ---- cores (papeis M3) ----
  // on_<papel> do M3 vira fg<Papel>: em QML, propriedade "onX" e lida como handler de sinal e chega vazia.
  readonly property color primary: role("primary")
  readonly property color fgPrimary: role("on_primary")
  readonly property color primaryContainer: role("primary_container")
  readonly property color fgPrimaryContainer: role("on_primary_container")
  readonly property color secondary: role("secondary")
  readonly property color tertiary: role("tertiary")
  readonly property color error: role("error")
  readonly property color fgError: role("on_error")
  readonly property color success: role("success")
  readonly property color warning: role("warning")
  readonly property color info: role("info")
  readonly property color surface: role("surface")
  readonly property color surfaceContainer: role("surface_container")
  readonly property color surfaceContainerHigh: role("surface_container_high")
  readonly property color surfaceContainerHighest: role("surface_container_highest")
  readonly property color fgSurface: role("on_surface")
  readonly property color fgSurfaceVariant: role("on_surface_variant")
  readonly property color outline: role("outline")
  readonly property color outlineVariant: role("outline_variant")
  readonly property color scrim: role("scrim")
  readonly property bool dark: colors.mode !== "light"

  readonly property var fallback: ({
      primary: "#cba6f7", on_primary: "#11111b", primary_container: "#494060", on_primary_container: "#cba6f7",
      secondary: "#b4befe", tertiary: "#f5c2e7", error: "#f38ba8", on_error: "#11111b",
      success: "#a6e3a1", warning: "#f9e2af", info: "#89b4fa",
      surface: "#1e1e2e", surface_container: "#313244", surface_container_high: "#3b3d4f", surface_container_highest: "#45475a",
      on_surface: "#cdd6f4", on_surface_variant: "#a6adc8", outline: "#6c7086", outline_variant: "#45475a", scrim: "#11111b"
    })

  function role(name) {
    return colors.colors[name] ?? fallback[name];
  }

  // ---- fontes e tamanhos (px) ----
  readonly property string uiFont: tokens.font.ui ?? "Google Sans Flex"
  readonly property string iconFont: tokens.font.icon ?? "JetBrainsMono Nerd Font Propo"
  readonly property var type: tokens.type     // label_s/m/l, body_s/m/l, title_s/m/l, headline_s/m/l, display_s
  readonly property var icon: tokens.icon     // xs, s, m, l, xl

  readonly property var shape: tokens.shape   // xs..xl_inc, window, frame_inner, popup, dialog
  readonly property var space: tokens.space   // xs..xxl, gap_in, gap_out, border
  readonly property var motion: tokens.motion // springs {k, c}: os mesmos do Hyprland

  // ---- moldura (DESIGN.md › Forma/Espaço) ----
  // Janela: gaps_out 8 do filete, canto 12. Filete = gaps_out, entao o canto interno
  // da moldura (12 + 8 = 20) tem o mesmo centro do canto da janela: concentrico.
  readonly property int barH: 48
  readonly property int edge: space.gap_out          // largura do filete lateral/inferior (= reserva)
  readonly property int frameR: shape.frame_inner    // canto interno da moldura

  // aba colada no filete direito (toasts + centro de notificacoes): comeca onde
  // termina o canto superior direito da moldura
  readonly property int sideTabTop: barH + frameR
  readonly property int sideTabW: 380                // largura do corpo (sem o filete)

  // workspaces da barra: icone de app e teto da faixa. 360 ~ a faixa antiga no pior
  // caso (10 workspaces + special); em 1366px sobram ~40px ate o bloco direito
  // (SSID de 5 letras, volume 100%). SSID/tray maiores comem essa folga: baixe aqui
  readonly property int wsIcon: 16
  readonly property int wsStripMax: 360

  // ---- animacao ----
  // Movimento = springs (SpringPanel: paineis grandes; SpringPill: coisas pequenas).
  // Duracoes so para cor/opacidade, proximas dos springs effects_* do M3.
  readonly property int animFast: 120      // hover: cor e opacidade; seguir a linha do submenu
  readonly property int animNormal: 150    // fade de entrada/saida, cor de pill/atalho, largura dos blocos da barra
  readonly property int animMove: 180      // altura, deslocamento de lista, volta do swipe

  // ---- arquivos ----
  FileView {
    path: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/eco/colors.json"
    blockLoading: true
    watchChanges: true
    onFileChanged: reload()
    JsonAdapter {
      id: colors
      property var colors: ({})
      property string mode: "dark"
    }
  }
  FileView {
    path: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/eco/tokens.json"
    blockLoading: true
    watchChanges: true
    onFileChanged: reload()
    JsonAdapter {
      id: tokens
      property var font: ({})
      property var type: ({})
      property var icon: ({})
      property var shape: ({})
      property var space: ({})
      property var motion: ({})
    }
  }
}
