# 下一 Session 快速入口

> 3 分钟了解当前状态, 然后读主文档

## 当前状态 (一句话)

**S03 已 PASS (2026-08-20 全新链路一次过门收敛), S04 正式采样就绪待开跑。**

## S04 开跑前必须解决的两件事

1. **fixture 注入链路设计** (未解设置题): 协议要求根 issue 携带共同任务正文 + 4 个冻结 fixture 附件, OMAC 侧"collect 通过与 Native 相同的根 issue fixture/ref 读取初始事实"。但今天的 smoke 没走这条路 (agent 用 workdir 上下文), **根 issue fixture -> OMAC collect 节点的具体接线方式还没被真实操作过** (source_refs? issue 描述? plan create 的输入?), 开跑前必须先设计并小规模验证, 否则 OMAC 样本可能不合规
2. **执行顺序确认** (用户拍板): protocol.md 冻结了串行 ABAB (`Native-01 -> OMAC-01 -> Native-02 -> OMAC-02`), 理由是平摊时间漂移 + 避免资源竞争污染数据。用户若要改 (如并行/分日跑), 必须在开跑前修订 protocol.md 并重新冻结 (样本未开始, 合同允许改)

## 已定案的决策 (不再重议)

- **WEEK-15 reviewer 合同质量意见 (gate 命令弱于验收声明): S04 前不采纳, 维持现口径**。理由: 现口径已被 S03 全链路验证; 一致性查验由 A4 rubric 人工查验兜底。未来若采纳, 一次性按计划执行: 收紧三节点 gate 命令 -> `dag check --no-review` lint -> 重新 smoke -> 修订 protocol.md 重新冻结 -> 两 arm 同步
- **不降级 PR 模式**, content 模式保留 (修复已验证)
- **`omac dag check` 评审流程有无限轮询 bug** (reviewer agent 不写结构化 verdict, `run_review` 无超时, WEEK-11/15 两次复现): 规避方式 `--no-review` 或直接 `dag run/tick`; 记为 OMAC backlog, 不阻塞 B3

## S03 最终证据

主文档: `smoke/s03-final-pass.md` (时间线/sha256 链/token 用量/已知事项)
根因与修复: `s03-rootcause-fix-20260820.md` (bug 链条, oh-my-multica@206f3b4)

## Git Commits

**oh-my-multica** (main, 未 push):
```
206f3b4 - fix(content): complete-unsealed 收口前补 hydrate worker verification
a605a34 - fix(content): 修复 content 模式 protocol 生成
ab9d0fe - feat(content): S02 content 交付前置实现
```

**learnezvibe**: S03 PASS 文档与计划更新 (见 git log)

## S04 执行要点 (已验证的纪律)

- 串行逐样本后台跑: 有界 `omac dag tick` 驱动循环 (模板 `.omac/smoke-driver.sh`, 日志参考 `.omac/smoke-run.log`), 每样本 ~45 分钟, 我定时查状态用户零值守
- 任何没读过源码的命令先读源码再跑; 涉及平台/agent 的命令一律带 timeout 或后台
- 采集: 每样本 issue/run/run-message/usage/时间戳 + 每跳产物 SHA-256, 存 `Evidence/B3/samples/<sample-id>/`
- 读数注意: collect 可能跑 2 个 run (smoke 中出现, usage 去重但 run 数是独立指标); review 的 gate 不查内容语义, A4 靠人工查验 run-message

---

**立即开始**: 设计并验证 fixture 注入链路 -> 用户确认执行顺序 -> 按 protocol.md 开跑 Native-01
