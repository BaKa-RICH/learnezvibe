# S04 样本证据采集清单 + 验收标准（模板）

> 用途：新 session 跑第二组时，为每个样本（Native-02 / OMAC-02）逐项核对填写。
> 用法：复制本文件到 `Evidence/B3/samples/<样本ID>/checklist.md`，跑完逐项勾选填写；或按本清单逐项采集后删除模板本文件。
> 对照协议：`Evidence/B3/protocol.md`（指标口径第 5 节、rubric A1-A5、失败/排除口径）。
> 参照已完成的样板：`Evidence/B3/samples/Native-01/`、`OMAC-01/`（原始证据齐全，可对照格式）。

---

## 0. 样本身份（填）

| 字段 | 值 |
|---|---|
| 样本 ID | Native-02 / OMAC-02 |
| 根 issue UUID | （create 后填）|
| 根 issue key | WEEK-?? |
| 开始时间 | （首个计量 run started_at）|
| 结束时间 | （终态 run completed_at）|
| 最终结果 | SUCCESS / FAILED / 排除 |

## 1. 根 issue 完整性检查（启动时必查）

- [ ] 正文 = `root-issue-body.md` 逐字（与 protocol 共同任务正文一致，两个 arm 字节相同）
- [ ] 4 个附件 = fixtures-v1 的 4 个冻结文件（字节/哈希与 frozen-input.json 一致）
- [ ] 附件 ID + size_bytes 记录到 `root-issue.json`
- [ ] Native：已指派"周报"squad；OMAC：manifest `meta.source_issues` 指向本根 issue

## 2. 证据文件清单（每个样本存 `Evidence/B3/samples/<id>/`）

| 文件 | 内容 | Native | OMAC |
|---|---|---|---|
| `root-issue.json` | 根 issue + 附件明细 | ☐ | ☐ |
| `observations.json` | 事件流水（派发/委派/异常/重试）| ☐ | ☐ |
| `runs.json` | 全部 run（id/status/agent/时间/usage）| ☐ | ☐ |
| `runmsg-<run>.json` | 每个计量 run 的完整 run-messages | ☐ | ☐ |
| `deliverables/` | 下载的产品文件（weekly-data.md / weekly-report.md）+ 逐文件 SHA-256 | ☐ | ☐ |
| `summary.json` | 指标汇总（见第 4 节）| ☐ | ☐ |
| `comment-thread.json` | 根 issue 评论线程（Native 委派记录；OMAC 有则存）| ☐ | ☐ |
| `driver.log` | OMAC driver 运行日志（OMAC 必存）| — | ☐ |

## 3. 验收标准（rubric A1-A5，全部满足才算 SUCCESS）

| ID | 条件 | 证据怎么取 | 通过 |
|---|---|---|---|
| A1 | `weekly-data.md` 非空且 ≥3 条要点 | 下载交付物读内容 + 数要点 | ☐ |
| A2 | write 基于 collect 产物生成 report | report 内容/声明 + write 输入 ref | ☐ |
| A3 | report 含"本周进展"+"下周计划" | 读 report 文件 | ☐ |
| A4 | review 检查准确性/结构/一致性 | OMAC：verification yaml 的 review-consistency.py；Native：人工看 review 评论/run-message | ☐ |
| A5 | 三阶段严格 collect→write→review，终态达成 | issue/run 状态 + 时间线 | ☐ |

> 注意：A4 不能只信过门——OMAC 的证据门只验结构不验语义，Native 的 review 是声明式结论，都要人工看一眼内容。

## 4. 指标采集（按 protocol 口径，填 summary.json）

- **四类 token**：`total_input_tokens` / `total_output_tokens` / `total_cache_read_tokens` / `total_cache_write_tokens`（按成功 run 的 usage 去重汇总）
- **headline total_tokens** = 四类相加
- **wall_clock**：首个计量 run started_at → 终态 run completed_at
- **步骤数**：去重的 run-message 事件数（建议另记 tool_use 数，便于横向比）
- **run 数**：按唯一 run id 另报（与业务节点数 3 分开）
- **Native 两种口径都要算**：成员三节点 vs 含 leader 编排开销（protocol：leader 决策/控制调用计入样本）
- **故障 run**：空会话/usage 为空/1-3 条消息即截断的 run，**不计入计量**，单列披露（协议修订记录口径）

## 5. 失败/排除判定（protocol 口径）

- 业务执行失败 → 保留为**失败样本**（照实记录，不重跑替换）
- 仅以下才可**排除并补足样本槽**：启动前取消、错误 revision、配置漂移、关键遥测缺失
- 基础设施故障（如账号欠费导致的空会话）→ 不计入计量、单列披露，**不算失败样本**
- 任何口径争议 → **升级用户，不自行判定**

## 6. 备注（异常/观察/遗留）

- （记录：委派方式、review 深度、retry 次数、任何平台异常……）
