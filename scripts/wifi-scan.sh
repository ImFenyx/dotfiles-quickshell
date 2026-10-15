#!/bin/sh
# Lista redes wifi: ssid|signal|security|inuse|saved (top 8 por sinal).
# Sem saida = falha (QML mantem estado). SSID com ':' quebra o parse
# (limitacao herdada do wifi-selector.sh do rofi).
# Salvas: cache em $CACHE (perfis tem nome proprio; lookup por perfil e lento
# e so vale a pena no --rescan; wifi-connect.sh alimenta o cache ao salvar).
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/quickshell/wifi-saved"
iface=$(nmcli -t -f DEVICE,TYPE device status 2>/dev/null | awk -F: '$2=="wifi" {print $1; exit}')
[ -n "$iface" ] || exit 1
rescan=no
[ "${1:-}" = "--rescan" ] && rescan=yes
if [ "$rescan" = yes ] || [ ! -s "$CACHE" ]; then
  mkdir -p "$(dirname "$CACHE")"
  nmcli -t -f NAME,TYPE connection show 2>/dev/null | awk -F: '$2=="802-11-wireless" {print $1}' \
    | while IFS= read -r prof; do
      nmcli -g 802-11-wireless.ssid connection show "$prof" 2>/dev/null
    done | grep -v '^$' | sort -u > "$CACHE.tmp" && mv "$CACHE.tmp" "$CACHE"
fi
saved=$(cat "$CACHE" 2>/dev/null)
nmcli -t -f SSID,SIGNAL,SECURITY,IN-USE device wifi list ifname "$iface" --rescan "$rescan" 2>/dev/null \
  | grep -v '^:' | sort -t: -k2 -rn | awk -F: '!seen[$1]++' | head -n 8 \
  | while IFS=: read -r ssid signal security in_use; do
    sv=0; printf '%s' "$saved" | grep -qxF "$ssid" && sv=1
    iu=0; [ "$in_use" = "*" ] && iu=1
    printf '%s|%s|%s|%s|%s\n' "$ssid" "$signal" "$security" "$iu" "$sv"
  done
