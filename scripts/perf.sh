#!/bin/sh
# Mede o consumo do Quickshell em idle (ou durante o uso): CPU, acordadas,
# processos filhos, RAM (RSS/PSS) e memoria de GPU. Compare antes/depois de
# uma mudanca (ou de uma variavel de ambiente, ver README > Desempenho).
#
# Uso:  scripts/perf.sh [segundos=30] [rotulo]
#   PID=1234 scripts/perf.sh      mede outro processo
# Cada execucao tambem grava uma linha em ~/.cache/quickshell/perf.csv.
#
# Notas:
#  - "filhos distintos" amostra /proc a cada 50ms: processos que vivem menos que
#    isso nao aparecem, entao e um MINIMO (serve para comparar, nao para auditar).
#  - memoria de GPU vem de /proc/PID/fdinfo (drm-*); depende do driver/kernel.

DUR=${1:-30}
LABEL=${2:-$(git -C "$(dirname "$0")/.." rev-parse --short HEAD 2>/dev/null || echo sem-rotulo)}
PID=${PID:-$(pgrep -x quickshell | head -n1)}
[ -n "$PID" ] && [ -d "/proc/$PID" ] || { echo "quickshell nao encontrado (use PID=...)" >&2; exit 1; }
HZ=$(getconf CLK_TCK)

cpu_ticks() { awk '{print $14+$15}' "/proc/$PID/stat"; }                       # utime+stime
ctx_switches() { cat /proc/$PID/task/*/status 2>/dev/null | awk '/ctxt_switches/ {s+=$2} END {print s+0}'; }
mem_kb() { awk -v k="$1" '$1==k":" {print $2}' "/proc/$PID/$2"; }

gpu_kb() {
  # soma drm-memory-* / drm-resident-* / drm-total-* (kB) de fds unicos (drm-client-id)
  for f in /proc/$PID/fdinfo/*; do
    grep -q '^drm-driver' "$f" 2>/dev/null && cat "$f"
  done 2>/dev/null | awk '
    /^drm-client-id/ { id=$2 }
    /^drm-(memory|resident|total)-[a-z0-9]+:/ && !seen[id SUBSEP $1]++ {
      v=$2; u=$3; if (u=="MiB") v*=1024; else if (u=="GiB") v*=1048576; else if (u=="B") v/=1024; s+=v }
    END { printf "%d", s }'
}

echo "== quickshell pid=$PID  rotulo=$LABEL  janela=${DUR}s =="
THREADS=$(ls /proc/$PID/task | wc -l)
RSS=$(mem_kb VmRSS status); PSS=$(mem_kb Pss smaps_rollup); SWAP=$(mem_kb VmSwap status)
GPU=$(gpu_kb); NFD=$(ls /proc/$PID/fd | wc -l)

T0=$(cpu_ticks); C0=$(ctx_switches); START=$(date +%s)
SEEN=/tmp/qs-perf-children.$$; : > "$SEEN"
END=$((START + DUR))
while [ "$(date +%s)" -lt "$END" ]; do
  cat /proc/$PID/task/*/children 2>/dev/null | tr ' ' '\n' | grep -v '^$' >> "$SEEN"
  sleep 0.05
done
T1=$(cpu_ticks); C1=$(ctx_switches)
KIDS=$(sort -u "$SEEN" | wc -l); rm -f "$SEEN"

CPU=$(awk -v a="$T0" -v b="$T1" -v hz="$HZ" -v d="$DUR" 'BEGIN {printf "%.2f", (b-a)/hz/d*100}')
WAKE=$(awk -v a="$C0" -v b="$C1" -v d="$DUR" 'BEGIN {printf "%.1f", (b-a)/d}')
KIDS_H=$(awk -v k="$KIDS" -v d="$DUR" 'BEGIN {printf "%.0f", k/d*3600}')

printf '%-26s %s\n' "CPU medio:"            "${CPU}% de 1 nucleo"
printf '%-26s %s\n' "acordadas (ctx sw):"   "${WAKE}/s"
printf '%-26s %s (~%s/hora)\n' "filhos distintos (min.):" "$KIDS" "$KIDS_H"
printf '%-26s %s MB   (PSS %s MB, swap %s MB)\n' "RAM RSS:" "$((RSS/1024))" "$((${PSS:-0}/1024))" "$((${SWAP:-0}/1024))"
printf '%-26s %s\n' "memoria GPU (drm fdinfo):" "$([ "${GPU:-0}" -gt 0 ] && echo "$((GPU/1024)) MB" || echo "n/d neste driver")"
printf '%-26s %s threads, %s fds\n' "recursos:" "$THREADS" "$NFD"

CSV="${XDG_CACHE_HOME:-$HOME/.cache}/quickshell/perf.csv"; mkdir -p "$(dirname "$CSV")"
[ -f "$CSV" ] || echo "data,rotulo,janela_s,cpu_pct,acordadas_s,filhos,rss_mb,pss_mb,gpu_mb,threads" > "$CSV"
echo "$(date +%F_%T),$LABEL,$DUR,$CPU,$WAKE,$KIDS,$((RSS/1024)),$((${PSS:-0}/1024)),$((${GPU:-0}/1024)),$THREADS" >> "$CSV"
echo "(gravado em $CSV)"
