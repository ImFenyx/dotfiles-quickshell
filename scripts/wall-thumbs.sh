#!/bin/sh
# Seletor de wallpaper: lista as imagens e os videos de <pasta> (sem subpastas) e
# imprime "caminho<TAB>miniatura<TAB>image|video". Miniatura 320x180 (corte
# central) gerada 1x por arquivo+mtime em ~/.cache/quickshell/wallthumbs (video:
# um quadro de 1s pelo ffmpeg); as de arquivos que sumiram sao apagadas.
dir=${1:?uso: wall-thumbs.sh <pasta>}
cache="${XDG_CACHE_HOME:-$HOME/.cache}/quickshell/wallthumbs"
mkdir -p "$cache"

# um stat so p/ a pasta toda: "mtime caminho"
stat -c '%Y %n' "$dir"/* 2>/dev/null | {
  keep=" "
  while read -r mtime f; do
    case ${f##*.} in
    jpg | jpeg | png | webp | gif | bmp | JPG | JPEG | PNG | WEBP | GIF | BMP) kind=image ;;
    mp4 | webm | mkv | mov | avi | MP4 | WEBM | MKV | MOV | AVI) kind=video ;;
    *) continue ;;
    esac
    t="$cache/${f##*/}.$mtime.jpg"
    if [ ! -s "$t" ]; then
      if [ "$kind" = image ]; then
        # [0] = 1o quadro (gif)
        magick "${f}[0]" -thumbnail '320x180^' -gravity center -extent 320x180 -quality 85 "jpg:$t" 2>/dev/null
      else
        ffmpeg -loglevel error -ss 1 -i "$f" -frames:v 1 -vf 'scale=320:180:force_original_aspect_ratio=increase,crop=320:180' -q:v 4 -y "$t" </dev/null
      fi
      [ -s "$t" ] || {
        rm -f "$t"
        continue
      }
    fi
    keep="$keep${t##*/} "
    printf '%s\t%s\t%s\n' "$f" "$t" "$kind"
  done
  for t in "$cache"/*; do
    [ -e "$t" ] || continue
    case $keep in *" ${t##*/} "*) ;; *) rm -f "$t" ;; esac
  done
}
