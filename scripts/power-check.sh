#!/bin/sh
# Aviso do PowerMenu ao armar: o que se perderia desligando/reiniciando/saindo/dormindo.
# Uma linha por item, o mais importante primeiro; nada pendente = sem saida.
# PACMAN_LOCK so p/ teste (o lock de verdade e do root).

# transacao do libalpm (pacman, paru instalando...): o lock so existe durante ela.
# pacman sem lock (-Q, o checkupdates do updates.sh com --dbpath proprio) nao conta
[ -e "${PACMAN_LOCK:-/var/lib/pacman/db.lck}" ] && echo "pacman rodando"

# AUR: consulta (-Q..., ex.: o paru -Qua do updates.sh) nao conta. -a = linha de
# comando; makepkg e script (o argv comeca pelo bash), por isso vai a parte
pgrep -ax 'paru|yay' | awk '$3 !~ /^-Q/ { sub(/.*\//, "", $2); if (!seen[$2]++) print $2 " rodando" }'
pgrep -x makepkg >/dev/null && echo "makepkg rodando"

# programa que pediu ao logind p/ nao desligar/dormir (gravar disco, atualizar...).
# So "block": os "delay" (navegador salvando estado, NetworkManager) so atrasam.
# Um objeto por linha (quebra antes de cada {"who":; "why" pode ter chaves)
systemd-inhibit --list --json=short 2>/dev/null | sed 's/{"who":/\n&/g' \
  | grep -E '"what":"[^"]*(shutdown|sleep)' | grep '"mode":"block' \
  | sed 's/^{"who":"\([^"]*\)".*/\1 bloqueia/'

# download do navegador sendo escrito: mexido nos ultimos 2 min (.part esquecido de
# um download que falhou nao conta). xdg-user-dir sem DOWNLOAD configurado da o $HOME
dir=$(xdg-user-dir DOWNLOAD 2>/dev/null)
case $dir in "" | "$HOME") dir=$HOME/Downloads ;; esac
n=$(find "$dir" -maxdepth 1 \( -name '*.part' -o -name '*.crdownload' -o -name '*.download' \) -mmin -2 2>/dev/null | wc -l)
if [ "$n" -eq 1 ]; then
  echo "1 download em andamento"
elif [ "$n" -gt 1 ]; then
  echo "$n downloads em andamento"
fi
