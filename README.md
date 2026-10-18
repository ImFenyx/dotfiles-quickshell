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
  Genie.qml        efeito "magic lamp" (abre/fecha painel a partir de um ponto)
  TipArea / TipWindow   tooltip
  PopupBase.qml    base de todo popup (menus, launcher, OSD); `floating` = camada p/ paineis extras
  MenuRow.qml      linha de menu
  EdgeFrame / EdgeExclusions / RoundCorner
services/        estado compartilhado (singletons)
  Audio (PipeWire), Wifi, Updates, Brightness, Battery,
  Notifs (swaync), Time, Workspaces, Fullscreen
bar/             widgets da barra (Bar.qml compoe os outros)
menus/           NetMenu, PowerMenu, TrayMenu (cascata: TrayMenuList, TrayFlyout + Genie, TrayEntryRow)
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

## Desempenho

Medir antes de mexer (idle, 60s; compare com a mudanca aplicada):

```sh
scripts/perf.sh 60 antes
# ... aplique a mudanca, reinicie o quickshell ...
scripts/perf.sh 60 depois     # as linhas ficam em ~/.cache/quickshell/perf.csv
```

Mostra CPU medio, acordadas/s, processos filhos (minimo), RAM (RSS/PSS) e
memoria de GPU (fdinfo do driver, quando disponivel).

### O que ja foi feito (e por que)

Contagem de processos em idle, pelas constantes do codigo (nao medida):

| fonte | antes | depois |
|---|---|---|
| Wi-Fi (refresh a cada 30s) | 5 processos x 120/h = ~600/h | 2 x 12/h = ~24/h |
| Brilho (poll a cada 30s) | ~5 processos x 120/h = ~600/h | 5 x 12/h = ~60/h |
| Updates | 2 checagens/h | 2/h na tomada, 0,5/h na bateria (com nice 19) |
| Fullscreen | 1 hyprctl por troca de foco | so quando o estado da janela nao e conhecido |

- **Eventos em vez de polling**: Wi-Fi e Fullscreen reagem a eventos; os polls
  que sobraram sao so rede de seguranca. Hover na pill de Wi-Fi/brilho relê o
  dado na hora, entao o numero mostrado continua fresco.
- **Superficies menores**: tooltip e OSD deixaram de ser janelas de tela cheia
  (cada tooltip mapeava ~8MB de buffer e danificava a tela inteira). Popups
  interativos continuam em tela cheia de proposito: o backdrop evita que o
  clique que fecha o menu atravesse e reabra pelo botao da barra.
- **Genie**: fatias capturam o conteudo uma vez ao fechar.
- **Special workspace**: estado por evento (`activespecial`), sem processo.

Mudancas de comportamento: o tooltip nao acompanha mais o mouse
(`TipArea.follow: true` restaura); brilho e Wi-Fi externos aparecem em ate 5 min
(ou no hover); na bateria os updates sao checados a cada 2h.

### Experimentos de ambiente (nao aplicados: dependem do seu hardware)

Rode `scripts/perf.sh` com cada um e fique com o que medir melhor. Defina antes
de iniciar o quickshell (ex.: no `exec-once` do Hyprland):

- `QSG_RENDER_LOOP=basic` — uma thread de render em vez de uma por janela
  (pode baixar RAM/threads; teste se ha engasgo nas animacoes)
- `QSG_RHI_BACKEND=vulkan` (ou `opengl`) — compare RAM e CPU; `QSG_INFO=1` mostra
  o backend em uso
- `QSG_RENDER_TIMING=1` — tempo por quadro de cada janela (diagnostico)
- Hyprland: desligue blur/xray nas layers do quickshell (as superficies sao
  opacas, o blur so gasta GPU) e confira `misc:vfr` ligado (so redesenha quando
  ha mudanca)

### Analisado e deixado de fora

- **EdgeFrame em 3 faixas**: o layer-shell posiciona superficies com zona
  exclusiva relativo a area util restante (depende da ordem), entao as faixas
  teriam de continuar `Ignore` e as 3 janelas de exclusao ficariam: 7 janelas
  no lugar de 5. Cada janela GL tem contexto proprio, entao pode piorar a RAM.
  Vale testar com o `perf.sh` antes de investir.
- **Popups interativos compactos**: ver acima (clique que reabre).
- **LazyLoader para popups**: poupa pouco (janelas ocultas custam pouco ate o
  primeiro uso) e complica as animacoes de saida.

## Desenvolvimento

```sh
qmlformat -i **/*.qml shell.qml
shellcheck scripts/*.sh
```
