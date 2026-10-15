#!/bin/sh
# Frecency do launcher: "hit <id>" incrementa, sem args despeja "id count".
FILE="${XDG_STATE_HOME:-$HOME/.local/state}/quickshell/frecency"
if [ "$1" = hit ] && [ -n "$2" ]; then
  mkdir -p "$(dirname "$FILE")"; touch "$FILE"
  awk -v id="$2" '$1==id {$2++; f=1} {print} END {if (!f) print id, 1}' "$FILE" > "$FILE.tmp" && mv "$FILE.tmp" "$FILE"
  exit 0
fi
[ -f "$FILE" ] && cat "$FILE"
