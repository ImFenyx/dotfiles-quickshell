#!/bin/bash
# scripts/frecency.sh num estado de mentira (XDG_STATE_HOME temporario; o real nao e tocado).
# Pega: migracao do formato antigo perder contagem ou nao guardar backup, `hit` nao somar,
# o decaimento (meia-vida 14 dias) parar, id com espaco quebrar a linha.
set -uo pipefail
here=$(cd "$(dirname "$0")" && pwd)
script="$here/../scripts/frecency.sh"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
export XDG_STATE_HOME=$tmp
file=$tmp/quickshell/frecency
fails=0
check() { # check <descricao> <obtido> <esperado>
  if [[ $2 == "$3" ]]; then
    echo "ok - $1"
  else
    echo "not ok - $1: obtido '$2', esperado '$3'"
    fails=$((fails + 1))
  fi
}
points() { sh "$script" | awk -F'\t' -v id="$1" '$1 == id {print $2}'; }

# formato antigo "id<TAB>contagem": vira pontos de agora, com backup
mkdir -p "$tmp/quickshell"
printf 'kitty\t7\nwine-Programs-Configurar Java\t2\n' >"$file"
check "migracao mantem a contagem" "$(points kitty)" "7.0000"
check "migracao guarda backup" "$(cut -f2 "$file.bak-contagem" | head -1)" "7"
check "migracao grava 3 colunas" "$(awk -F'\t' '{print NF}' "$file" | sort -u)" "3"

# hit soma 1 (a id com espaco continua uma linha so)
sh "$script" hit kitty
check "hit soma 1" "$(points kitty)" "8.0000"
sh "$script" hit "wine-Programs-Configurar Java"
check "id com espaco" "$(points "wine-Programs-Configurar Java")" "3.0000"
sh "$script" hit novo
check "id novo comeca em 1" "$(points novo)" "1.0000"

# 14 dias parado = metade; 28 = um quarto
old=$(($(date +%s) - 14 * 86400))
older=$(($(date +%s) - 28 * 86400))
printf 'meio\t8\t%s\nquarto\t8\t%s\n' "$old" "$older" >>"$file"
check "14 dias = metade" "$(points meio)" "4.0000"
check "28 dias = um quarto" "$(points quarto)" "2.0000"
sh "$script" hit meio
check "hit soma sobre o decaido" "$(points meio)" "5.0000"

((fails == 0))
