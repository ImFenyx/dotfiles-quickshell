#!/bin/sh
# Esquece rede salva (apaga perfis com esse SSID). Feedback via notify.
ssid=${1:-}; [ -n "$ssid" ] || exit 1
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/quickshell/wifi-saved"
profs=$(nmcli -t -f NAME,TYPE connection show 2>/dev/null | awk -F: '$2=="802-11-wireless" {print $1}' \
  | while IFS= read -r prof; do
    s=$(nmcli -g 802-11-wireless.ssid connection show "$prof" 2>/dev/null)
    [ "$s" = "$ssid" ] && printf '%s\n' "$prof"
  done)
if [ -z "$profs" ]; then
  notify-send -h boolean:transient:true "Wi-Fi" "Nenhum perfil salvo p/ $ssid"
  exit 0
fi
printf '%s\n' "$profs" | while IFS= read -r prof; do
  nmcli connection delete "$prof" >/dev/null 2>&1
done
[ -f "$CACHE" ] && grep -vxF "$ssid" "$CACHE" > "$CACHE.tmp" && mv "$CACHE.tmp" "$CACHE"
notify-send -h boolean:transient:true "Wi-Fi" "Rede esquecida: $ssid"
