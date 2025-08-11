#!/usr/bin/env bash
set -u
cd "$(dirname "$0")"

RHOST=127.0.0.1
RPORT=25575
# TODO: replace with your own password
RPASS='your_password'
MCRCON="/usr/local/bin/mcrcon"

mkdir -p logs
OUT="logs/spark-$(date +%Y%m%d).log"

# 找出目前的主控台 log（start.sh 生成的最新檔）
CURLOG=$(ls -1t logs/latest-*.log 2>/dev/null | head -n 1 || true)
[ -f "$CURLOG" ] || { echo "--- $(date -Iseconds) (no current console log) ---" >> "$OUT"; exit 0; }

# RCON 就緒檢查（最多等 60 秒）
check() { "$MCRCON" -H "$RHOST" -P "$RPORT" -p "$RPASS" "list" >/dev/null 2>&1; }
ready=0; for i in {1..6}; do check && ready=1 && break; sleep 10; done
[ $ready -eq 1 ] || { echo "--- $(date -Iseconds) (rcon not ready) ---" >> "$OUT"; exit 0; }

# ===== 1) 取 snapshot：玩家數、server.properties、JVM 旗標 =====
LIST_OUT=$("$MCRCON" -H "$RHOST" -P "$RPORT" -p "$RPASS" "list" 2>/dev/null || true)
ONLINE=$(echo "$LIST_OUT" | grep -oE 'There are [0-9]+' | awk '{print $3}')
ONLINE=${ONLINE:-0}

# 從 server.properties 讀目前配置（若不存在就顯示 ?）
PROP="server.properties"
VIEW=$(grep -E '^view-distance=' "$PROP" 2>/dev/null | tail -n1 | cut -d= -f2)
SIMU=$(grep -E '^simulation-distance=' "$PROP" 2>/dev/null | tail -n1 | cut -d= -f2)
MAXP=$(grep -E '^max-players=' "$PROP" 2>/dev/null | tail -n1 | cut -d= -f2)

# JVM Xms/Xmx（優先從 JVM 命令列，否則用 VM.flags 的位元組換算）
XMS="?"
XMX="?"
if command -v jcmd >/dev/null 2>&1; then
  PID=$(jcmd 2>/dev/null | awk '/server\.jar|minecraft|forge|fabric/ {print $1; exit}')
  if [ -n "${PID:-}" ]; then
    CMDLINE=$(jcmd "$PID" VM.command_line 2>/dev/null || true)
    XMS=$(echo "$CMDLINE" | tr ' ' '\n' | grep -E '^-Xms' | tail -n1 | sed 's/^-Xms//')
    XMX=$(echo "$CMDLINE" | tr ' ' '\n' | grep -E '^-Xmx' | tail -n1 | sed 's/^-Xmx//')

    if [ -z "$XMX" ] || [ -z "$XMS" ]; then
      FLAGS=$(jcmd "$PID" VM.flags 2>/dev/null || true)
      MAXB=$(echo "$FLAGS" | tr ' ' '\n' | grep -oE 'MaxHeapSize=[0-9]+' | sed 's/.*=//')
      INITB=$(echo "$FLAGS" | tr ' ' '\n' | grep -oE 'InitialHeapSize=[0-9]+' | sed 's/.*=//')
      # 轉成 GiB（1,073,741,824 bytes = 1 GiB）
      [ -n "$MAXB" ] && XMX=$(awk -v b="$MAXB" 'BEGIN{printf "%.1fG", b/1073741824}')
      [ -n "$INITB" ] && XMS=$(awk -v b="$INITB" 'BEGIN{printf "%.1fG", b/1073741824}')
    fi
  fi
fi

# ===== 2) 寫 snapshot 標頭到 spark-*.log =====
{
  echo "=== $(date -Iseconds) ==="
  echo "players: ${ONLINE}/${MAXP:-?}"
  echo "view-distance: ${VIEW:-?}, simulation-distance: ${SIMU:-?}"
  echo "jvm: Xms=${XMS}, Xmx=${XMX}"
} >> "$OUT"

# ===== 3) 記下主控台位移 → 送 spark 指令（同一連線）→ 抽新增段落 =====
START_OFF=$(wc -c < "$CURLOG" 2>/dev/null || echo 0)

"$MCRCON" -H "$RHOST" -P "$RPORT" -p "$RPASS" -t <<'EOF' >/dev/null 2>&1
/spark gc
/spark health --brief
EOF

# 視負載調整等待時間，確保輸出完整寫入主控台
sleep 4

END_OFF=$(wc -c < "$CURLOG" 2>/dev/null || echo 0)
if [ "$END_OFF" -gt "$START_OFF" ]; then
  dd if="$CURLOG" bs=1 skip="$START_OFF" count=$((END_OFF-START_OFF)) status=none >> "$OUT"
fi

echo "--- $(date -Iseconds) ---" >> "$OUT"
