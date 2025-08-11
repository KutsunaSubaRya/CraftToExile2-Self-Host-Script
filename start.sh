#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p logs

LOG="logs/latest-$(date +%Y%m%d-%H%M).log"

if screen -list | grep -q "\bmc\b"; then
  echo "[WARN] screen 'mc' already exists, skipping."
  exit 0
fi

# start with readable log
screen -S mc -dm bash -lc 'stdbuf -oL -eL ./run.sh nogui 2>&1 | tee -a '"$LOG"
echo "Server started in screen 'mc'. Log => $LOG"
