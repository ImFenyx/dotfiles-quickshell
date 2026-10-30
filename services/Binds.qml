pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Atalhos do Hyprland para a cheatsheet (SUPER+F1). `hyprctl -j binds` e lido na
// partida e a cada reload da config (evento configreloaded), nunca ao abrir.
// Agrupa pelo prefixo da descricao ("Grupo: texto", regra do DESIGN.md) e junta as
// repeticoes: setas e HJKL viram uma linha, workspaces 1-10 tambem.
Singleton {
  id: root

  // [{ name, rows: [{ keys: ["Super", "← / H"], text }] }]
  property var groups: []

  readonly property var order: ["Apps", "Shell", "Editar", "Janela", "Foco", "Mover", "Tamanho", "Workspace", "Layout", "Zoom", "Captura", "Sistema", "Mídia"]
  readonly property var names: ({
      left: "←", right: "→", up: "↑", down: "↓", period: ".", comma: ",", bracketleft: "[", bracketright: "]",
      equal: "=", minus: "-", SPACE: "Espaço", TAB: "Tab", ESCAPE: "Esc", PRINT: "Print",
      mouse_down: "Roda ↓", mouse_up: "Roda ↑", "mouse:272": "Botão esq.", "mouse:273": "Botão dir.",
      Caps_Lock: "Caps Lock", Num_Lock: "Num Lock",
      XF86AudioRaiseVolume: "Vol +", XF86AudioLowerVolume: "Vol −", XF86AudioMute: "Mudo", XF86AudioMicMute: "Mic",
      XF86AudioNext: "⏭", XF86AudioPrev: "⏮", XF86AudioPlay: "⏯", XF86AudioPause: "⏯",
      XF86MonBrightnessUp: "Brilho +", XF86MonBrightnessDown: "Brilho −"
    })

  function mods(m) {
    const out = [];
    if (m & 64)
      out.push("Super");
    if (m & 4)
      out.push("Ctrl");
    if (m & 8)
      out.push("Alt");
    if (m & 1)
      out.push("Shift");
    return out;
  }
  function key(k) {
    return names[k] ?? (k.length === 1 ? k.toUpperCase() : k);
  }

  function build(binds) {
    const rows = new Map();   // "Grupo: texto normalizado" -> { group, text, mods, keys }
    for (const b of binds) {
      const d = b.description || "";
      const i = d.indexOf(": ");
      if (i < 0)
        continue;
      const group = d.slice(0, i);
      const text = d.slice(i + 2).replace(/\b\d+\b/, "1–10");
      const m = mods(b.modmask).join("+");
      const id = group + "\u0000" + text + "\u0000" + m;
      if (!rows.has(id))
        rows.set(id, { group: group, text: text, mods: mods(b.modmask), keys: [] });
      const k = key(b.key);
      const r = rows.get(id);
      if (!r.keys.includes(k))
        r.keys.push(k);
    }
    const byGroup = new Map();
    for (const r of rows.values()) {
      // 1..9 + 0 colapsam numa faixa; o resto vira "a / b"
      const digits = r.keys.length > 3 && r.keys.every(k => /^\d$/.test(k));
      const last = digits ? "1 … 0" : r.keys.join(" / ");
      if (!byGroup.has(r.group))
        byGroup.set(r.group, []);
      byGroup.get(r.group).push({ keys: r.mods.concat([last]), text: r.text });
    }
    const names = [...byGroup.keys()].sort((a, b) => {
      const ia = order.indexOf(a), ib = order.indexOf(b);
      return (ia < 0 ? 99 : ia) - (ib < 0 ? 99 : ib);
    });
    return names.map(n => ({ name: n, rows: byGroup.get(n) }));
  }

  function reload() {
    proc.running = true;
  }

  Connections {
    target: Hyprland
    function onRawEvent(event) {
      if (event.name === "configreloaded")
        root.reload();
    }
  }

  Process {
    id: proc
    command: ["hyprctl", "-j", "binds"]
    running: true
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          root.groups = root.build(JSON.parse(text));
        } catch (e) {}
      }
    }
  }
}
