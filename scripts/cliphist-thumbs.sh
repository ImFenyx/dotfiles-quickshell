#!/bin/sh
# Miniaturas da aba de imagens do clipboard (launcher "#", Alt+i): decodifica
# cada imagem do cliphist p/ o cache UMA vez por id e imprime "id<TAB>arquivo"
# (mais nova primeiro, entao as visiveis chegam antes). Apaga do cache as que
# sairam do historico. O cache tem o mesmo conteudo do db do cliphist: so o dono le.
umask 077
dir="${XDG_CACHE_HOME:-$HOME/.cache}/quickshell/cliphist"
mkdir -p "$dir" && chmod 700 "$dir"
tab=$(printf '\t')
# miniatura de verdade (o db guarda as imagens inteiras: ~200MB); sem magick, a imagem toda.
# Fundo surface0 no lugar da transparencia (JPEG nao tem alfa).
if command -v magick >/dev/null 2>&1; then
  ext=jpg
  thumb() { cliphist decode "$1" | magick - -thumbnail '360x270>' -background '#313244' -flatten -quality 85 "jpg:$2"; }
else
  ext=""   # = formato do preview
  thumb() { cliphist decode "$1" > "$2"; }
fi
set -f    # o preview tem "[[": sem glob no `set --`
cliphist list | {
  keep=" "
  while IFS=$tab read -r id preview; do
    # "[[ binary data 492 KiB png 747x528 ]]" -> $6 = png
    case $preview in "[[ binary data "*" ]]") ;; *) continue ;; esac
    # shellcheck disable=SC2086 # split por espaco e o objetivo
    set -- $preview
    f="$dir/$id.${ext:-$6}"
    [ -s "$f" ] || thumb "$id" "$f" 2>/dev/null || { rm -f "$f"; continue; }
    keep="$keep$id "
    printf '%s\t%s\n' "$id" "$f"
  done
  set +f
  for f in "$dir"/*; do
    [ -e "$f" ] || continue
    id=${f##*/}
    case $keep in *" ${id%.*} "*) ;; *) rm -f "$f" ;; esac
  done
}
