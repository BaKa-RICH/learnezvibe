# B3 Evidence 文档索引

> 最后更新: 2026-08-20
> 当前状态: **B3 已完成** —— 4 有效样本全 SUCCESS（Native-01/03 + OMAC-01/03），S05 分析报告已出，污染样本已排除并单列披露。

## 快速导航

- **结论一页**: `reports/B3-S05-结论-一页.md`（给用户）
- **硬核明细**: `reports/B3-S05-四样本对比-硬核明细.md`（token/墙钟/步骤/run 数/成功率，Native 双口径）
- **污染披露**: `reports/B3-S05-污染样本披露.md`（Native-02/OMAC-02，不计入计量）
- **样本证据**: `samples/Native-03/`、`samples/OMAC-03/`（本次重跑）；第一组 Native-01/OMAC-01 及污染样本在归档目录 `learnezvibe-b3-archive-20260820/samples/`
- **实验合同**: `protocol.md`（修订记录：同窗串行/新槽 03/污染排除/故障 run 不计入）
- **冻结输入**: `frozen-input.json`、`fixtures-v1/`

## B3 结果速查（4 有效样本，全 SUCCESS）

| 样本 | total token | 墙钟 | tool_use | 备注 |
|---|---|---|---|---|
| Native-01 | 107.4 万（含 leader 291.2 万） | 10m01s（含 leader 13m05s） | 39（全 78） | 第一组 |
| Native-03 | 139.0 万（含 leader 217.0 万） | 14m17s（含 leader 17m36s） | 49（全 84） | 重跑 |
| OMAC-01 | 319.8 万 | 23m08s | 91 | 第一组 |
| OMAC-03 | 423.9 万 | 33m59s | 75 | 重跑 |

## 目录结构

### 核心交接文档（已完成，保留为执行史）
- `s03-rootcause-fix-20260820.md` - 根因定位与修复 (2026-08-20, 已验证收尾)
- `交接信-S04-第二组.md` / `交接信-S04-第二组重跑.md` - S04 两轮执行交接（历史）
- `prompt-重跑第二组.md` - 重跑执行 prompt（历史）
- `next-session-entry.md` - 3分钟快速入口（B3 期间用；B3 已收口，后续以总纲为准）

### S01 冻结合同
- `protocol.md` - 实验协议 (验收标准、公平性合同、修订记录)
- `frozen-input.json` - 冻结的输入 (revision, fixture 哈希)
- `config-snapshot.json` - Agent 配置快照

### S02 前置实现（历史验证记录）
- `s02-gate-verdict.md`、`baseline-4f1773d.txt`、`after-s02.txt`、`prerequisite-verification.md`、`s02-fix-plan.md`、`code-changes-summary.md`

### S03 Smoke 测试
- `smoke/s03-final-pass.md` - S03 最终 PASS 证据
- 其余 smoke 中间产物已归档

### S04/S05 证据
- `samples/Native-03/`、`samples/OMAC-03/` - 重跑样本证据（checklist/root-issue/runs/runmsg/deliverables/summary/observations）
- `reports/` - S05 三份报告

### 归档
- `archive/` - S03 中间产物、历史交接、旧 session 状态

## 关键发现（B3 全程）

1. Mock 通过 ≠ 真实集成成功（S03 教训）
2. Content 模式真实集成根因：evidence gate hydration bug（206f3b4 修复）
3. 配对实验的环境共享性污染：跨 arm 串扰 + 跨样本仓库残留 → 同窗串行 + 清场解决
4. OMAC 确定性 vs Native 声明式 review：约 3 倍 token 换可复算可审计
