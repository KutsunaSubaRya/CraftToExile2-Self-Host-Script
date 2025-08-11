#!/usr/bin/env bash
set -Eeuo pipefail

BASE="$HOME/CTE2"
LOGDIR="$BASE/logs"
ARCHDIR="$BASE/backuplog"
mkdir -p "$LOGDIR" "$ARCHDIR"
cd "$LOGDIR" || exit 0
shopt -s nullglob

TS=$(date +%Y%m%d-%H%M%S)
ARCHZIP="$ARCHDIR/logs-$TS.zip"
ARCHTAR="$ARCHDIR/logs-$TS.tar.gz"

mapfile -d '' FILES < <(find . -maxdepth 1 -type f -mmin +5 -print0)

for i in "${!FILES[@]}"; do FILES[$i]="${FILES[$i]#./}"; done

ACTIVE_CONSOLE=$(ls -1t latest-*.log 2>/dev/null | head -n 1 || true)   
TODAY_SPARK="spark-$(date +%Y%m%d).log"                                 
filtered=()
for f in "${FILES[@]}"; do
  [[ "$f" == "$ACTIVE_CONSOLE" ]] && continue
  [[ "$f" == "$TODAY_SPARK"     ]] && continue
  [[ "$f" == "latest.log"       ]] && continue
  filtered+=("$f")
done

((${#filtered[@]})) || exit 0

if command -v zip >/dev/null 2>&1; then
  zip -q -9 -m "$ARCHZIP" "${filtered[@]}"
else
  tar -czf "$ARCHTAR" -- "${filtered[@]}"
  rm -f -- "${filtered[@]}"
fi

KEEP_ARCH=14
mapfile -t ARCHS < <(ls -1t "$ARCHDIR"/logs-* 2>/dev/null || true)
if ((${#ARCHS[@]} > KEEP_ARCH)); then
  for old in "${ARCHS[@]:$KEEP_ARCH}"; do rm -f -- "$old"; done
fi
