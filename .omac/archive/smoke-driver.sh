#!/bin/bash
# S03 全新 smoke 驱动: 有界 tick 循环,零人工值守
# 退出条件: dag tick 返回 0 (收敛) / 20 (需决策) / 墙钟超时 75 分钟
cd /d/agentlearn/learnezvibe || exit 99
LOG=.omac/smoke-run.log
echo "=== smoke driver start $(date -Iseconds) ===" >> "$LOG"
deadline=$((SECONDS + 4500))
while [ $SECONDS -lt $deadline ]; do
  omac dag tick .omac/weekly-smoke.yaml >> "$LOG" 2>&1
  rc=$?
  echo "=== tick rc=$rc at $(date -Iseconds) ===" >> "$LOG"
  if [ $rc -eq 0 ]; then echo "RESULT: CONVERGED" >> "$LOG"; break; fi
  if [ $rc -eq 20 ]; then echo "RESULT: NEEDS_DECISION" >> "$LOG"; break; fi
  if [ $rc -ne 10 ]; then
    echo "WARN: unexpected rc=$rc, retrying after delay" >> "$LOG"
  fi
  sleep 150
done
if [ $SECONDS -ge 4500 ]; then echo "RESULT: TIMEOUT_75MIN" >> "$LOG"; fi
echo "=== smoke driver end $(date -Iseconds) ===" >> "$LOG"
