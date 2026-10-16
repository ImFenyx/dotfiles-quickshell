#!/bin/sh
# Mostra info da conexao ativa via notify-send (substitui waybar/scripts/netinfo.sh).
iface=$(nmcli -t -f DEVICE,TYPE,STATE device status 2>/dev/null \
  | awk -F: '$3=="connected" && ($2=="wifi" || $2=="ethernet") {print $1; exit}')
if [ -z "$iface" ]; then
  notify-send -h boolean:transient:true "Conexão" "Sem conexão ativa"
  exit 1
fi
name=$(nmcli -g GENERAL.CONNECTION device show "$iface" 2>/dev/null)
ip4=$(nmcli -g IP4.ADDRESS device show "$iface" 2>/dev/null | head -n1)
gw=$(nmcli -g IP4.GATEWAY device show "$iface" 2>/dev/null)
dns=$(nmcli -g IP4.DNS device show "$iface" 2>/dev/null | tr '\n' ' ')
notify-send -h boolean:transient:true "Conexão: ${name:-$iface}" "Interface: $iface
IP: ${ip4:--}
Gateway: ${gw:--}
DNS: ${dns:--}"
