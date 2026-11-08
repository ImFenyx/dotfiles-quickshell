#!/bin/bash
# Compila todo QML da shell numa copia, sem instanciar nada (sem processo, D-Bus nem
# janela: nenhum efeito colateral). Pega o que derruba a shell na partida: erro de
# sintaxe, import quebrado, tipo inexistente, propriedade que nao existe.
# Erro de binding em tempo de execucao (TypeError) nao aparece aqui.
# Precisa da sessao Wayland (o quickshell abre a conexao mesmo sem janela): sem ela, pula (77).
set -uo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)

if [[ -z ${WAYLAND_DISPLAY:-} ]]; then
  for s in "${XDG_RUNTIME_DIR:-/run/user/$UID}"/wayland-[0-9]; do
    [[ -S $s ]] && export WAYLAND_DISPLAY=${s##*/} && break
  done
fi
if [[ -z ${WAYLAND_DISPLAY:-} ]]; then
  echo "skip - sem sessao Wayland"
  exit 77
fi

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
# copia o que o git ve (versionado + novo nao ignorado), como a shell rodaria
(cd "$root" && { git ls-files; git ls-files --others --exclude-standard; } | sort -u | while IFS= read -r f; do
  [[ -f $f ]] && install -Dm644 "$f" "$tmp/$f"
done)
mapfile -t files < <(cd "$tmp" && find shell.qml bar components menus overlays services -name '*.qml' 2>/dev/null | sort)

# os modulos qs.* so existem se a raiz importa (importar nao instancia singleton);
# o Qt.quit() no onCompleted e ignorado, dai o Timer
cat >"$tmp/__compile.qml" <<'EOF'
import QtQuick
import Quickshell
import qs.components
import qs.services
import qs.bar
import qs.menus
import qs.overlays
ShellRoot {
  Timer {
    interval: 1
    running: true
    onTriggered: compile()
  }
  function compile() {
    const files = Quickshell.env("QML_FILES").split("\n").filter(f => f !== "");
    let bad = 0;
    for (const f of files) {
      const c = Qt.createComponent(Qt.resolvedUrl(f), Component.PreferSynchronous);
      if (c.status !== Component.Ready) {
        console.log("COMPILE_FAIL " + f + ": " + c.errorString().trim().replace(/\n/g, " | "));
        bad++;
      }
    }
    console.log("COMPILE_DONE " + files.length + " " + bad);
    Qt.quit();
  }
}
EOF

out=$(cd "$tmp" && QML_FILES=$(printf '%s\n' "${files[@]}") QS_NO_RELOAD_POPUP=1 timeout 60 quickshell -p ./__compile.qml 2>&1)
grep -oE 'COMPILE_FAIL .*' <<<"$out" | sed 's/^COMPILE_FAIL /not ok - /'
done=$(grep -oE 'COMPILE_DONE [0-9]+ [0-9]+' <<<"$out" | tail -1)
if [[ -z $done ]]; then
  echo "not ok - o quickshell nao terminou a compilacao"
  echo "$out" | tail -20
  exit 1
fi
read -r _ total bad <<<"$done"
echo "ok - $((total - bad)) de $total arquivos compilam"
((bad == 0))
