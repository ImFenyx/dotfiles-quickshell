#!/bin/sh
# Desconecta a interface Wi-Fi (substitui waybar/scripts/wifi-selector.sh --disconnect).
iface=$(nmcli -t -f DEVICE,TYPE device status 2>/dev/null | awk -F: '$2=="wifi" {print $1; exit}')
[ -n "$iface" ] || { notify-send -h boolean:transient:true "Wi-Fi" "Sem interface Wi-Fi"; exit 1; }
nmcli device disconnect "$iface" >/dev/null 2>&1 \
  || notify-send -h boolean:transient:true "Wi-Fi" "Falha ao desconectar $iface"
