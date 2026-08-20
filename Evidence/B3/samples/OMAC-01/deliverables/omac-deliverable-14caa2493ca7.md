# 本周数据（b3-weekly-fixture-v1）

- 当前进度为 Phase A、B1、B2 已完成，B3 尚未开工；B3 的启动项是完成环境检查并先落盘计划，关键运行参数须经确认后再执行。
- B3 要在相同场景、agent 与参数下，对 Multica 真引擎和原生 LLM 编排各运行 N 次，并从平台执行记录提取总 token、总耗时、步骤数和失败率；不得编造这些指标。
- B1 已定位并修正 content 交付的两项实质问题：lint 不应强制 `pr_base`，evidence 门不应要求或由 mock 伪造 `pr_url`；隔离的 mocksite 已验证 weekly 三节点（含评审）全链路 3/3 收敛。
- B2 在提交 `4f1773d` 建立节点级 `delivery_mode: pr|content` 和统一交付策略；content 模式通过验证命令和集成门验收，不走 PR merge、封印和远端合入观察路径，相关测试 7/7 通过。
- 完整回归采用“相对基线零新增失败”口径：Windows 环境存在 88 条与 B2 无关的预存编码/环境失败；本周资料还记录了 content 三节点收敛并获得 reviewer 的 `pass` 结论。

## 输入完整性

已从上游根 issue 下载四个指定附件，并计算 SHA-256：交接信 `a3553b02ce6ad7de19aa9bab379b5568cb822abfeed1b094ccd6876be0997271`、项目总纲 `17c5cb0d368aa935fd18d4922ce5a516f318ee8b6e8277a4a3194036e004cde2`、B1 `40cb15e9ba79f737bd9b549deed03f421d449a30dee7f585b580b0db07b26a48`、B2 `9d744387dc9ddbf93de3814bd27794c325568e1e575e6831f78e968ce627819c`。上游 issue 仅提供这四个附件，未提供任务要求的 `frozen-input.json`，因此无法完成声明的 SHA-256 对照确认；以上要点未使用仓库或 workdir 中的同名文件。
