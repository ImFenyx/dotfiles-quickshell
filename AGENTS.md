# AGENTS.md — shell Quickshell do eco

Shell de desktop (barra, launcher, notificações, OSD, lock, captura, overview…) em Quickshell 0.3 / Qt 6.12, para Hyprland com config em Lua. Este arquivo é para quem vai mexer no código, pessoa ou agente de IA. O `README.md` é a referência de uso e traz as convenções na seção "Como estender"; a régua visual é o `~/eco/DESIGN.md` do ecossistema.

## Onde fica o quê

- `shell.qml`: a raiz. Instancia tudo, registra os atalhos globais (`GlobalShortcut`) e o IPC (`IpcHandler`)
- `components/`: a base. `Theme` (tokens), `PopupBase` (todo popup), `StateLayer`, `MenuRow`, `Slider`, `SpringPanel`/`SpringPill`, `Config` (programas externos)
- `services/`: singletons com o estado do sistema (Audio, Wifi, Bt, Notifs, Media, Battery…)
- `bar/`, `menus/`, `overlays/`: a barra, os menus que descem dela e as telas cheias
- `scripts/`: shell scripts que a shell chama; `data/`: dados estáticos
- `tests/`: `tests/run`

## Antes de mudar

- Leia "Como estender" no README: cor, fonte, glifo, atalho, animação, superfície, hover e teclado têm um jeito só, e ele vale para todo arquivo novo.
- Todo valor visual sai do `Theme` (tokens de `~/.config/eco`). Nada de cor ou medida solta.
- Mudança visual só vai para commit depois que o usuário testar na tela.

## Regras que já custaram um crash ou um bug

- Lista que muda de ordem não vai como itens num `ScriptModel`: o `QQmlDelegateModel` do Qt 6.12 dessincroniza o cache num move de linha (SIGSEGV em `_q_itemsMoved`). O modelo são posições (`results.map((_, i) => i)`) e o delegate lê `results[index]` (ver `overlays/Launcher.qml`).
- Objeto que o serviço apaga na hora (`PwNode`, `BluetoothDevice`, `WifiNetwork`) não vai como item de `Repeater`: o modelo são linhas primitivas publicadas por um `Timer` de 0 ms e cada delegate resolve o objeto (`Audio.sinkRows`/`nodeFor`, `Bt.deviceFor`, `Wifi.networkFor`). `ObjectModel` do próprio Quickshell (tray, MPRIS) direto no modelo é seguro.
- Propriedade QML não começa com `on` + maiúscula (vira handler de sinal); os papéis `on_*` do M3 se chamam `fg*`.
- Texto que vem de fora (app, notificação, SSID, nome de dispositivo) leva `textFormat: Text.PlainText`.
- App aberto pela shell: `Quickshell.execDetached(Config.app(cmd))` (uwsm-app). No cgroup do serviço ele morre a cada restart da shell.
- `Behavior` com spring leva `enabled: !Theme.reduceMotion`.
- Hover, foco e clique: `StateLayer`. Nunca trocar a cor do fundo.
- Sem polling: sinal do serviço do Quickshell, depois stream de eventos que já existe, depois `FileView` com `watchChanges`, depois push do comando que mudou o estado. `Timer` de consulta só com o menu aberto.

## Rodar e testar

- O watcher está desligado (`QS_DISABLE_FILE_WATCHER` no unit): depois de editar, `systemctl --user restart quickshell` (no eco, `eco restart shell`, que recusa com a tela travada).
- Avisos: `journalctl --user -u quickshell`. Crash: `coredumpctl info <pid>` e `~/.cache/quickshell/crashes/*/report.txt` (stack e o fim do log da instância que caiu).
- `tests/run` antes de commitar: a busca do launcher (Node), o `frecency.sh` e a compilação de todo QML (pega import quebrado, tipo e propriedade inexistentes; precisa da sessão Wayland).
- Instância de teste: copie a pasta e rode `quickshell -p <copia>/<arquivo>.qml` (IPC e estado próprios). Num `PopupBase` de teste, `interactive: false` não toma o teclado do usuário, e `Theme.reduceMotion = true` evita depender das molas.
- Lógica sem QML (ranking, parsing, agrupamento) vai para um `.js` que termina com `if (typeof module !== "undefined") module.exports = {...}`, e ganha teste em `tests/` (ver `overlays/LauncherSearch.js`).
- Teste só se pegar uma regressão: diga qual no comentário e confira que ele falha sem a mudança.

## Git

- A pasta é a config viva: nunca `git checkout` de um commit antigo com arquivos diferentes. Branch: `git switch -c <nome>` (mesmo commit), commit, `git checkout -B main`.
- Commits pequenos e por assunto, mensagem em português sem acento, com o porquê.
