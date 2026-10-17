#!/bin/sh
# Conecta numa rede (salva -> connection up; com senha -> wifi connect).
# Feedback via notify-send (paridade com wifi-selector.sh).
#
# Uso:
#   wifi-connect.sh <ssid>             rede salva / aberta
#   wifi-connect.sh <ssid> --stdin     senha na 1a linha do stdin (recomendado)
#   wifi-connect.sh <ssid> <senha>     senha como argumento (legado: aparece em ps)
#
# Com --stdin a senha vai para `nmcli --ask` por pipe e nunca aparece na linha
# de comando (/proc/*/cmdline e legivel por qualquer usuario). Se na sua versao
# do nmcli o --ask nao ler o pipe, mude para 1 e volte ao comportamento antigo:
PASSWORD_VIA_ARGV=0

ssid=${1:-}; [ -n "$ssid" ] || exit 1
mode=${2:-}
pw=""
case "$mode" in
  "") ;;
  --stdin) IFS= read -r pw ;;
  *) pw=$mode ;;
esac

iface=$(nmcli -t -f DEVICE,TYPE device status 2>/dev/null | awk -F: '$2=="wifi" {print $1; exit}')
[ -n "$iface" ] || { notify-send -h boolean:transient:true "Wi-Fi" "Sem interface Wi-Fi"; exit 1; }

# device wifi connect resolve o perfil salvo pelo SSID (connection up exigia o
# nome exato do perfil: "Vilma" vs "Vilma 1" falhava silencioso).
if [ -z "$pw" ]; then
  out=$(nmcli device wifi connect "$ssid" ifname "$iface" 2>&1)
elif [ "$mode" = "--stdin" ] && [ "$PASSWORD_VIA_ARGV" != 1 ]; then
  out=$(printf '%s\n' "$pw" | nmcli --ask device wifi connect "$ssid" ifname "$iface" 2>&1)
else
  out=$(nmcli device wifi connect "$ssid" password "$pw" ifname "$iface" 2>&1)
fi
rc=$?

if [ $rc -eq 0 ]; then
  # alimenta cache de salvas p/ wifi-scan.sh
  if [ -n "$pw" ]; then
    CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/quickshell/wifi-saved"
    mkdir -p "$(dirname "$CACHE")"
    printf '%s\n' "$ssid" >> "$CACHE"
    sort -u "$CACHE" -o "$CACHE"
  fi
else
  notify-send -h boolean:transient:true "Wi-Fi" "Falha ao conectar a $ssid
$out"
fi
