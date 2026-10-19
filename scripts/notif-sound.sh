#!/bin/sh
# Toca o som de uma notificacao.
# Uso: notif-sound.sh <arquivo | file://arquivo | nome-do-som>
# Nome = freedesktop sound naming spec (ex.: message-new-instant), procurado no
# tema de sons (SOUND_THEME, depois freedesktop e ocean). Player: pw-play,
# paplay, canberra-gtk-play ou ffplay, o primeiro que existir.

arg=$1
[ -n "$arg" ] || exit 0

case $arg in
file://*) arg=${arg#file://} ;;
esac

have() { command -v "$1" >/dev/null 2>&1; }

play() {
  if have pw-play; then
    exec pw-play "$1"
  elif have paplay; then
    exec paplay "$1"
  elif have ffplay; then
    exec ffplay -nodisp -autoexit -loglevel quiet "$1"
  fi
  exit 0
}

case $arg in
/*)
  [ -r "$arg" ] && play "$arg"
  exit 0
  ;;
esac

data_dirs="${XDG_DATA_HOME:-$HOME/.local/share}:${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
old_ifs=$IFS
IFS=:
for dir in $data_dirs; do
  for theme in "${SOUND_THEME:-freedesktop}" freedesktop ocean; do
    for ext in oga ogg wav; do
      f="$dir/sounds/$theme/stereo/$arg.$ext"
      if [ -r "$f" ]; then
        IFS=$old_ifs
        play "$f"
      fi
    done
  done
done
IFS=$old_ifs

# nao achou no tema: deixa o libcanberra tentar (ele conhece outros temas)
have canberra-gtk-play && exec canberra-gtk-play -i "$arg"
exit 0
