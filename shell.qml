//@ pragma IconTheme MacTahoe-purple-dark
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.components
import qs.services
import qs.bar
import qs.menus
import qs.overlays

// Barra quickshell, replica ~/.config/waybar (style.css + config.jsonc).
// Numeros em Rubik, icones em Nerd Font (sem fallback misturado).
// Hyprland com IPC lua: dispatchs usam a forma hl.dsp.*.
//
// Este arquivo so compoe. Onde esta cada coisa:
//   components/  tema, icones, pills, popups (PopupBase), tooltip, moldura
//   services/    estado compartilhado (singletons): audio, wifi, updates...
//   bar/         widgets da barra
//   menus/       popups de clique (rede, tray, energia, centro de notificacoes)
//   overlays/    launcher, OSD e toasts (instancia unica, seguem o monitor focado)
//   scripts/     helpers de shell
//
// Multi-monitor: barra + moldura + exclusoes + tooltip + menus sao per-screen
// (Variants model: Quickshell.screens). Launcher + OSD sao instancia unica que
// segue o monitor focado. O centro de notificacoes tambem e instancia unica:
// abre no monitor do sino clicado (centerScreen) ou, por IPC, no focado.
ShellRoot {
  id: root

  // tela do monitor focado: launcher + OSD aparecem onde voce esta
  property var focusedScreen: {
    const f = Hyprland.focusedMonitor ? Hyprland.focusedMonitor.name : "";
    const ss = Quickshell.screens;
    for (let i = 0; i < ss.length; ++i) {
      if (ss[i] && ss[i].name === f)
        return ss[i];
    }
    return ss.length > 0 ? ss[0] : null;
  }

  // monitor do sino que abriu o centro (null = o focado, p.ex. via IPC)
  property var centerScreen: null

  // ---- per-screen: barra + moldura + tooltip + menus + exclusoes ----
  Variants {
    model: Quickshell.screens
    delegate: Component {
      Scope {
        id: scr
        required property var modelData

        // um popup por vez: abrir um fecha os outros (e o tooltip)
        function closeMenusExcept(keep) {
          hoverTip.hide();
          notifCenter.close();
          for (const m of [netMenu, trayMenu, powerMenu]) {
            if (m !== keep)
              m.close();
          }
        }

        Bar {
          screen: scr.modelData
          tip: hoverTip
          onTrayMenuRequested: (item, pos) => {
            scr.closeMenusExcept(trayMenu);
            trayMenu.show(item, pos);
          }
          onNetMenuRequested: {
            scr.closeMenusExcept(netMenu);
            netMenu.toggle();
          }
          onPowerMenuRequested: {
            scr.closeMenusExcept(powerMenu);
            powerMenu.toggle();
          }
          onNotifCenterRequested: {
            scr.closeMenusExcept(null);
            root.centerScreen = scr.modelData;
            notifCenter.toggle();
          }
        }

        // Moldura de janela unica: filetes + dobras inferiores num so Shape.
        EdgeFrame {
          screen: scr.modelData
        }

        TipWindow {
          id: hoverTip
          screen: scr.modelData
        }

        NetMenu {
          id: netMenu
          screen: scr.modelData
        }
        TrayMenu {
          id: trayMenu
          screen: scr.modelData
        }
        PowerMenu {
          id: powerMenu
          screen: scr.modelData
        }

        EdgeExclusions {
          screen: scr.modelData
        }
      }
    }
  }

  // tela de bloqueio: uma superficie por monitor (IPC "lock")
  Lock {
    id: lock
  }

  // ---- single-instance (segue o foco): launcher + OSD + notificacoes ----
  Launcher {
    id: launcher
    screen: root.focusedScreen
  }

  Osd {
    id: osd
    screen: root.focusedScreen
  }

  NotifCenter {
    id: notifCenter
    screen: root.centerScreen ?? root.focusedScreen
  }

  // com o centro aberto os toasts somem (ele ja mostra tudo)
  NotifToasts {
    id: toasts
    screen: root.focusedScreen
    suppress: notifCenter.open
  }

  // eventos de audio/brilho -> OSD (a mesma janela serve os tres)
  Connections {
    target: Audio
    function onSinkShown(pct, muted, icon) {
      osd.show(pct, muted, icon);
    }
    function onSourceShown(pct, muted, icon) {
      osd.show(pct, muted, icon);
    }
  }
  Connections {
    target: Brightness
    function onShown(pct, icon) {
      osd.show(pct, false, icon);
    }
  }

  // Atalhos do Hyprland chamam:  qs ipc call <target> <funcao>
  IpcHandler {
    target: "launcher"
    function toggle(): void {
      launcher.toggle();
    }
  }

  // qs ipc call notifs toggle | clear | dnd | sound
  IpcHandler {
    target: "notifs"
    function toggle(): void {
      root.centerScreen = null;
      notifCenter.toggle();
    }
    function clear(): void {
      Notifs.clearAll();
    }
    function dnd(): void {
      Notifs.toggleDnd();
    }
    function sound(): void {
      Notifs.toggleSound();
    }
  }

  IpcHandler {
    target: "osd"
    function showBright(): void {
      Brightness.showOsd();
    }
    function showMic(): void {
      Audio.showMic();
    }
  }
}
