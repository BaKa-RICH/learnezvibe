# Phase B 周报

> 报告日期：2026-08-20
> 数据来源：collect 阶段交付的 `weekly-data.md`
> 统计口径：仅纳入可追溯且已验证的事实；计划项不计入本周完成。

## 本周进展

### B1：content 交付形态诊断已完成

- 完成诊断现场梳理，记录 5 个卡点；其中核心问题为 `pr_base` 的强制要求，以及 `pr_url` 导致的 mock 假通过。
- 在隔离 `mocksite` 场景中，weekly 的 collect、write、review 三节点按 `collect -> write -> review` 全链路收敛，结果为 `3/3` 完成，review 结论为 `pass`。

### B2：delivery_mode 抽象与验收已完成

- 增加节点级 `delivery_mode: pr|content`，差异策略集中于 `src/omac/core/delivery.py`。
- content 节点不再要求 `pr_base` 或 `pr_url`；交付验收由 `verification_commands` 与 `integration_gates` 承载。
- `tests/test_delivery_mode.py` 的 7 项用例全部通过（7/7）。
- 端到端验证中，`omac dag run mocksite/manifest.yaml` 输出 `converged done=3 total=3`，reviewer 为 bob，结论为 `pass`。

### 量化摘要

| 指标 | 本周结果 |
| --- | --- |
| 已完成 Phase B 子阶段 | 2 个：B1、B2 |
| 已记录诊断卡点 | 5 个 |
| delivery_mode 专项测试 | 7/7 通过 |
| weekly 流程节点收敛 | 3/3，review=pass |

## 风险与注意事项

- Windows 本地全量回归存在 88 条预存环境失败；本周 B2 的回归结论为相对基线零新增，不能将绝对失败数归因于 B2。
- mock 全链路验证应使用隔离 `mocksite` 的 `dag run` 路径。独立多次执行 `dag tick` 会丢失进程内 mock 状态。
- merge 命令解析受 `config.yaml` 中 engine 控制，CLI 的 `--engine mock` 覆盖不会传导；后续验证继续使用隔离配置，避免误触发真实 PR 合并。

## 下周计划

1. 推进 B3 真实基线对比：在同场景、同 agent、同参数下分别运行 Multica 引擎和原生 LLM 编排，采集总 token、总耗时、步骤数与失败率。
2. 推进 B4 content 全链路验证：验证 weekly 的真实 `collect -> write -> review` content 交付，覆盖 reviewer、返工与收口行为。
3. 基于 B3/B4 的实测结果更新周报数据；未实测项继续明确标记为计划，不提前计入完成。

## 结论

本周已完成 B1 诊断与 B2 delivery_mode 骨架及其专项、端到端验证。B3 真实基线对比和 B4 真实 content 全链路尚未开工，已列入下周计划。
