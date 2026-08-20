# 下一 Session 快速入口

> 3 分钟了解当前状态，然后读主文档

## 当前状态（一句话）

**S04 第一组（Native-01 + OMAC-01）已完成，双 SUCCESS（2026-08-20）。第二组（Native-02 + OMAC-02）待开跑，跑完做 S05 分析 → B3 收口。**

**首选阅读**: `Evidence/B3/交接信-S04-第二组.md` -- 下个 session 的第一封信（第一组怎么跑通的/第二组照抄步骤/避坑/口径决定/S05 要点，一页讲完）。本文件是 3 分钟速查索引。

## 第一组结论（硬核版）

完整报告: `Evidence/B3/samples/pair-01-complete.md`；原始证据: `samples/Native-01/` + `samples/OMAC-01/`。
- **Native-01**: leader @mention 委派 collect→write→review（同一工单评论区接力），根 issue done。成员三节点 in 123141/out 10313/cr 940288；含 leader 编排开销 in 226231/out 19642/cr 2666240。步骤 78（成员 39 + leader 38），墙钟 10m（成员）/13m（含 leader）。
- **OMAC-01**: 固定三节点 DAG 收敛（rc=0），每节点独立新工单。in 175384/out 29605/cr 2992896。步骤 91，墙钟 23m08s。review 有 review-consistency.py 独立核验。
- **一句话**: OMAC 用更多 token/时间换确定性与可验证性；Native 更快更省但 review 是声明式、且依赖 leader 临场可靠性。

## 第二组开跑（照抄已验证 recipe，详见交接信）

1. **公共前置已就绪**：fixtures-v1（4 冻结文件）、`.omac/s04/root-issue-body.md`（共同正文）、weekly agents 已设 OMAC env。
2. **Native-02**: 建根 issue（正文+4 附件）→ 指派周报 squad → leader 自动评论区委派。
3. **OMAC-02**: 建根 issue → 复制 `.omac/s04-omac-01.yaml` 为 `-02`（改 title/source_issues/清状态，collect objective 保留模板句）→ `nohup bash .omac/s04-driver.sh .omac/s04-omac-02.yaml .omac/s04-omac-02.log &`。
4. **采集**: 每样本 root-issue/runs/usage/run-messages/deliverables/summary 存 `samples/<id>/`；run-messages 格式已确认可用。**逐样本对照 `samples/sample-checklist.md`（A1-A5 + 指标口径模板）勾选验收**。

## 已定案决策（不再重议）

- **配对并发**（同窗一 Native + 一 OMAC；禁同 arm 并发、禁四样本全并发）。
- **codex 故障期 run 不计入计量**（用户拍板，2026-08-20；基础设施故障单列披露，计量用成功 run）。
- **frozen-input.json 不附根 issue**（collect 自算哈希匹配即合规，第一组实测通过）。
- **WEEK-15 reviewer 意见不采纳**；**B4 暂不写 plan**；**不降级 PR，content 保留**。

## 环境坑（已修，别踩）

- **codex 账号余额耗尽 → 所有会话空转/截断**（表现像并发问题，实为欠费；用户充值修复）。
- **OMAC agent 找不到引擎配置 → `omac work show` 报 engine missing**（排障手册问题 25）：已给 weekly agents 设 OMAC_ENGINE/WORKSPACE_ID/PROJECT_ID env 解决。

## 纪律（血泪换的）

- 后台驱动用 `dag tick` + sleep，**不用 dag check**（评审轮询无限挂死，排障手册问题 24）。
- 平台/agent 命令一律 timeout 或后台；没读过源码先读源码。

---

**立即开始**: 读 `交接信-S04-第二组.md` → 建 Native-02 + OMAC-02 根 issue → 启动双 arm → 采集 → S05 分析。
