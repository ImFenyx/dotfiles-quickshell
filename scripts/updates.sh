#!/bin/sh
# Badge repo + AUR com dedupe por nome. Falha -> sem saida (QML mantem ultimo valor).
# checkupdates: 0=com updates, 2=limpo, 1=erro (sync/lock).
o1=$(checkupdates 2>/dev/null); s1=$?
case $s1 in
  2) o1="" ;;                          # limpo de verdade
  0) [ -n "$o1" ] || exit 1 ;;         # vazio com exit 0 = anomalia: mantem anterior
  *) exit 1 ;;                         # erro sync/lock
esac
o2=$(paru -Qua 2>/dev/null || true) # exit 1 + vazio = sem updates AUR, nao erro
list=$( { printf '%s\n' "$o1" "$o2"; } | grep -v '^$' | awk '!seen[$1]++' )
if [ -z "$list" ]; then
  out=0
else
  out=$(echo "$list" | wc -l)
  out="$out
$(echo "$list" | head -n 16)"
fi
echo "$out"
# cache p/ estreia instantanea no proximo boot (QML le antes do poll de 1800s)
CACHE="${XDG_STATE_HOME:-$HOME/.local/state}/quickshell/updates-cache"
mkdir -p "$(dirname "$CACHE")"
printf '%s\n' "$out" > "$CACHE"
