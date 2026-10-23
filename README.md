# dotfiles-quickshell

Shell do Hyprland feita em [Quickshell](https://quickshell.org): barra, menus
(rede, tray, energia), launcher, OSD e centro de notificacoes. Tema Catppuccin Mocha.

## Estrutura

```
shell.qml        composicao: so liga as pecas e expoe os atalhos (IPC)
components/      blocos reutilizaveis
  Theme.qml        cores, fontes e geometria (fonte unica)
  Icons.qml        glifos Nerd Font (sempre via escape \u...)
  Config.qml       programas externos (terminal, mixer, locker...)
  Pill / PillText / PillGlyph / UiText / Glyph
  Genie.qml        efeito "magic lamp" (abre/fecha painel a partir de um ponto)
  EdgeTab.qml      aba colada no filete direito (orelhas concavas); fundo de toasts e centro
  NotifCard.qml    cartao de uma notificacao (toast e lista do centro)
  TipArea / TipWindow   tooltip
  PopupBase.qml    base de todo popup (menus, launcher, OSD, centro); `floating` = camada p/ paineis extras;
                   `fromRight` = aba no filete direito
  MenuRow.qml      linha de menu
  Slider.qml       slider proprio (sem QtQuick.Controls); SpringPanel / SpringPill
  EdgeFrame / EdgeExclusions / RoundCorner
services/        estado compartilhado (singletons)
  Audio (PipeWire), Wifi (Quickshell.Networking), Updates, Brightness, Battery,
  Notifs (daemon de notificacoes), Media (MPRIS), Time, Workspaces, Fullscreen
  Bt, Caffeine, NightLight, Energy   (atalhos do centro)
  Emoji (dados do launcher), ShellState (estado que sobrevive a restart: state.json)
  NotifItem / NotifGroup = uma notificacao / um grupo por app (criados pelo Notifs)
bar/             widgets da barra (Bar.qml compoe os outros)
menus/           NetMenu, PowerMenu, AudioMenu (mixer; VolumeRow), BtMenu,
                 TrayMenu (cascata: TrayMenuList, TrayFlyout + Genie, TrayEntryRow),
                 NotifCenter (NotifStatusBar = atalhos, NotifQuickTile, NotifGroupView, NotifMedia)
overlays/        Launcher, Osd, NotifToasts, Lock (tela de bloqueio), PolkitDialog (agente polkit)
scripts/         helpers de shell (updates, frecency, netinfo, notif-sound, cliphist-thumbs, perf)
data/            listas estaticas (kaomoji.tsv)
```

Regras de bolso:

- cor, fonte ou medida nova -> `components/Theme.qml`
- glifo novo -> `components/Icons.qml` (escape `\u...`, nunca o caractere literal)
- programa externo -> `components/Config.qml`
- widget novo que abre popup -> use `PopupBase`; ele cuida de janela, mascara,
  foco, Esc, click-fora e animacao
- estado que mais de um widget le -> um singleton em `services/`
- estado que o usuario escolhe e deve sobreviver a restart/reboot (DND, som, tom do
  emoji...) -> propriedade no `JsonAdapter` de `services/ShellState.qml`
  (`~/.local/state/quickshell/state.json`; grava sozinho, relê se o arquivo mudar).
  Nao chame um singleton de `State`: colide com o `State` do QtQuick
- atalho de teclado novo -> `GlobalShortcut { name: "x" }` no `shell.qml` + bind
  `hl.dsp.global("quickshell:x")` com `description` (sem processo por tecla; tem
  onReleased). `IpcHandler` so p/ scripts (hypridle, etc.)
- animacao -> `Theme.animFast` / `animNormal` / `animMove`; slide de painel =
  `SpringPanel {}`, largura que muda = `SpringPill {}`. Numero solto so se for
  especifico (ex.: Genie)
- conteudo pesado de popup (listas com imagem, submenus, previas) -> modelo vazio
  com a janela invisivel (`values: root.visible ? ... : []`); o `visible` do
  PopupBase so cai depois da animacao de saida

## Dependencias

- Hyprland e Quickshell (com os modulos Hyprland, PipeWire, UPower, SystemTray, Networking e Bluetooth)
- Fontes: Rubik, JetBrainsMono Nerd Font (Propo)
- Tema de icones: MacTahoe-purple-dark (`//@ pragma IconTheme` no `shell.qml`)
- NetworkManager: Wi-Fi pelo D-Bus (Quickshell.Networking); `nmcli` so p/ "Alternar rede" e
  `scripts/netinfo.sh`; `nm-connection-editor`
- `libnotify` (`notify-send`, so para testar). A propria shell e o daemon de
  notificacoes: **pare o swaync/dunst/mako** (tire o `exec-once` do Hyprland),
  senao eles seguram o nome `org.freedesktop.Notifications` e nada chega.
- Midia no centro: qualquer player MPRIS (Spotify, mpv, navegador...). `playerctl` e opcional.
- Som das notificacoes: `sound-theme-freedesktop` + `pipewire` (`pw-play`; ou `paplay`/`ffplay`/`canberra-gtk-play`)
- Atalhos do centro: Bluetooth (BlueZ), Cafeina (`systemd-inhibit`; o `hypridle` respeita), Luz noturna
  (`hyprsunset`, ver `Config.nightTemp`; usa o daemon que ja estiver rodando, ex.: servico do systemd, via `hyprctl hyprsunset`), Energia (TLP >= 1.9 com o servico `tlp-pd`:
  `systemctl enable --now tlp-pd`; troca o perfil pelo `tlpctl`, sem root; nao convive com o
  `power-profiles-daemon`; clique direito abre o `tlpui`, ver `Config.powerManager`).
  O que nao existe some do painel.
- `pacman-contrib` (`checkupdates`) e `paru` — badge de atualizacoes
- `kitty`, `pavucontrol`, `cal` (util-linux), `hyprctl`
- `hyprlock` instalado: o lock nativo usa o PAM dele (`/etc/pam.d/hyprlock`) e ele e o
  fallback (`Config.locker`)
- polkit: a propria shell e o agente (`overlays/PolkitDialog.qml`). So um agente registra
  por sessao: desative os outros (`systemctl --user disable --now hyprpolkitagent`) e
  reinicie a shell (`systemctl --user restart quickshell`); "An authentication agent
  already exists" no `qs log` = outro agente ainda rodando
- `uwsm` (opcional; usado no "Sair")
- Modos do launcher: `qalc` (libqalculate), `cliphist` + `wl-clipboard` (com
  `wl-paste --watch cliphist store` rodando), `wtype` (digitar emoji/kaomoji),
  `unicode-emoji` + `unicode-cldr-annotations` (lista oficial de emojis + nomes em pt/en;
  atualizam com o pacman) e uma fonte de emoji colorida (ex.: `ttf-twemoji`)

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
qs ipc call launcher toggle  # apps; tambem: calc | emoji | clip | windows
qs ipc call osd showBright   # depois de mudar o brilho
qs ipc call osd showMic      # depois de mutar/desmutar o mic
```

O OSD de volume aparece sozinho (PipeWire).

OSD de Caps/Num/Fn Lock (`services/LockKeys.qml`): binds em `Caps_Lock`/`Num_Lock`
que nao consomem a tecla (`non_consuming`, no `release`, `locked`) chamam
`quickshell:lockkeys`, que relê os LEDs em `/sys/class/leds/*::capslock|numlock`.
O Fn Lock (Fn+Esc no IdeaPad) e do firmware e nao gera tecla: o `ideapad_laptop`
avisa em `platform::fnlock/brightness_hw_changed`, vigiado por inotify.

## Launcher

Modo pelo 1o caractere da busca (o IPC ja abre com ele):

| prefixo | modo | Enter |
|---|---|---|
| (nada) | apps (ranking por campo + frecency) | abre |
| `=` | calculadora (`qalc`: contas, unidades, moedas) | copia o resultado |
| `:` | emoji (`services/Emoji.qml`: Unicode oficial, busca em pt e en) | copia e digita na janela focada; com `›` abre o popup de tom de pele |
| `;` | kaomoji (lista propria, `data/kaomoji.tsv`) | copia e digita na janela focada |
| `#` | clipboard (`cliphist`, mais novo primeiro): abas texto e imagens | copia de volta |
| `@` | janelas abertas | foca (troca de workspace se precisar) |

Atalho que chama o mesmo modo ja aberto fecha o launcher.

Emoji: a lista tem so o emoji base; os que tem tom de pele mostram `›` e o
Enter/clique abre o popup (setas ou mouse, Enter insere, Esc volta), ja no
ultimo tom usado (`~/.local/state/quickshell/emoji-tone`). Os arquivos do pacman
sao vigiados: emoji novo do Unicode entra quando o pacote atualiza (precisa da
fonte atualizada tambem, senao aparece como quadrado). Bandeiras e outras
sequencias ficam com o nome em ingles (o pt delas so existe no `unicode-cldr`
completo, ~235MB).

Clipboard, como no rofi-cliphist: `Alt+t` texto, `Alt+i` imagens (grade de 3
colunas com miniatura; setas andam na grade), `Alt+d` apaga a selecionada,
`Alt+p` / `Alt+n` apagam todas acima / abaixo dela (na aba e busca atuais). As
miniaturas sao decodificadas 1x por id (`scripts/cliphist-thumbs.sh`) em
`~/.cache/quickshell/cliphist/` (modo 700; o mesmo conteudo do db do cliphist) e
somem do cache quando saem do historico.

## Tela de bloqueio

`overlays/Lock.qml` (ext-session-lock + PAM), no lugar do hyprlock. Uma superficie
por monitor com a tela borrada, relogio e senha; avisos do PAM (faillock: 3 erros
travam a conta por 10 min) aparecem embaixo do campo.

```sh
qs ipc call lock lock        # cadeado da barra, SUPER+O e lock_cmd do hypridle
qs ipc call lock isLocked
```

Reload da shell com a tela travada mantem o lock. Se o processo morrer travado,
o Hyprland segura a tela (`misc.allow_session_lock_restore = true` deixa outro lock
assumir): de um TTY, reinicie o quickshell e rode `qs ipc call lock lock`, ou rode
`hyprlock` apontando para a sessao (`WAYLAND_DISPLAY`), e volte ao TTY do Hyprland.

## Notificacoes

A shell recebe as notificacoes (`services/Notifs.qml`) e mostra em dois lugares,
ambos colados no filete direito da moldura:

- **Toasts** (`overlays/NotifToasts.qml`): aba unica que desliza pela borda, no
  monitor focado. Hover pausa o tempo; clique no corpo roda a acao padrao do app;
  arrastar para a direita (ou o x) fecha; criticas ficam ate dispensar. Somem
  quando o centro abre.
- **Centro** (`menus/NotifCenter.qml`): abre no sino. Em cima os atalhos (a
  "status bar"); no meio as notificacoes **agrupadas por app**; embaixo a midia.

Sino: clique esquerdo abre o centro, direito liga o Nao perturbe.

**Bateria baixa** (`services/Battery.qml`): na bateria, um aviso por limite de
`Config.batteryWarn` (20/10/5%) ao descer; <= 10% e critica (fura o Nao perturbe
e fica ate dispensar). Ligar o carregador zera.

**Grupos** (estilo macOS): um por app, ordenados por **prioridade** (urgencia
critica > normal > baixa) e depois cronologia; dentro do grupo, a mesma regra.
Recolhido mostra a principal com a pilha por tras (clique expande, arrastar
dispensa o grupo todo); expandido tem cabecalho com recolher e limpar o app.

**Atalhos** (`menus/NotifStatusBar.qml`): Wi-Fi, Bluetooth, Nao perturbe, Mudo,
Mic mudo, Cafeina, Luz noturna e Energia. Clique liga/desliga; clique direito
abre o detalhe: Mudo/Mic mudo -> mixer (`AudioMenu`), Bluetooth -> `BtMenu` (o
centro fecha e o menu desce da barra); Wi-Fi -> nm-connection-editor, Energia ->
tlpui. O toggle de Wi-Fi saiu do NetMenu. Hora/data/Wi-Fi/som/bateria nao se
repetem aqui: ja estao na barra.

**Mixer** (`menus/AudioMenu.qml`, clique na pill de audio): volume e mudo de saida e
entrada (clique no icone = mudo; roda do mouse no slider), escolha do dispositivo
padrao e volume de cada app tocando. OSD de volume calado com o mixer aberto.
pavucontrol no rodape p/ perfis e portas.

**Bluetooth** (`menus/BtMenu.qml`): liga/desliga, lista (conectados > pareados >
novos; os que so anunciam o endereco ficam de fora), clique conecta/desconecta ou
pareia e conecta, X esquece (2 cliques), bateria quando o dispositivo informa.
Procura so com o menu aberto. A 0.3.2 nao registra agente BlueZ: dispositivo que
pede PIN/confirmacao precisa de um agente externo (blueman-applet, `bluetoothctl`).

**Midia**: so aparece enquanto algo *toca* (aba de navegador pausada nao conta).
Se voce pausar com o centro aberto ela fica ate fechar, p/ dar para retomar. O
MPRIS nao diz se e musica ou video, entao o rotulo e uma heuristica em
`Media.classify` (nome do app, depois a URL da faixa).

### Padrao freedesktop (Desktop Notifications Specification)

| item | situacao |
|---|---|
| capacidades anunciadas | `actions`, `action-icons`, `body`, `body-markup`, `body-hyperlinks`, `body-images`, `icon-static`, `persistence`, `inline-reply`, `sound`, `x-canonical-private-synchronous` |
| `Notify` / `replaces_id` | atualiza o mesmo cartao, volta a aparecer e reinicia a hora |
| `expire_timeout` | -1 = padrao (`Notifs.defaultTimeout`), 0 = fica ate dispensar, >0 respeitado (4 a 20 s). So o *toast* expira; o historico permanece (capacidade `persistence`), com teto de `Notifs.maxHistory` (100): acima disso as mais antigas nao criticas expiram |
| `CloseNotification` / `NotificationClosed` | fechar pelo app remove na hora; dispensar manda `dismissed`; transient que acaba manda `expired` |
| acoes | `default` = clique no corpo; as demais viram botoes (ou so o icone, com `action-icons`) |
| hints `urgency` | critica fura o Nao perturbe, fica ate dispensar e vai pro topo; baixa nao toca som |
| hints `transient` | so toast: fora do historico, da contagem e dos grupos (em Nao perturbe some sem rastro) |
| hints `resident` | depois de uma acao a notificacao continua |
| hints `sound-file` / `sound-name` / `suppress-sound` | tocam via `scripts/notif-sound.sh`; sem hint usa `message-new-instant` (`dialog-warning` p/ critica). Desligue com `qs ipc call notifs sound` |
| hints `image-data` / `image-path` / `desktop-entry` | icone: imagem do app > `app_icon` > icone do `.desktop` > inicial do app |
| hints `x` / `y` | ignorados (posicao e da shell) |
| hint `value` | barra de progresso no cartao (extensao comum: volume, brilho, download) |
| hints `synchronous` / `x-canonical-private-synchronous` / `x-dunst-stack-tag` | a nova substitui a anterior do mesmo app |
| corpo | `<b> <i> <u> <a href>` renderizados (links abrem no navegador); `<img>` so de arquivo local, vira miniatura; imagem remota nunca e carregada |
| resposta inline | campo no centro (nao no toast: toast nao recebe teclado) |

```sh
qs ipc call notifs toggle   # abre/fecha o centro (monitor focado)
qs ipc call notifs dnd      # nao perturbe
qs ipc call notifs sound    # liga/desliga o som das notificacoes
qs ipc call notifs clear    # apaga tudo

# testes
notify-send -a Teste "Titulo" "Corpo com <b>negrito</b> e <a href=\"https://quickshell.org\">link</a>"
notify-send -u critical "Critica" "Fica ate dispensar e vai pro topo"
notify-send -u low -a Teste "Baixa" "Sem som"
notify-send -e -a Teste "Transient" "Some sozinha e nao fica no centro"
notify-send -h int:value:60 -a Teste "Progresso" "60%"
notify-send -h string:sound-name:bell -a Teste "Som do tema" "sound-name=bell"
notify-send -h string:x-canonical-private-synchronous:vol -a Teste "Volume" "a nova substitui a velha"
notify-send -A abrir=Abrir -A depois=Depois "Com acoes" "Botoes do app"
for i in 1 2 3; do notify-send -a Chat "Mensagem $i" "agrupa por app"; done
```

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
| Wi-Fi (refresh a cada 30s) | 5 processos x 120/h = ~600/h | 0 (D-Bus, sem `nmcli monitor` residente) |
| Brilho (poll a cada 30s) | ~5 processos x 120/h = ~600/h | 0 (FileView + inotify no sysfs; 1 sh na partida) |
| Updates | 2 checagens/h | 2/h na tomada, 0,5/h na bateria (com nice 19) |
| Fullscreen | 1 hyprctl por troca de foco | so quando o estado da janela nao e conhecido |

- **Eventos em vez de polling**: Wi-Fi (D-Bus), brilho (inotify) e Fullscreen
  reagem a eventos, ao vivo. O scanner de Wi-Fi so liga com o NetMenu aberto (ou
  conectando).
- **Janelas de tela cheia**: tooltip e OSD chegaram a ter janela do tamanho do
  conteudo (2b5c4b9), mas voltaram a tela cheia (438f2be, a3db0b7): o reconfigure
  do layer-shell engasgava a barra do OSD e o tooltip seguindo o mouse. O tooltip
  espera 80ms antes de sumir, p/ cruzar o vao entre widgets sem remapear; o OSD
  tem largura fixa (nao re-tessela o fundo em 9->10%). Popups interativos sao tela
  cheia de proposito: o backdrop evita que o clique que fecha o menu atravesse e
  reabra pelo botao da barra.
- **Genie**: 24 fatias; capturam o conteudo uma vez ao fechar.
- **Special workspace**: estado por evento (`activespecial`), sem processo.

Mudanca de comportamento: na bateria os updates sao checados a cada 2h.

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
