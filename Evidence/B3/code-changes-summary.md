# 代码改动汇总

> 本文档汇总 S02 和 Protocol 修复的所有代码改动，关联 git commits

## Commits 概览

### oh-my-multica 仓库

```
a605a34 - fix(content): 修复 content 模式 protocol 生成
ab9d0fe - feat(content): S02 content 交付前置实现
4f1773d - feat(delivery): B2 交付形态骨架 (基线)
```

### learnezvibe 仓库

```
4915d33 - docs(B3): S02-S03 完整证据链和分析文档
```

---

## Commit ab9d0fe: S02 content 交付前置实现

### 改动文件统计

```
src/omac/cli/commands/work.py     | 修改
src/omac/core/delivery.py         | 修改
src/omac/engines/mock.py           | 修改
src/omac/pipeline/dispatch.py     | 修改
tests/test_content_submit.py      | 新增
```

### 详细改动

#### 1. `src/omac/cli/commands/work.py`

**目的**: 增加 `--content-file` 入口，支持 content 模式提交

**改动**:
- 新增 `--content-file` 参数支持
- `work read` 使用 UTF-8 二进制模式写出文件
- 读取时校验 SHA-256 摘要和字节数
- 修复: 避免 CRLF 转换导致的摘要不一致

**为什么**:
- Content 模式需要直接提交文件内容
- 不能依赖 PR 作为传递媒介
- 必须保证文件完整性 (SHA-256 校验)

#### 2. `src/omac/core/delivery.py`

**目的**: 支持从 Contract 对象或 mapping 解析 `delivery_mode`

**改动**:
- `resolve_delivery_mode()` 函数增强
- 同时支持 Contract 对象和字典类型
- 向后兼容: None → pr (默认)

**为什么**:
- 不同调用方传递的 contract 类型不同
- 需要统一的解析逻辑
- 保持向后兼容性

#### 3. `src/omac/pipeline/dispatch.py`

**目的**: Content 模式使用 `--content-file` 参数，PR 模式使用 `--pr-url`

**改动**:
- Submit 参数模板根据 `delivery_mode` 动态生成
- Content 模式: `--content-file + --verification-file`
- PR 模式: `--pr-url + --verification-file`
- 提交前校验正文与 verification 一致性

**为什么**:
- 两种模式的提交参数不同
- Agent 需要收到正确的 submit 命令模板
- 防止参数错误导致提交失败

#### 4. `src/omac/engines/mock.py`

**目的**: Mock 引擎支持 content deliverable 的可校验 ref

**改动**:
- Mock deliverable 生成包含 SHA-256 和字节数
- 支持本地 source/ref 测试
- 验证 deliverable 传递的完整性

**为什么**:
- 测试需要验证 deliverable 传递机制
- Mock 环境下也要保证数据一致性
- 为真实环境提供参考实现

#### 5. `tests/test_content_submit.py` (新增)

**目的**: 完整测试 content 模式的提交、持久化、读取流程

**测试用例** (12 个):
- Content 参数模板选择
- 缺失参数的教学错误
- 正文与 verification 持久化
- Multica adapter payload/ref 摘要
- 独立 workdir 的 `work read` 写出相同字节
- Digest drift 拒绝
- PR 路径回归保护
- Multica adapter contract 隔离测试

**覆盖率**:
- Submit 参数生成 ✅
- WorkItemStore 持久化 ✅
- 跨 workdir 读取 ✅
- SHA-256 校验 ✅
- 回归保护 ✅

**为什么**:
- TDD: 先写测试，证明旧行为不支持 content
- 完整覆盖 content 模式的关键路径
- 回归保护: 确保 PR 模式不受影响

### S02 验证结果

**测试**:
- `test_content_submit.py`: 12/12 通过 ✅
- `test_delivery_mode.py`: 7/7 通过 ✅
- 基线对比: 零新增回归 ✅
- 修复: 1 个旧 bug (work read CRLF) ✅

**判定**: S02 代码层面 PASS

---

## Commit a605a34: 修复 content 模式 protocol 生成

### 改动文件统计

```
src/omac/i18n.py              | +11 行
src/omac/pipeline/dispatch.py | +7 行 / -3 行
```

### 详细改动

#### 1. `src/omac/i18n.py`

**目的**: 新增 content 模式的 protocol 文案

**改动**:
```python
"work.protocol.develop_content": (
    "Use content delivery mode (no PR required). Create the deliverable "
    "file(s) as specified in the contract source_of_truth, execute all "
    "verification_commands to ensure correctness, and submit via the exact "
    "command shown below with --content-file and --verification-file. "
    "Work test-first, map every full-flow claim to a concrete business test "
    "on a successful command, and submit structured verification evidence. "
    "Deliver the complete contract without skeletons, placeholders, or "
    "production synthetic-data fallbacks; do not manually change the issue "
    "status, assignee, rerun, or cancel state."
),
```

