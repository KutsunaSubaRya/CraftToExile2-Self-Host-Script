#!/usr/bin/env bash
set -u
cd "$(dirname "$0")"

# ---- single-instance lock ----
if command -v flock >/dev/null 2>&1; then
  exec 9>/tmp/mc-restart.lock
  flock -n 9 || exit 0
fi

RHOST=127.0.0.1
RPORT=25575
# TODO: replace with your own password
RPASS='your_password'
# TODO: replace with your own mcrcon path
MCRCON="path/to/mcrcon"

# TODO: replace with your own tag and other custom settings
TAG="[Your Tag]"
TAG_COLOR="gold"
SOUND="minecraft:entity.experience_orb.pickup"
SRC="player"
VOL=1
PITCH=1
MINVOL=0.6

announce() {
  local msg="$*"
  "$MCRCON" -H "$RHOST" -P "$RPORT" -p "$RPASS" -t <<EOF >/dev/null 2>&1
tellraw @a [{"text":"$TAG ","color":"$TAG_COLOR","bold":true},{"text":"$msg","color":"white"}]
title @a actionbar {"text":"$msg","color":"yellow"}
execute as @a at @s run playsound $SOUND $SRC @s ~ ~ ~ $VOL $PITCH $MINVOL
EOF
}
rc(){ "$MCRCON" -H "$RHOST" -P "$RPORT" -p "$RPASS" "$@" >/dev/null 2>&1 || true; }

"$MCRCON" -H "$RHOST" -P "$RPORT" -p "$RPASS" "list" >/dev/null 2>&1 || exit 0

MODE=${1:-}

usage() {
  cat <<'EOF'
Usage: ./mc-restart.sh [--now|--fast|--help]
  (no flag)  5 minutes countdown with notices (5m/4m/3m/2m/60s + 10..1)
  --fast     30 seconds quick test (30s, 10s + 10..1)
  --now      15 seconds short countdown (15s, 10s, 5s + 10..1)
  --shutdown stop server immediately
  --help     show this help and exit

Notes:
- Single-instance lock prevents overlap with cron or another manual run.
- After restart, cron schedule continues as usual.
EOF
}

case "$MODE" in
  "" )
    TOTAL=300; marks=(300 240 180 120 60) ;;   # 5m/4m/3m/2m/60s
  --fast|fast )
    TOTAL=30;  marks=(30 10) ;;                # 30s & 10s
  --now|now )
    TOTAL=15;  marks=(15 10 5) ;;              # 15s/10s/5s
  -h|--help|help )
    usage; exit 0 ;;
  --shutdown|shutdown )
    # save isShutdown bool
    TOTAL=5
    isShutdown=true; marks=(5);;
  * )
    echo "[mc-restart] Unknown option: $MODE"
    usage; exit 1 ;;
esac

if [ "$isShutdown" = true ]; then
  last=$TOTAL
  for t in "${marks[@]}"; do
    sleep $(( last - t ))
    announce "Server will shutdown in ${t} seconds."
    last=$t
  done
  rc "save-all flush"
  sleep 2
  rc "stop"
  exit 0
fi


last=$TOTAL
for t in "${marks[@]}"; do
  sleep $(( last - t ))
  if [ "$t" -ge 60 ]; then
    announce "Server will restart in $(( t/60 )) minutes."
  else
    announce "Server will restart in ${t} seconds."
  fi
  last=$t
done

start=$(( last > 10 ? 10 : last ))
sleep $(( last - start ))
for (( s=start; s>=1; s-- )); do
  announce "Restart in ${s}s ..."
  sleep 1
done

rc "save-all flush"
sleep 2
rc "stop"

sleep 15
bash ./start.sh
