# 下一 Session 快速入口

> 3 分钟了解当前状态，然后读主文档

## 当前状态（一句话）

**第一组双 SUCCESS（有效）；第二组双样本污染已排除归档；用户已拍板（清场完成、同窗串行、新开槽 Native-03/OMAC-03）。任务：重跑 Native-03 + OMAC-03 → 做 S05 分析 → B3 收口。**

**首选阅读**: `Evidence/B3/交接信-S04-第二组重跑.md`（重跑配方：串行时序/证据暂存仓库外/canary 告警/踩坑清单）。
**用户已拍板 3 点（已登记 protocol 修订，无需再问）**：① 同窗串行；② 新槽 Native-03/OMAC-03；③ 清场已执行（samples 移出仓库 + push 远端 d94df09，已验证远端干净）。
**归档路径**（samples 已不在仓库）：`/d/agentlearn/learnezvibe-b3-archive-20260820/samples/`（sample-checklist.md 模板 / 污染事件原文 incident-pair-02-contamination.md / 第一组证据 / 污染样本证据都在这里）

## 第一组结论（硬核版，有效样本）

- **Native-01**: leader @mention 委派 collect→write→review。成员 in 123141/out 10313/cr 940288；含 leader in 226231/out 19642/cr 2666240。步骤 78，墙钟 10m（成员）/13m（含 leader）。
- **OMAC-01**: 三节点 DAG 收敛 rc=0。in 175384/out 29605/cr 2992896。步骤 91，墙钟 23m08s。review 有 review-consistency.py 独立核验。
- **一句话**: OMAC 用更多 token/时间换确定性与可验证性；Native 更快更省但 review 声明式、依赖 leader 临场可靠性。

## 重跑铁律（防二次污染）

1. **同窗串行**：Native-03 全部三节点收敛后，才建 OMAC-03（同角色 agent 严禁并发）。
2. **证据暂存仓库外**：两臂 run 期间证据写 `/d/agentlearn/learnezvibe-b3-archive-20260820/tmp-collect/`，**两臂都收敛 + canary 全绿后**才移入 `Evidence/B3/samples/`。
3. **canary 全绿才算有效**：Native 成员 run 无 OMAC 引用、OMAC write/review 无 samples/deliverables 引用、产物 hash 全新（≠ 14caa249/5245b7f6/c87bb483/003dc995/0f1e46f4）、三节点同 agent 无重叠。任一告警→升级用户。

## 环境坑（已修，别踩）

- **codex 余额耗尽 → 会话空转/截断**（表现像并发问题，实为欠费）：首个 run 无 usage 立即停，查余额。
- **OMAC agent 引擎配置**：weekly agents 已设 OMAC_ENGINE/WORKSPACE_ID/PROJECT_ID（问题 25 修复，别删）。
- **dag check 评审轮询挂死**（问题 24）：后台驱动一律 dag tick + sleep。

## 已定案决策（沿用）

- 3 个 weekly agent 两臂共用（冻结配置不改）；周报 squad 6e94e57b；fixtures-v1 冻结不改。
- 故障/污染 run 不计入计量，单列披露；frozen-input.json 不附根 issue（collect 自算哈希合规）。
- WEEK-15 reviewer 意见不采纳；B4 暂不写 plan；content 模式保留。

## 纪律（血泪换的）

- 平台/agent 命令一律 timeout 或后台；没读过源码先读源码。
- 重跑期间不 commit 任何样本证据进仓库（OMAC 引擎会自动 manifest sync，属正常）。

---

**立即开始**: 读 `交接信-S04-第二组重跑.md` → Native-03（建 issue→指派→监控收敛）→ canary1 → OMAC-03（建 issue→manifest→driver→CONVERGED）→ canary2 → 证据入库 → S05。
