#!/bin/sh
# Frecency do launcher: "hit <id>" incrementa, sem args despeja "id<TAB>count".
# TAB porque id de .desktop pode ter espaco (wine: "wine-Programs-...-Configurar Java").
FILE="${XDG_STATE_HOME:-$HOME/.local/state}/quickshell/frecency"
if [ "$1" = hit ] && [ -n "$2" ]; then
  mkdir -p "$(dirname "$FILE")"; touch "$FILE"
  ID="$2" awk -F'\t' -v OFS='\t' '$1==ENVIRON["ID"] {$2++; f=1} {print} END {if (!f) print ENVIRON["ID"], 1}' "$FILE" > "$FILE.tmp" && mv "$FILE.tmp" "$FILE"
  exit 0
fi
[ -f "$FILE" ] && cat "$FILE"
