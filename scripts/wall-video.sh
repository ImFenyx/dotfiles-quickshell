#!/bin/sh
# Wallpaper em video (seletor): toca <arquivo> em loop, sem audio, cobrindo cada
# <saida> (um processo por tela: nenhum dos players tem "todas as telas"). Roda
# dentro da unidade transiente qs-wallvideo (systemd-run --user, ver
# services/Wallpapers.qml): sobrevive a reload da shell e para com
# `systemctl --user stop qs-wallvideo`.
# Sem -p (pausar quando escondido): em tiling as janelas cobrem o wallpaper e o
# player congelava o video em poucos segundos, mesmo aparecendo pelas bordas.
# Decodificacao por hardware: mpvpaper via hwdec (VA-API do mpv); gslapper so com
# o gst-plugin-va instalado (o GStreamer escolhe sozinho), senao vai na CPU.
# Uso: wall-video.sh <gslapper|mpvpaper> <arquivo> <saida>...
player=${1:?player}
file=${2:?arquivo}
shift 2
case $player in
gslapper) opts="no-audio loop fill" ;;                         # fill = cobre a tela, corta o excesso
mpvpaper) opts="no-audio loop panscan=1.0 hwdec=auto-safe" ;;  # panscan=1.0 = o mesmo no mpv
*)
  echo "player desconhecido: $player" >&2
  exit 1
  ;;
esac
# camada bottom: sempre acima da imagem do awww (background), mesmo se o daemon reiniciar
for out; do
  "$player" -l bottom -o "$opts" "$out" "$file" &
done
wait
