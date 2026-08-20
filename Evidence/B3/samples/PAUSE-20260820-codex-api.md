# S04 暂停记录（2026-08-20 ~16:52）

## 原因
**codex 账号余额耗尽**（用户确认），主动暂停，已充值修复（~16:55）。

> 早期 AI 猜测“并发压垮运行时”被证伪：所有截断均为 codex 账号无余额导致的连接失败。**保持配对并发，不回退串行。**

## 环境证据（daemon 日志）
- 16:20:41 spawn 后，codex 会话出现 `Reconnecting... 1/5 → 4/5` 连接丢失循环，以 `tools=0 / models_with_usage=0` 完成（task d8817c19）。
- 对照：smoke 时代（本地 13:38-14:03 = UTC 05:38-06:03）单 arm 会话全部正常（tools=17/27/27）。
- 判定：本次窗口所有 agent 会话（Native leader + OMAC collect）空会话/截断的根因是 **codex 账号余额耗尽**（连接被拒），**非 OMAC 代码、非 agent 配置、非协议、非并发问题**。已由用户充值修复。

## 已停止的组件
- OMAC driver（PID 3024）已 kill，最后 tick 16:51:48。之后不再有派发。
- Native 侧 leader 已 idle（无活动 run）。
- 残留 in-flight：OMAC collect run `cf600ccc`（08:51:50 派发，driver 停止时在跑；会自行完成/截断，不会阻塞恢复）。

## 两 arm 当前状态（暂停时）
### Native-01（WEEK-19 a2470a6f）
- runs: d8817c19(空会话,0 usage), eb36d4e3(3msgs,有 usage,读委派指南后截断)
- 根 issue todo，无子任务，无产物，附件完好（4 fixtures）
- 触发恢复历史：首派发空会话后 unassign→re-assign 唤醒（详见 observations.json）

### OMAC-01（根 issue d7694427，manifest .omac/s04-omac-01.yaml）
- collect 4 runs 均未交付 weekly-data.md（d6de631e/def42bc3 空会话，a82ca56e 截断，cf600ccc in-flight）
- manifest 停于 collect in_progress；write/review todo
- 派发出的 [DAG:collect] issue 0ac256e4

## 恢复点（2026-08-20 ~16:55 执行）
1. 重启 OMAC driver（后台）：`bash .omac/s04-driver.sh .omac/s04-omac-01.yaml .omac/s04-omac-01.log`
2. Native-01：重触发（unassign→re-assign 周报 squad）让 leader 重新拆解
3. 恢复后确认会话能产生真实多轮消息（不再 0-3 msgs 截断）

## 结论
- 根因 = codex 账号余额耗尽；已修复。**配对并发维持不变**，无需 protocol 修订。
