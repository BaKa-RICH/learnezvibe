# Native-03 样本证据采集清单 + 验收（已核验）

> 重跑（2026-08-20，同窗串行第一臂）。对照 protocol A1-A5。证据先暂存仓库外 tmp-collect，双臂收敛 + canary 全绿后移入。

## 0. 样本身份

| 字段 | 值 |
|---|---|
| 样本 ID | Native-03 |
| 根 issue UUID | 01a01f0e-44d0-729a-9fad-14c9d0fa6e1c |
| 根 issue key | WEEK-30 |
| 开始时间 | 2026-08-20T12:04:10Z（首个 run started_at） |
| 结束时间 | 2026-08-20T12:21:46Z（最后 run completed_at） |
| 最终结果 | SUCCESS（根 issue in_review，review 结论通过） |

## 1. 根 issue 完整性检查

- [x] 正文 = root-issue-body.md 逐字（description sha256=3beb44390fa334b816ef07e76cfd70a8a3be29f6114ebfdd98cded346277f6a1；与 OMAC-03 根 issue 相同）
- [x] 4 个附件 = fixtures-v1 冻结文件（size 5297/18915/8165/4205 与 frozen-input.json 一致）
- [x] 附件 ID 记录到 root-issue.json
- [x] 已指派"周报"squad（6e94e57b-9c9d-4380-9304-5b9d780112f1）

## 2. 证据文件清单

| 文件 | 内容 | 状态 |
|---|---|---|
| root-issue.json | 根 issue + 附件明细 | ☑ |
| runs.json | 全部 7 run（id/status/agent/时间/usage） | ☑ |
| runmsg-<run>.json | 7 个计量 run 完整 run-messages | ☑ |
| deliverables/ | weekly-data.md / weekly-report.md + SHA-256 | ☑ |
| summary.json | 指标汇总（成员/含 leader 双口径） | ☑ |
| comment-thread.json | 根 issue 评论线程（委派记录） | ☑ |
| usage.json | 平台聚合 usage | ☑ |
| issue-*.json / runs-*.json | 监控快照（过程留痕） | ☑ |

## 3. 验收标准（rubric A1-A5）

| ID | 条件 | 证据 | 通过 |
|---|---|---|---|
| A1 | weekly-data.md 非空且 ≥3 条要点 | 4318B；6 条已完成进展要点（B1 诊断/回归场、B2 抽象/规则/验证/端到端） | ☑ |
| A2 | write 基于 collect 产物生成 report | write 评论声明"使用 collect 阶段交付的 weekly-data.md 作为唯一数据输入"；报告内容与 collect 数据一致 | ☑ |
| A3 | report 含"本周进展"+"下周计划" | 两个小节均存在（人工读文件） | ☑ |
| A4 | review 检查准确性/结构/一致性 | review 评论（f1657953）人工核验：准确性（B1/B2 状态、5 卡点、7/7、3/3 pass 与 collect 一致）、结构（两小节齐全）、一致性（无矛盾） | ☑ |
| A5 | 三阶段严格 collect→write→review，终态达成 | 评论时间线 12:05:22→12:10:45→12:15:20 严格串行；根 issue in_review 终态 | ☑ |

## 4. 指标采集（summary.json）

- 成员三节点（3 runs）：in=161685 out=13025 cr=1215232 cw=0，total=1389942；墙钟 14m17s；步骤 113
- 含 leader 编排（7 runs）：in=286865 out=20256 cr=1862400 cw=0，total=2169521；墙钟 17m36s；步骤 197
- 故障 run：无

## 5. canary1（污染告警，全绿）

- [x] collect 成员 run-messages 无 `WEEK-2[5-9]` / `run-messages 01a0` / OMAC 工单引用（omac 引用均为冻结 fixture 正文）
- [x] weekly-data.md hash 8daac0ff... 全新（≠ 14caa249/5245b7f6/c87bb483/003dc995/0f1e46f4）
- [x] 根 issue 达终态（in_review）
- [x] 无 samples/deliverables 引用（成员 run 扫描 0 hits）

## 6. 备注

- leader 4 次编排 run（direct 委派 + 3 次跟进），成员 3 次 run，共 7 次，全部 completed
- 交接媒介：根 issue 评论区附件（collect/write 交付物均以评论附件上传）
- review 为声明式结论（与 OMAC 的脚本级核验不同，属设计使然）
