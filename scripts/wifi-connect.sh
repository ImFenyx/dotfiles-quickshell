#!/bin/sh
# Conecta numa rede (salva -> connection up; com senha -> wifi connect).
# Feedback via notify-send (paridade com wifi-selector.sh).
ssid=${1:-}; [ -n "$ssid" ] || exit 1
iface=$(nmcli -t -f DEVICE,TYPE device status 2>/dev/null | awk -F: '$2=="wifi" {print $1; exit}')
[ -n "$iface" ] || { notify-send -h boolean:transient:true "Wi-Fi" "Sem interface Wi-Fi"; exit 1; }
# device wifi connect resolve o perfil salvo pelo SSID (connection up exigia o
# nome exato do perfil: "Vilma" vs "Vilma 1" falhava silencioso).
if [ -n "${2:-}" ]; then
  out=$(nmcli device wifi connect "$ssid" password "$2" ifname "$iface" 2>&1)
else
  out=$(nmcli device wifi connect "$ssid" ifname "$iface" 2>&1)
fi
if [ $? -eq 0 ]; then
  : # iwd ja notifica; sem toast duplicado
  # alimenta cache de salvas p/ wifi-scan.sh
  if [ -n "${2:-}" ]; then
    CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/quickshell/wifi-saved"
    mkdir -p "$(dirname "$CACHE")"
    printf '%s\n' "$ssid" >> "$CACHE"
    sort -u "$CACHE" -o "$CACHE"
  fi
else
  notify-send -h boolean:transient:true "Wi-Fi" "Falha ao conectar a $ssid
$out"
fi
