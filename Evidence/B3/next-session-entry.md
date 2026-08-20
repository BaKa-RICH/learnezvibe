# 下一 Session 快速入口

> 3 分钟了解当前状态，然后读主文档

## 当前状态（一句话）

**第一组双 SUCCESS（有效）；第二组（Native-02 + OMAC-02）双样本被污染（两条通道：同 agent 并发串扰 + 仓库残留第一组证据），已归档证据。任务：按"清场 + 同窗串行"缓解方案重跑第二组 → 再做 S05 分析 → B3 收口。**

**首选阅读**: `Evidence/B3/交接信-S04-第二组重跑.md` -- 重跑执行配方（清场步骤/串行时序/canary 告警/踩坑清单/需用户确认的 3 点）。
**污染事件原文**: `Evidence/B3/samples/incident-pair-02-contamination.md`（已随清场归档，见重跑交接信第四节路径）。

## 第一组结论（硬核版，有效样本）

- **Native-01**: leader @mention 委派 collect→write→review，根 issue done。成员 in 123141/out 10313/cr 940288；含 leader in 226231/out 19642/cr 2666240。步骤 78，墙钟 10m（成员）/13m（含 leader）。
- **OMAC-01**: 三节点 DAG 收敛 rc=0，每节点独立新工单。in 175384/out 29605/cr 2992896。步骤 91，墙钟 23m08s。review 有 review-consistency.py 独立核验。
- **一句话**: OMAC 用更多 token/时间换确定性与可验证性；Native 更快更省但 review 声明式、依赖 leader 临场可靠性。

## 第二组污染（教训，重跑必须堵死）

1. **同 agent 并发串扰（Native-02 停滞）**：weekly-collect agent 同时被两臂派发，成员 run 读到 OMAC run-messages 后拒绝产出。→ 重跑改为**同窗串行**（先跑完 Native 再跑 OMAC）。
2. **仓库残留（OMAC-02 write/review 照抄 Native-01）**：`Evidence/B3/samples/Native-01/deliverables/` 已在 **GitHub 远端 main**，agents 克隆即搜到。→ 重跑前**整个 samples 目录移出 repo + push 远端**（清场）。

## 已定案决策（沿用）

- 3 个 weekly agent 两臂共用（冻结配置，不改）；周报 squad 6e94e57b；fixtures-v1 冻结不改。
- codex 故障 run / 污染 run 不计入计量，单列披露（用户拍板口径）。
- frozen-input.json 不附根 issue；collect 自算哈希匹配即合规。
- WEEK-15 reviewer 意见不采纳；B4 暂不写 plan；content 模式保留。

## 环境坑（已修，别踩）

- **codex 余额耗尽 → 会话空转/截断**（表现像并发问题，实为欠费）：首个 run 无 usage 立即停，查余额。
- **OMAC agent 引擎配置**：weekly agents 已设 OMAC_ENGINE/WORKSPACE_ID/PROJECT_ID（问题 25 修复，别删）。
- **dag check 评审轮询挂死**（问题 24）：后台驱动一律 dag tick + sleep。

## 纪律（血泪换的）

- 平台/agent 命令一律 timeout 或后台；没读过源码先读源码。
- 污染告警 canary（重跑交接信第五节）全绿才算有效样本；任一告警 → 升级用户，不自行处理。

---

**立即开始**: 读 `交接信-S04-第二组重跑.md` → 用户确认 3 点（执行方式修订/槽位命名/清场）→ 清场 → 串行重跑 → canary → S05。
