# 周报数据集

> 数据截至：2026-08-20
> 收集范围：Multica 工作流引擎项目的 Phase B 当前进展
> 数据口径：仅记录随附材料中可追溯的已验证事实；计划和待办单独标注，不计入完成项。

## 来源与可信度

| 来源 | 日期/状态 | 可提取事实 |
| --- | --- | --- |
| `Evidence/B1卡点清单.md` | 2026-08-19，已完成 | B1 的诊断现场、5 个卡点及修正结论、mocksite 三节点收敛结果 |
| `Evidence/B2验收记录.md` | 2026-08-19，已验收 | B2 的实现范围、测试结果和 mocksite 实测验收结果 |
| `项目总纲-Multica工作流引擎.md` | 当前状态快照 | Phase B 阶段状态、B3/B4 目标和验收定义 |
| `交接信-新session.md` | 2026-08-19 | 当前工作起点、已完成资产、B3 尚未开工的确认 |

## 已完成进展

| 工作项 | 状态 | 已验证事实 | 证据来源 |
| --- | --- | --- | --- |
| B1：content 交付形态诊断 | 已完成 | 定位并记录 5 个卡点；核心 content 卡点为 `pr_base` 强制和 `pr_url` 的 mock 假通过。 | `Evidence/B1卡点清单.md` |
| B1：weekly 流程回归场 | 已完成 | 隔离的 `mocksite` 场景中，weekly 的 collect、write、review 三节点全链路收敛，评审结论为 `pass`。 | `Evidence/B1卡点清单.md` |
| B2：delivery_mode 抽象 | 已完成 | 增加节点级 `delivery_mode: pr|content`；差异策略集中在 `src/omac/core/delivery.py`。 | `Evidence/B2验收记录.md` |
| B2：content 声明与证据规则 | 已完成 | content 节点不再要求 `pr_base` 或 `pr_url`；验收改由 `verification_commands` 和 `integration_gates` 承载。 | `Evidence/B2验收记录.md` |
| B2：自动化验证 | 已完成 | `tests/test_delivery_mode.py` 共 7 项用例，结果为 7/7 通过。 | `Evidence/B2验收记录.md` |
| B2：端到端验收 | 已完成 | `omac dag run mocksite/manifest.yaml` 输出 `converged done=3 total=3`，顺序为 collect -> write -> review，reviewer 为 bob，结论为 `pass`。 | `Evidence/B2验收记录.md` |

## 本周量化数据

| 指标 | 值 | 说明 |
| --- | ---: | --- |
| 已完成 Phase B 子阶段 | 2 | B1、B2 均标记完成；B3 尚未开工。 |
| 已记录诊断卡点 | 5 | B1 清单中的编号卡点 1-5；其中 4、5 已在后续实测中修正根因。 |
| delivery_mode 专项测试 | 7/7 通过 | B2 的 TDD 回归结果。 |
| weekly 流程节点收敛数 | 3/3 | collect、write、review 均完成，且 review 为 pass。 |
| B2 发现的额外 PR 专属差异点 | 4 | PR 封印、done 终态 reconcile、评审因果基线等均已统一路由到 delivery 策略。 |

## 风险、限制与待办

| 项目 | 当前结论 | 对后续工作的影响 |
| --- | --- | --- |
| 全量回归环境 | Windows 本地存在 88 条预存环境失败；B2 的回归口径为相对基线零新增。 | 不可将全量测试的绝对通过数写为 B2 新增回归失败。 |
| mock 使用方式 | `dag run` 在单进程内可保持 mock 状态；多次独立 `dag tick` 会丢失 mock 内存状态。 | 后续 mock 全链路验证应使用隔离 `mocksite` 的 `dag run` 路径。 |
| 引擎配置 | merge 命令解析跟随 `config.yaml` 的 engine；CLI `--engine mock` 覆盖不会传导。 | 需继续使用 `mocksite` 隔离配置，避免误触发真实 `gh pr merge`。 |
| B3：真实基线对比 | 未开工。 | 需在同场景、同 agent、同参数下分别运行 Multica 引擎与原生 LLM 编排，并收集总 token、总耗时、步骤数、失败率。 |
| B4：content 全链路 | 未开工。 | 需验证 weekly 的 collect -> write -> review 真实 content 交付，包括 reviewer、返工与收口行为。 |

## 供 write 阶段使用的结论

1. 本周可确认完成的是 B1 诊断和 B2 delivery_mode 骨架，不应将 B3 或 B4 写为已完成。
2. 主要成果是：weekly 三节点 content 流程已在 mocksite 以 `3/3` 收敛并获得 `pass`；content 交付已去除对 PR 字段的虚假依赖。
3. 下周计划应聚焦 B3 的真实基线数据收集与 B4 的真实 content 全链路验证；B3 的四项对比指标为 token、耗时、步骤数和失败率。
4. 所有量化陈述均可回溯到本文件列出的四份来源材料；未经实测的计划、估计或外推不纳入本周完成数据。
