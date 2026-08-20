# OMAC-03 样本证据采集清单 + 验收（已核验）

> 重跑（2026-08-20，同窗串行第二臂）。对照 protocol A1-A5。证据先暂存仓库外 tmp-collect，双臂收敛 + canary 全绿后移入。

## 0. 样本身份

| 字段 | 值 |
|---|---|
| 样本 ID | OMAC-03 |
| 根 issue UUID | 01a01f25-ba04-7ad6-a160-8e51443c2046 |
| 根 issue key | WEEK-31 |
| 开始时间 | 2026-08-20T12:31:02Z（collect 首个 run started_at） |
| 结束时间 | 2026-08-20T13:05:01Z（review run completed_at） |
| 最终结果 | SUCCESS（CONVERGED rc=0，三节点 done） |

## 1. 根 issue 完整性检查

- [x] 正文 = root-issue-body.md 逐字（description sha256=3beb4439...，与 Native-03 字节一致）
- [x] 4 个附件 = fixtures-v1 冻结文件（size 5297/18915/8165/4205 一致）
- [x] 附件 ID 记录到 root-issue.json
- [x] manifest meta.source_issues 指向根 issue；三节点 status todo / work_item_id null 启动

## 2. 证据文件清单

| 文件 | 内容 | 状态 |
|---|---|---|
| root-issue.json | 根 issue + 附件明细 | ☑ |
| collect/write/review-runs.json | 三节点 run（id/status/agent/时间/usage） | ☑ |
| runmsg-collect/write/review.json | 三节点完整 run-messages | ☑ |
| deliverables/ | 3 交付物附件 + 3 verification yaml + git 分支提取的实际产物 | ☑ |
| summary.json | 指标汇总 | ☑ |
| driver.log | driver 运行日志（tick 序列，CONVERGED rc=0） | ☑ |

## 3. 验收标准（rubric A1-A5）

| ID | 条件 | 证据 | 通过 |
|---|---|---|---|
| A1 | weekly-data.md 非空且 ≥3 条要点 | 602B；4 条要点（git 分支 origin/agent/weekly-collect/62a4df67 提取） | ☑ |
| A2 | write 基于 collect 产物生成 report | review verification 用 `git show origin/agent/weekly-collect/62a4df67:weekly-data.md` 对比；write 报告内容覆盖 collect 全部数据点 | ☑ |
| A3 | report 含"本周进展"+"下周计划" | write 与 review 产物均含两个小节（人工读文件） | ☑ |
| A4 | review 检查准确性/结构/一致性 | review verification yaml（14b9dc26）：3 命令全过，含 upstream item containment check（4 条数据要点全在报告中，missing_items 空）；env_setup 指向 git ref 机制 | ☑ |
| A5 | 三阶段严格 collect→write→review，终态达成 | 时间线 12:31→12:44 (collect)、12:46→12:53 (write)、12:57→13:05 (review) 完全串行无重叠；CONVERGED rc=0 | ☑ |

## 4. 指标采集（summary.json）

- 三节点（3 runs）：in=574359 out=27889 cr=3636736 cw=0，total=4238984
- 墙钟：33m59s（collect 12:31:02 → review 13:05:01）
- 步骤数：168 事件（collect 83 / write 50 / review 35）
- 故障 run：无

## 5. canary2（污染告警，全绿）

- [x] write run-messages 无 `Native-0x` 路径引用 / `samples` / `deliverables`（samples=0、deliverables=0、WEEK-2=0；Native-0x 仅出现在 git log commit subject）
- [x] 产物 hash 全新：41cb834b（data）/ f5130fc1（write）/ fce9d7bf（review）≠ 历史（14caa249/5245b7f6/c87bb483/003dc995/0f1e46f4）
- [x] review verification yaml 的 env_setup/summary 不指向 samples/deliverables 路径（指向 git ref 与根 issue 附件）
- [x] 三节点 run 时间线无重叠（严格串行）
- [x] review 交付物与 write 内容自洽（review 修订措辞、数据点一致；未照抄历史样本）

## 6. 备注

- 节点间产物传递走 WorkItemStore git 分支（origin/agent/weekly-collect/62a4df67 等）与 workdir 磁盘文件，非人工复制
- collect 的 deliverable 附件为交付说明（263B），实际 weekly-data.md 内容在 git 分支（602B）
- review 对 write 产物做了实质修订（920B vs 813B），内容自洽（canary2 允许"透传或自洽"）
- 证据采集期无后续 run，移入 Evidence/B3/samples/ 不会再生污染
