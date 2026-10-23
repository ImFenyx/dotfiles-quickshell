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
# Controle: cada player abre um socket em $XDG_RUNTIME_DIR (precisa do socat).
# - pause|resume (bateria): mpv por JSON, gslapper por texto.
# - audio on|off: so o mpv troca ao vivo (trilha aid auto/no); o gslapper nao tem
#   comando de audio, quem usa reinicia o player.
# Som so no player da 1a tela (com 2 monitores nao toca duplicado).
# Uso: wall-video.sh <gslapper|mpvpaper> <arquivo> <som:0|1> <saida>...
#      wall-video.sh pause|resume
#      wall-video.sh audio on|off
sockdir=${XDG_RUNTIME_DIR:?}

send() { printf '%s\n' "$2" | socat - "UNIX-CONNECT:$1" >/dev/null 2>&1; }

case ${1:-} in
pause | resume)
  v=false
  [ "$1" = pause ] && v=true
  for s in "$sockdir"/qs-wallvideo-*.sock; do
    [ -S "$s" ] || continue
    case ${s##*/} in
    qs-wallvideo-mpvpaper-*) send "$s" "{\"command\":[\"set_property\",\"pause\",$v]}" ;;
    *) send "$s" "$1" ;;
    esac
  done
  exit 0
  ;;
audio)
  aid=no
  [ "${2:-}" = on ] && aid=auto
  # so o da 1a tela (.main: o que nasce com som)
  for s in "$sockdir"/qs-wallvideo-mpvpaper-*.main.sock; do
    [ -S "$s" ] && send "$s" "{\"command\":[\"set_property\",\"aid\",\"$aid\"]}"
  done
  exit 0
  ;;
esac

player=${1:?player}
file=${2:?arquivo}
sound=${3:?som 0|1}
shift 3
case $player in
gslapper) opts="loop fill" ;;                         # fill = cobre a tela, corta o excesso
mpvpaper) opts="loop panscan=1.0 hwdec=auto-safe" ;;  # panscan=1.0 = o mesmo no mpv
*)
  echo "player desconhecido: $player" >&2
  exit 1
  ;;
esac

# os sockets desta instancia nao ficam p/ tras (o pause tentaria falar com player morto)
socks=""
trap 'for s in $socks; do rm -f "$s"; done' EXIT
trap 'exit 0' TERM INT HUP

# camada bottom: sempre acima da imagem do awww (background), mesmo se o daemon reiniciar
first=1
for out; do
  o="no-audio $opts"
  if [ "$first" = 1 ]; then
    sock="$sockdir/qs-wallvideo-$player-$out.main.sock"   # o do som (audio on|off)
    [ "$sound" = 1 ] && o=$opts
    first=0
  else
    sock="$sockdir/qs-wallvideo-$player-$out.sock"
  fi
  socks="$socks $sock"
  rm -f "$sock"
  if [ "$player" = gslapper ]; then
    gslapper -I "$sock" -l bottom -o "$o" "$out" "$file" &
  else
    mpvpaper -l bottom -o "$o input-ipc-server=$sock" "$out" "$file" &
  fi
done
wait
