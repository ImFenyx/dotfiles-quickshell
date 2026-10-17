# dotfiles-quickshell

Shell do Hyprland feita em [Quickshell](https://quickshell.org): barra, menus
(rede, tray, energia), launcher e OSD. Tema Catppuccin Mocha.

## Estrutura

```
shell.qml        composicao: so liga as pecas e expoe os atalhos (IPC)
components/      blocos reutilizaveis
  Theme.qml        cores, fontes e geometria (fonte unica)
  Icons.qml        glifos Nerd Font (sempre via escape \u...)
  Config.qml       programas externos (terminal, mixer, locker...)
  Pill / PillText / PillGlyph / UiText / Glyph
  TipArea / TipWindow   tooltip
  PopupBase.qml    base de todo popup (menus, launcher, OSD); `floating` = camada p/ paineis extras
  MenuRow.qml      linha de menu
  EdgeFrame / EdgeExclusions / RoundCorner
services/        estado compartilhado (singletons)
  Audio (PipeWire), Wifi, Updates, Brightness, Battery,
  Notifs (swaync), Time, Workspaces, Fullscreen
bar/             widgets da barra (Bar.qml compoe os outros)
menus/           NetMenu, PowerMenu, TrayMenu (cascata: TrayMenuList, TrayFlyout, TrayEntryRow)
overlays/        Launcher, Osd
scripts/         helpers de shell (updates, frecency, wifi-*, netinfo)
```

Regras de bolso:

- cor, fonte ou medida nova -> `components/Theme.qml`
- glifo novo -> `components/Icons.qml` (escape `\u...`, nunca o caractere literal)
- programa externo -> `components/Config.qml`
- widget novo que abre popup -> use `PopupBase`; ele cuida de janela, mascara,
  foco, Esc, click-fora e animacao
- estado que mais de um widget le -> um singleton em `services/`

## Dependencias

- Hyprland e Quickshell (com os modulos Hyprland, PipeWire, UPower e SystemTray)
- Fontes: Rubik, JetBrainsMono Nerd Font (Propo)
- Tema de icones: MacTahoe-purple-dark (`//@ pragma IconTheme` no `shell.qml`)
- NetworkManager (`nmcli`, `nm-connection-editor`)
- `swaync` (`swaync-client`), `libnotify` (`notify-send`)
- `pacman-contrib` (`checkupdates`) e `paru` — badge de atualizacoes
- `kitty`, `pavucontrol`, `hyprlock`, `cal` (util-linux), `hyprctl`
- `uwsm` (opcional; usado no "Sair")

Os programas que a shell chama ficam em `components/Config.qml`.

## Usar

Clone (ou aponte) para `~/.config/quickshell`. Para testar sem mexer na
instalacao atual:

```sh
qs -p /caminho/do/repo     # roda esta copia
qs log                     # erros e warnings da instancia
```

Atalhos do Hyprland (IPC):

```sh
qs ipc call launcher toggle
qs ipc call osd showBright   # depois de mudar o brilho
qs ipc call osd showMic      # depois de mutar/desmutar o mic
```

O OSD de volume aparece sozinho (PipeWire).

## Desenvolvimento

```sh
qmlformat -i **/*.qml shell.qml
shellcheck scripts/*.sh
```
