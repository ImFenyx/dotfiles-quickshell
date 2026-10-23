#!/bin/sh
# Mostra info da conexao ativa via notify-send (substitui waybar/scripts/netinfo.sh).
iface=$(nmcli -t -f DEVICE,TYPE,STATE device status 2>/dev/null \
  | awk -F: '$3=="connected" && ($2=="wifi" || $2=="ethernet") {print $1; exit}')
if [ -z "$iface" ]; then
  notify-send -h boolean:transient:true "Conexão" "Sem conexão ativa"
  exit 1
fi
# um nmcli so: -g com varios campos sai um por linha (multivalor vem "a | b")
{ read -r name; read -r ip4; read -r gw; read -r dns; } <<EOF
$(nmcli -e no -g GENERAL.CONNECTION,IP4.ADDRESS,IP4.GATEWAY,IP4.DNS device show "$iface" 2>/dev/null)
EOF
ip4=${ip4%% | *}
notify-send -h boolean:transient:true "Conexão: ${name:-$iface}" "Interface: $iface
IP: ${ip4:--}
Gateway: ${gw:--}
DNS: ${dns:--}"
