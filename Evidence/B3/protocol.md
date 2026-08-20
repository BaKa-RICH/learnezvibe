# B3 实验合同

> 状态：S01 冻结；前置能力和 Desktop smoke 尚未通过，因此本文件登记正式实验口径但不表示可以开始计量。
> 冻结时间：2026-08-19（Asia/Shanghai）。
> 修订记录：2026-08-20 S03 PASS 后，执行方式由“串行 ABAB”修订为“配对并发”（同窗配对比较；样本未开始，符合不可变规则）。

## 目标

在同一冻结输入、同一角色 agent 配置、同一 `collect -> write -> review` 业务拓扑和同一验收目标下，对比 Multica Native squad 编排与 OMAC 编排。每组取得 2 个有效正式样本，共 4 个有效样本。

正式样本槽固定为：`Native-01`、`OMAC-01`、`Native-02`、`OMAC-02`。执行方式为**配对并发**：`Native-01` 与 `OMAC-01` 同窗运行、`Native-02` 与 `OMAC-02` 同窗运行（同一环境窗口下配对比较）；禁止同一 arm 两样本并发或四样本全并发。`WEEK-9` 仅作为预演模板，不计入样本；已有取消 run 不计入样本。

## 共同任务正文

以下正文是 Native 根 issue 和 OMAC 根 issue 的共同业务输入。编排方式所必需的控制信息（Native 的 squad 指派、OMAC 的 manifest 控制前缀）单独记录，不改变业务目标。

```text
请完成一条三阶段周报流程，必须按以下业务阶段推进：

1. collect：收集并整理本周数据，产出 weekly-data.md
2. write：基于 weekly-data.md 生成 weekly-report.md
3. review：检查 weekly-report.md 的准确性和结构，确认最终结果

依赖关系必须是：collect -> write -> review

不得跳过、合并或颠倒这三个阶段。

weekly-data.md 存在且内容有效
weekly-report.md 存在且包含“本周进展”和“下周计划”
write 使用 collect 的产物
review 检查 write 的产物
最终结果达到验收标准
```

共同正文中的“本周数据”仅指冻结输入 `b3-weekly-fixture-v1`：`交接信-新session.md`、`项目总纲-Multica工作流引擎.md`、`Evidence/B1卡点清单.md`、`Evidence/B2验收记录.md`。四个样本必须在首个计量 run 前获得完全相同的 fixture attachment/ref；collect 不得使用动态网页、当前日期后产生的事实或未登记文件。fixture 的逐文件哈希和聚合摘要见 `frozen-input.json`。

## 两组编排约束

### Native

- 每次创建新的根 issue，并指派给“周报” squad。
- leader 自主拆解、选择 `collect`、`write`、`review` 成员、派发、接收交付和推进。
- 根 issue 明示三个阶段和顺序；不规定附件、评论、仓库或其他交接媒介。
- leader 的决策和控制调用属于 Native 系统开销，计入样本；实际交接媒介和事件必须原样保存。
- 根 issue 在执行前获得共同 frozen fixture；该初始输入注入不限制 leader 后续选择何种节点交接媒介。

### OMAC

- 每次创建新的根 issue，使用与 Native 相同的共同任务正文。
- manifest 必须是固定三节点 DAG：`collect -> write -> review`。
- `collect`、`write`、`review` 分别使用 `weekly-collect`、`weekly-write`、`weekly-review`。
- B3 基线中 `review` 节点不配置额外 reviewer；若平台产生额外控制 run，必须单列，不能伪装为三节点主调用。
- 节点间文件通过真实 `WorkItemStore`/Multica deliverable/ref 传递；禁止人工复制到下游 workdir。
- collect 通过与 Native 相同的根 issue fixture/ref 读取初始事实；fixture 与节点产物通道分别留痕。

## 共同验收 rubric

| ID | 必须满足的条件 | 证据 |
|---|---|---|
| A1 | `collect` 产出 `weekly-data.md`，非空且至少含 3 条要点 | 文件内容、SHA-256、上游 source/ref |
| A2 | `write` 基于 collect 产物生成 `weekly-report.md` | write 输入 ref/hash 与输出文件 hash |
| A3 | `weekly-report.md` 同时包含“本周进展”和“下周计划” | 文件内容和验证记录 |
| A4 | `review` 检查报告准确性、结构及与 `weekly-data.md` 的一致性 | review run/message、验收结论 |
| A5 | 三阶段严格按 `collect -> write -> review` 完成，最终达到验收标准 | issue/run 状态、时间线、节点产物 |

成功样本必须具备 A1-A5、完整 issue/run/run-message/usage/timestamp lineage，以及可复算的产物传递哈希。业务执行失败保留为失败样本；只有启动前取消、错误 revision、配置漂移或关键遥测缺失等不可比情形才可排除并补足样本槽。

## 指标口径

- 四类原始 token：`total_input_tokens`、`total_output_tokens`、`total_cache_read_tokens`、`total_cache_write_tokens`，按样本 lineage 中去重的 issue/task usage 汇总。
- headline `total_tokens`：四类 `total_*` 相加。`uncosted_*` 是对应 total 的子集，只单列披露，不重复加总。
- 端到端 `wall_clock`：样本首个计量 run `started_at` 到所有验收所需终态 run 的最大 `completed_at`；逐 run active duration 另报。
- 步骤数：去重的平台 `run-message` 事件数；业务节点数固定为 3，实际 run 数按唯一 run id 另报。
- 产物传递：保存每一跳输入/输出 SHA-256 与 source/ref；哈希相等且 ref 可解析才算传递成功。

## 不可变规则

正式样本开始后不得临时修改任务正文、验收 rubric、输入 revision/文件、agent 模型或 thinking、runtime、manifest 拓扑和 review 单调用规则。需要变更时，当前批次作废并重新冻结；不得根据结果事后调整分类或口径。
