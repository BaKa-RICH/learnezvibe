#!/bin/bash
# S04 有界 tick 驱动: 零人工值守, 防卡死
# 用法: bash .omac/s04-driver.sh <manifest> <log>
# 退出条件: dag tick 返回 0(收敛) / 20(需决策) / 墙钟超时 75 分钟
# 纪律: 一律用 dag tick 驱动; 不用 dag check(评审轮询会无限挂死)
cd /d/agentlearn/learnezvibe || exit 99
MANIFEST="${1:?manifest path required}"
LOG="${2:-.omac/s04-driver.log}"
echo "=== s04 driver start $(date -Iseconds) manifest=$MANIFEST ===" >> "$LOG"
deadline=$((SECONDS + 4500))
while [ $SECONDS -lt $deadline ]; do
  omac dag tick "$MANIFEST" >> "$LOG" 2>&1
  rc=$?
  echo "=== tick rc=$rc at $(date -Iseconds) ===" >> "$LOG"
  if [ $rc -eq 0 ]; then echo "RESULT: CONVERGED" >> "$LOG"; break; fi
  if [ $rc -eq 20 ]; then echo "RESULT: NEEDS_DECISION" >> "$LOG"; break; fi
  if [ $rc -ne 10 ]; then echo "WARN: unexpected rc=$rc, retrying after delay" >> "$LOG"; fi
  sleep 150
done
if [ $SECONDS -ge 4500 ]; then echo "RESULT: TIMEOUT_75MIN" >> "$LOG"; fi
echo "=== s04 driver end $(date -Iseconds) ===" >> "$LOG"