**为什么**:
- S03 发现: Agent 收到矛盾指令 (Contract 说 content, Protocol 说 PR)
- 需要针对 content 模式的专用指令文本
- 明确告诉 agent 不需要 PR，使用 `--content-file` 提交

#### 2. `src/omac/pipeline/dispatch.py`

**目的**: 根据 `delivery_mode` 动态选择 protocol

**改动**:
```python
def _next_action(kind: TaskKind, phase: TaskPhase, language: str, contract=None) -> str:
    # ...
    if kind == TaskKind.DEVELOP and contract and is_content_delivery(contract):
        action = t("work.protocol.develop_content", language=language)
    else:
        action = t(key, language=language) if key else ""
    # ...
```

**调用点**:
```python
# 行 511
protocol = _next_action(kind, phase, language, contract=contract)
```

**为什么**:
- Protocol 文本是 agent 的关键输入
- 必须根据 contract.delivery_mode 生成正确的指令
- PR 模式和 content 模式的工作流程不同

### Protocol 修复验证结果

**测试**:
- `test_delivery_mode.py`: 7/7 通过 ✅
- `test_content_submit.py`: 5/5 通过 ✅

**真实验证**:
- S03 重试时，检查 write 节点收到的 protocol ✅
- 确认 protocol 文本已更新为 content 模式 ✅
- Agent 仍然失败 → 说明问题更深 ❌

---

## 改动原因总结

### S02 实现 (ab9d0fe)

**根本需求**: B3 实验需要 content 交付模式

**为什么不用 PR 模式**:
- 周报任务是数据传递，不是代码变更
- PR 模式太重，不适合纯内容传递
- Content 模式更直接、更快

**设计思路**:
- Submit 参数: `--content-file` 代替 `--pr-url`
- 持久化: 通过 WorkItemStore 存储 deliverable
- 传递: 下游通过 source ref 读取
- 校验: SHA-256 确保完整性

### Protocol 修复 (a605a34)

**触发原因**: S03 smoke 第一次失败

**发现问题**: 
- Contract: `delivery_mode: content`
- Protocol: "Push a branch and open a PR"
- Agent 收到矛盾指令，困惑

**修复思路**:
- 新增 content 专用 protocol 文案
- dispatch.py 根据 delivery_mode 动态选择
- 保持 PR 模式向后兼容

---

## 测试覆盖情况

### Mock 测试 (全部通过)

| 测试文件 | 用例数 | 状态 | 覆盖内容 |
|---------|--------|------|---------|
| test_content_submit.py | 12 | ✅ | Content 完整流程 |
| test_delivery_mode.py | 7 | ✅ | Delivery mode 路由 |

### 基线回归测试

- 基线 (4f1773d): 10 个失败
- S02 后: 9 个失败
- **对比**: 零新增，修复 1 个 ✅

### 真实集成测试 (失败)

| 测试 | 节点 | 结果 | 错误 |
|-----|------|------|------|
| S03 第一次 | collect | ❌ | evidence gate: verification is required |
| S03 修复后 | write | ❌ | evidence gate: verification is required |

**结论**: Mock 通过但真实集成失败，说明问题在实际执行流程或 evidence gate 验证逻辑。

---

## 未修改的部分

### 保持不变
- `src/omac/pipeline/loop.py` - 虽然 GPT 改了，但没有提交 (可能不需要)
- `src/omac/engines/store.py` - WorkItemStore 接口没改
- `src/omac/engines/multica.py` - Multica adapter 没改 (已有 deliverable 支持)

### 为什么不改
- WorkItemStore 和 Multica adapter 已经有 deliverable 的基础设施
- S02 复用了现有接口，不需要改动
- 保持改动最小化，降低风险

---

## Diff 统计

### ab9d0fe
```
5 files changed, 358 insertions(+), 13 deletions(-)
- src/omac/cli/commands/work.py
- src/omac/core/delivery.py
- src/omac/engines/mock.py
- src/omac/pipeline/dispatch.py
- tests/test_content_submit.py (new)
```

### a605a34
```
2 files changed, 18 insertions(+), 3 deletions(-)
- src/omac/i18n.py
- src/omac/pipeline/dispatch.py
```

### 总计
```
7 files changed, 376 insertions(+), 16 deletions(-)
```

---

## 与 Evidence 文档的对应

- S02 验收: `s02-gate-verdict.md`
- 基线测试: `baseline-4f1773d.txt`, `after-s02.txt`
- Protocol 修复: `s02-fix-plan.md`
- S03 失败: `smoke/s03-final-result.md`, `smoke/s03-retry-failed.md`
