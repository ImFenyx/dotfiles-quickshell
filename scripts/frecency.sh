#!/bin/sh
# Frecency do launcher: "id<TAB>pontos<TAB>epoch da ultima abertura".
# "hit <id>" soma 1 ponto; sem args despeja "id<TAB>pontos de agora".
# Os pontos caem pela metade a cada HALF dias sem abrir: o uso antigo perde peso
# e quem voce usa agora sobe (uso diario estabiliza em ~HALF/ln2 = ~20 pontos).
# TAB porque id de .desktop pode ter espaco (wine: "wine-Programs-...-Configurar Java").
FILE="${XDG_STATE_HOME:-$HOME/.local/state}/quickshell/frecency"
HALF=14
NOW=$(date +%s)

# formato antigo "id<TAB>contagem": a contagem vira pontos de agora (copia em .bak-contagem)
if [ -f "$FILE" ] && awk -F'\t' 'NF == 2 {f = 1; exit} END {exit !f}' "$FILE"; then
  cp "$FILE" "$FILE.bak-contagem"
  awk -F'\t' -v OFS='\t' -v now="$NOW" 'NF == 2 {$3 = now} {print}' "$FILE" > "$FILE.tmp" && mv "$FILE.tmp" "$FILE"
fi

# pontos decaidos ate agora: p * 2^(-dias/HALF)
DECAY='function decay(p, t) { return p * exp(-(now - t) * log(2) / (half * 86400)) }'

if [ "$1" = hit ] && [ -n "$2" ]; then
  mkdir -p "$(dirname "$FILE")"; touch "$FILE"
  ID="$2" awk -F'\t' -v OFS='\t' -v now="$NOW" -v half="$HALF" "$DECAY"'
    $1 == ENVIRON["ID"] {$2 = sprintf("%.4f", decay($2, $3) + 1); $3 = now; f = 1}
    {print}
    END {if (!f) print ENVIRON["ID"], 1, now}' "$FILE" > "$FILE.tmp" && mv "$FILE.tmp" "$FILE"
  exit 0
fi
[ -f "$FILE" ] && awk -F'\t' -v OFS='\t' -v now="$NOW" -v half="$HALF" "$DECAY"'
  {printf "%s\t%.4f\n", $1, decay($2, $3)}' "$FILE"
