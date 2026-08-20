# Weekly Data

> 范围：2026-08-17 至 2026-08-20
> 数据状态：collect 阶段整理；仅记录已提供资料中可核验的事实。

## 本周已完成

| 项目 | 状态 | 可核验事实 | 证据来源 |
| --- | --- | --- | --- |
| B1：weekly 流程问题定位与复验 | 完成 | 已定位 content 交付在 `pr_base` 与 `pr_url` 校验上的阻塞；在隔离 mocksite 中，weekly 三节点全链路收敛，顺序为 collect -> write -> review，review 结论为 pass。 | `B1卡点清单.md` |
| B2：交付形态抽象 | 完成 | 交付形态已支持 `delivery_mode: pr|content`；content 节点免除 `pr_base` 与 `pr_url` 要求，采用 verification 通道承载验收；相关实现提交为 `4f1773d`。 | `B2验收记录.md` |
| B2：测试与验收 | 完成 | `tests/test_delivery_mode.py` 7/7 通过；`omac dag check mocksite/manifest.yaml` 通过 3 节点 lint 与 reviewer 校验；`omac dag run mocksite/manifest.yaml` 收敛为 3/3 节点完成。 | `B2验收记录.md` |
| 交付边界 | 完成 | 正式 weekly 草案使用 content 交付形态，声明面不包含 PR 字段；content 节点不走 merge 确认与 PR 封印路径。 | `交接信-新session.md`、`B2验收记录.md` |

## 当前基线

| 字段 | 值 |
| --- | --- |
| 项目阶段 | Phase A、B1、B2 已完成；B3 尚未开始。 |
| 代码基线 | oh-my-multica commit `4f1773d`。 |
| 周报流程定义 | 三阶段：collect -> write -> review；本文件是 collect 阶段的输入产物。 |
| 本阶段产物 | `weekly-data.md`，供 write 阶段生成 `weekly-report.md` 使用。 |

## 风险与注意项

| 项目 | 状态 | 说明 |
| --- | --- | --- |
| Windows 全量回归 | 已知环境基线问题 | 存在 88 条预存环境/编码类失败；B2 的判定依据为相对基线零新增失败，而非宣称全量零失败。 |
| mock 引擎配置 | 已知注意项 | `--engine mock` 覆盖不会传导至 merge 命令解析；应使用隔离 mocksite 的 `engine: mock` 配置。 |
| B3 基准测试 | 未开始 | 需要以真实引擎运行 weekly，并采集总 token、总耗时、步骤数、失败率；尚无可报告数值。 |

## 下周/后续输入

1. B3 开始前完成运行环境检查，并由用户确认测试参数。
2. B3 以真实平台执行记录为准采集指标，不编造 token、耗时、步骤数或失败率。
3. write 阶段应仅基于本文件中的“本周已完成”“当前基线”“风险与注意项”生成周报，并保留“B3 未开始”的状态表述。

## 来源清单

- `交接信-新session.md`：阶段进度、B3 测试范围与正式 weekly 草案信息。
- `项目总纲-Multica工作流引擎.md`：项目目标和阶段规划。
- `B1卡点清单.md`：B1 问题定位与 mocksite 全链路复验记录。
- `B2验收记录.md`：B2 实现、测试和验收记录。
