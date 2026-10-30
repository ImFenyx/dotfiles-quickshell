pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.components

// Estado do eco para o shell (~/.local/state/eco, vigiado): tema ativo (gravado pelo
// eco-theme), efeitos completos e modo jogo (hypr/modules/profile.lua). Os botoes do
// centro mudam pelo mesmo caminho dos atalhos: eco-theme e hyprctl eval.
Singleton {
  id: root

  readonly property string dir: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/eco/"
  property string theme: "mocha"        // mocha | latte | wall
  property bool effectsAlways: false
  property bool game: false

  readonly property string themeLabel: theme === "latte" ? "Latte" : (theme === "wall" ? "Wallpaper" : "Mocha")
  // Wallpaper so quando ha imagem de onde tirar as cores (video: a miniatura)
  readonly property var themes: Wallpapers.colorSource !== "" ? ["mocha", "latte", "wall"] : ["mocha", "latte"]

  function setTheme(name, dark) {
    const cmd = [Quickshell.env("HOME") + "/.local/bin/eco-theme", name];
    if (name === "wall")
      cmd.push(Wallpapers.colorSource, dark ? "dark" : "light");
    Quickshell.execDetached(cmd);
  }
  function cycleTheme() {
    setTheme(themes[(themes.indexOf(theme) + 1) % themes.length], true);
  }

  // trocou o wallpaper com o tema Wallpaper ativo: cores novas, mesmo claro/escuro
  Connections {
    target: Wallpapers
    function onApplied() {
      if (root.theme === "wall" && Wallpapers.colorSource !== "")
        root.setTheme("wall", Theme.dark);
    }
  }
  function toggleEffects() {
    Quickshell.execDetached(["hyprctl", "eval", "eco_effects()"]);
  }
  function toggleGame() {
    Quickshell.execDetached(["hyprctl", "eval", "eco_game()"]);
  }

  FileView {
    path: root.dir + "theme"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.theme = text().trim() || "mocha"
  }
  FileView {
    path: root.dir + "effects"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.effectsAlways = text().trim() === "always"
  }
  FileView {
    path: root.dir + "game"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.game = text().trim() === "1"
  }
}
