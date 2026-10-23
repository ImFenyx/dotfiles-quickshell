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
  // monitor de onde o mixer/Bluetooth foi aberto (barra ou centro)
  property var menuScreen: null

  // atalho do centro (clique direito em Mudo/Mic/Bluetooth): o centro fecha e o
  // menu desce da barra do mesmo monitor
  function openFromCenter(menu) {
    root.menuScreen = root.centerScreen ?? root.focusedScreen;
    notifCenter.close();
    menu.open = true;
  }

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
          for (const m of [netMenu, trayMenu, powerMenu, audioMenu, btMenu]) {
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
          onAudioMenuRequested: {
            scr.closeMenusExcept(audioMenu);
            root.menuScreen = scr.modelData;
            audioMenu.toggle();
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

  // agente polkit (pedidos de senha do sistema) no monitor focado
  PolkitDialog {
    screen: root.focusedScreen
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
    onAudioRequested: root.openFromCenter(audioMenu)
    onBluetoothRequested: root.openFromCenter(btMenu)
  }

  // mixer e Bluetooth: instancia unica, no monitor de onde foram abertos
  AudioMenu {
    id: audioMenu
    screen: root.menuScreen ?? root.focusedScreen
  }
  BtMenu {
    id: btMenu
    screen: root.menuScreen ?? root.focusedScreen
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
  // Caps/Num/Fn Lock -> OSD no modo tecla
  Connections {
    target: LockKeys
    function onToggled(key, on) {
      if (key === "caps")
        osd.showKey(Icons.capsLock, "Caps Lock", on);
      else if (key === "num")
        osd.showKey(Icons.numLock, "Num Lock", on);
      else
        osd.showKey(Icons.fnLock, "Fn Lock", on);
    }
  }

  // Atalhos do Hyprland: hl.dsp.global("quickshell:<name>") no keybindings.lua.
  // Sem processo por tecla (o exec de `qs ipc call` abria um) e da acesso ao
  // soltar a tecla (onReleased). O IPC abaixo fica p/ scripts e hypridle.
  GlobalShortcut {
    name: "launcher"
    description: "Launcher: apps"
    onPressed: launcher.toggle("")
  }
  GlobalShortcut {
    name: "clipboard"
    description: "Launcher: clipboard"
    onPressed: launcher.toggle("#")
  }
  GlobalShortcut {
    name: "emoji"
    description: "Launcher: emoji"
    onPressed: launcher.toggle(":")
  }
  GlobalShortcut {
    name: "kaomoji"
    description: "Launcher: kaomoji"
    onPressed: launcher.toggle(";")
  }
  GlobalShortcut {
    name: "notifs"
    description: "Centro de notificacoes"
    onPressed: {
      root.centerScreen = null;
      notifCenter.toggle();
    }
  }
  GlobalShortcut {
    name: "lock"
    description: "Bloquear a tela"
    onPressed: lock.lock()
  }
  // bind em Caps_Lock/Num_Lock sem consumir a tecla: so avisa p/ reler os LEDs.
  // O bind e `release = true`: o Hyprland manda o global como *released*, nao pressed.
  GlobalShortcut {
    name: "lockkeys"
    description: "OSD de Caps/Num Lock"
    onReleased: LockKeys.check()
  }

  // Scripts chamam:  qs ipc call <target> <funcao>
  // qs ipc call launcher toggle | calc | emoji | kaomoji | clip | windows (abre ja no modo)
  IpcHandler {
    target: "launcher"
    function toggle(): void {
      launcher.toggle("");
    }
    function calc(): void {
      launcher.toggle("=");
    }
    function emoji(): void {
      launcher.toggle(":");
    }
    function kaomoji(): void {
      launcher.toggle(";");
    }
    function clip(): void {
      launcher.toggle("#");
    }
    function windows(): void {
      launcher.toggle("@");
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

  // qs ipc call time sync: after_sleep_cmd do hypridle (relogio parado apos suspend)
  IpcHandler {
    target: "time"
    function sync(): void {
      Time.sync();
    }
  }
}
