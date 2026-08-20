# B3 Evidence 文档索引

> 最后更新: 2026-08-20  
> 当前状态: **S03 PASS** (全新链路一次过门收敛), S04 正式采样就绪待开跑

## 快速导航

**新 session 入口**: 先读 `交接信-S04.md` (下个 session 的第一封信) -> `next-session-entry.md` (3 分钟速查)

**当前问题**: S04 开跑前置 -- ① fixture 注入链路设计 (根 issue -> OMAC collect 接线未验证); ② 执行顺序已定案为配对并发 (protocol.md 已修订)。详见交接信-S04.md / next-session-entry.md

## 目录结构

### 核心交接文档
- `s03-rootcause-fix-20260820.md` - 根因定位与修复 (2026-08-20, 已验证收尾)
- `smoke/s03-final-pass.md` - **S03 最终 PASS 证据** (2026-08-20: 时间线/sha256 链/token 用量)
- `next-session-entry.md` - 3分钟快速入口
- `session-handoff-20260819.md` - 上一 session 交接 (历史记录, 根因猜测已被新文档纠正)
- `code-changes-summary.md` - 代码改动汇总 (S02 阶段)

### S01 冻结合同
- `protocol.md` - 实验协议 (验收标准、公平性合同)
- `frozen-input.json` - 冻结的输入 (revision, fixture 哈希)
- `config-snapshot.json` - Agent 配置快照

### S02 前置实现
- `s02-gate-verdict.md` - S02 基线验证报告 (零新增回归)
- `baseline-4f1773d.txt` - 基线测试结果
- `after-s02.txt` - S02 后测试结果
- `prerequisite-verification.md` - 前置验收记录
- `s02-fix-plan.md` - Protocol 修复计划

### S03 Smoke 测试
- `smoke/s03-final-result.md` - 第一次执行结果 (发现 protocol 冲突)
- `smoke/s03-retry-failed.md` - 修复后重试结果 (仍失败, 根因见 s03-rootcause-fix-20260820.md)
- `smoke/failure-analysis.md` - 失败分析 (当时的初步分析, 根因以新文档为准)
- `smoke/progress-report.md` - 执行进度
- `smoke/current-situation.md` - 情况说明
- `smoke/omac-dag-run-fresh.log` - OMAC 执行日志
- `smoke/issue-create-result.json` - WEEK-10 创建记录
- `smoke/issue-description.md` - Smoke issue 描述

### 其他
- `S03-smoke-plan.md` - S03 执行计划 (操作手册)
- `session-status-2026-08-19.md` - 给下一 session 的初步交接

## Git Commits (oh-my-multica)

```
a605a34 - fix(content): 修复 content 模式 protocol 生成
ab9d0fe - feat(content): S02 content 交付前置实现
4f1773d - feat(delivery): B2 交付形态骨架 (基线)
```

## 关键发现

1. **S02 基线验证**: 零新增回归,修复1个旧bug
2. **Protocol 冲突**: Contract 说 content, Protocol 说 PR
3. **Protocol 已修复**: dispatch.py 根据 delivery_mode 动态生成
4. **仍然失败**: Agent 收到正确指令但 evidence gate 仍拒绝
5. **根本原因**: 比 protocol 文本更深,可能是 submit 流程或 evidence gate 验证逻辑

## 下一步选项

**A.** 继续修复 content 模式 (分析 evidence gate 源码)
**B.** 降级到 PR 模式完成 B3
**C.** 其他方案

## 文件清理记录

已删除:
- `s02-changes.patch` (已提交 commit,不需要 patch)
- `pytest-full.txt` (不完整的测试日志)
- `smoke/quick-summary.txt` (临时文件)
- `smoke/issue-current-state.json` (空文件)
- `smoke/runs-initial.json` (空文件)
- `smoke/omac-dag-run.log` (被更完整的日志替代)
- `smoke/omac-dag-run-retry.log` (被更完整的日志替代)
- `smoke/omac-dag-run-clean.log` (被更完整的日志替代)
