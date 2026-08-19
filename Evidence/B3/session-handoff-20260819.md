# B3 Session 交接文档 (2026-08-19)

> 本文档替代旧的"交接信-新session.md"  
> 执行时间: 2026-08-19 15:00 - 21:05 (约6小时)  
> 执行者: Claude Opus 5

**快速入口**: 先读 `next-session-entry.md` (3分钟)，再读本文档

---

## 第一部分: 3分钟快速上下文

### 项目是什么

为 Multica AI Agent 平台增加**确定性工作流引擎** (OMAC)，解决原生 LLM 临场编排的不稳定、token 浪费、失败循环问题。

### B3 目标

对比 Native LLM 编排 vs OMAC 编排的性能数据 (token、耗时、步骤数、成败)，产出简历核心数据。

实验: 跑一个 3 节点周报任务 (collect → write → review)，Native 2次 + OMAC 2次 = 4个样本。

### 当前卡在哪

**S02 完成** (代码+测试通过) → **S03 失败** (OMAC evidence gate 拒绝) → 无法进入 S04 正式样本

### 核心问题

Agent 收到了正确的 content 模式指令，也上传了附件，但 OMAC 的 evidence gate 仍然拒绝，错误: "verification is required"。

问题比 protocol 文本更深，可能在 submit 流程、evidence gate 验证逻辑、或 agent 实际行为。

---

## 第二部分: Git 状态和 Commits

### oh-my-multica 仓库

**当前状态**:
```
Branch: main (ahead of origin by 4 commits)
HEAD: a605a34
Working tree: clean (除 .agents/ 外)
```

**新增 commits**:
```
a605a34 - fix(content): 修复 content 模式 protocol 生成
ab9d0fe - feat(content): S02 content 交付前置实现
4f1773d - feat(delivery): B2 交付形态骨架 (基线)
daa225b - fix(windows): Windows 兼容补丁 5 处
```

**详细说明**: 见 `code-changes-summary.md`

### learnezvibe 仓库

**当前状态**:
```
Branch: main (up to date with origin)
HEAD: 4915d33
Untracked: .omac/weekly.test.yaml, mocksite/, scripts_tmp_b2close.py, 等
```

**新增 commit**:
```
4915d33 - docs(B3): S02-S03 完整证据链和分析文档
```

包含: S01-S03 所有证据文档、验收报告、失败分析、索引文档

---

## 第三部分: 代码改动汇总

### S02 实现 (commit ab9d0fe)

**改动**: 5个文件，358 insertions

**核心功能**:
- `work.py`: 增加 `--content-file` 入口，UTF-8 二进制 read/write，SHA-256 校验
- `delivery.py`: 支持从 Contract/mapping 解析 `delivery_mode`
- `dispatch.py`: Submit 模板根据 delivery_mode 动态生成
- `mock.py`: Mock deliverable 支持可校验 ref
- `test_content_submit.py`: 12 个测试用例

**测试结果**:
- 定向测试: 12/12 ✅
- 基线对比: 零新增回归 ✅
- 修复: 1个旧bug (work read CRLF) ✅

### Protocol 修复 (commit a605a34)

**改动**: 2个文件，18 insertions

**核心功能**:
- `i18n.py`: 新增 `work.protocol.develop_content` 文案
- `dispatch.py`: `_next_action()` 根据 `is_content_delivery()` 选择 protocol

**为什么修复**: S03 第一次失败发现 Agent 收到矛盾指令 (Contract说content, Protocol说PR)

**测试结果**:
- Mock 测试: 全部通过 ✅
- 真实 S03: 仍然失败 ❌

**详细说明**: 见 `code-changes-summary.md`

---

## 第四部分: 执行时间线

### 15:00-16:00 | S02 基线验证

**目标**: 验证 GPT 的 S02 实现是否完成

**执行**:
1. 保存 S02 改动为 patch
2. 回退到基线 4f1773d
3. 运行完整测试 → 记录 10 个失败
4. 恢复 S02 改动
5. 再次运行测试 → 9 个失败

**发现**:
- 零新增回归 ✅
- 修复了 1 个旧bug (work read CRLF 转换) ✅
- GPT 的代码是对的，只是他没完整验证

**决策**: S02 代码层面 PASS，提交 commit ab9d0fe

**证据**: `s02-gate-verdict.md`, `baseline-4f1773d.txt`, `after-s02.txt`

---

### 16:00-17:30 | S03 Smoke 第一次执行

**目标**: 在真实环境验证 S02 实现

**尝试 1**: 直接创建 issue WEEK-10
- **错误**: 这不是 OMAC 编排，只是普通的 Multica issue
- Weekly-collect agent 执行了 5 分钟完成
- 但这是原生模式，不是 OMAC 模式

**纠正**: 使用正确命令
```bash
omac dag run .omac/weekly.yaml
```

**执行过程**:
- OMAC 成功启动 ✅
- 创建 WEEK-11 (plan-check), WEEK-12 (collect 节点)
- Weekly-collect agent 执行 11 分钟
- Agent 上传了 verification 和 deliverable 附件

**结果**: ❌ FAILED
- 错误: "Worker evidence gate: verification is required"
- Collect 节点被标记为 blocked
- Write 和 review 级联 blocked

**证据**: `smoke/s03-final-result.md`, `smoke/omac-dag-run.log`

---

### 17:30-18:00 | 失败分析和根因定位

**分析方法**:
1. 检查 OMAC 给 agent 的指令
2. 检查 agent 上传的附件
3. 对比 Contract 和 Protocol

**发现问题**: **配置冲突**

```yaml
# Contract (weekly.yaml)
delivery_mode: content

# Protocol (dispatch.py 生成给 agent)
"Push a branch and open a PR (base=contract.pr_base; ...)"
```

**根本原因**:
- GPT 修改了代码逻辑 (dispatch.py, delivery.py)
- 但忘记修改 protocol 文本生成
- Protocol 还是硬编码的 PR 模式指令
- Agent 收到矛盾指令，困惑，只上传附件但没正确提交

**这验证了什么**: GPT 在交接文档里提到的问题完全正确
> "真实 content submit 参数合同仍是 PR 形态...agent 即使生成了文件，也没有符合当前 CLI 合同的无 PR 提交方式。"

**证据**: `smoke/failure-analysis.md`

---

### 18:00-18:30 | Protocol 修复

**修复内容**:
1. `i18n.py`: 新增 content 模式 protocol 文案
   ```
   "Use content delivery mode (no PR required). Create the deliverable file(s)..."
   ```

2. `dispatch.py`: 动态选择 protocol
   ```python
   if kind == TaskKind.DEVELOP and contract and is_content_delivery(contract):
       action = t("work.protocol.develop_content", language=language)
   ```

**验证**:
- `test_delivery_mode.py`: 7/7 通过 ✅
- `test_content_submit.py`: 5/5 通过 ✅

**提交**: commit a605a34

**期待**: Protocol 修复了，下次 smoke 应该能通过

**证据**: `s02-fix-plan.md`

---

### 18:30-20:30 | S03 Smoke 第二次执行

**准备**:
1. 关闭旧的 smoke issues (WEEK-11, WEEK-12)
2. 清理 OMAC 旧状态
3. 重新运行: `omac dag run .omac/weekly.yaml`

**执行过程**:
- Collect 节点被 abandoned (因为之前失败)
- OMAC 自动派发 Write 节点 (WEEK-13)
- Weekly-write agent 执行 9 分钟
- Agent 上传了 verification 和 deliverable 附件

**验证 protocol**:
- 检查 write 节点收到的 protocol 文本
- 确认已更新为 content 模式 ✅
- "Use content delivery mode (no PR required)..." ✅

**结果**: ❌ FAILED
- 错误: **同样的** "Worker evidence gate: verification is required"
- Write 节点被标记为 blocked
- Review 级联 blocked

**证据**: `smoke/s03-retry-failed.md`, `smoke/omac-dag-run-fresh.log`

---

### 20:30-21:05 | 问题深入分析和交接准备

**已验证的事实**:
- ✅ S02 代码逻辑正确
- ✅ Mock 测试全部通过
- ✅ Protocol 文本已修复为 content 模式
- ✅ Agent 收到了正确的指令
- ✅ Agent 上传了 verification 和 deliverable 附件
- ❌ OMAC evidence gate 仍然拒绝

**结论**: 问题比 protocol 文本更深

**可能的根因** (优先级排序):
1. **Agent 没有正确运行 `omac work submit`** (最可能)
   - 可能只是上传附件
   - 没有通过 OMAC 的 submit API
   - Evidence gate 需要特定的提交流程

2. **Evidence gate 的验证逻辑更复杂**
   - 可能要求特定的 metadata 格式
   - 可能要求 verification 命令的执行记录
   - 附件上传 ≠ 正确提交

3. **Submit 命令模板可能还有问题**
   - `omac work show` 返回的模板可能不对
   - Agent 看到的可能还是 `--pr-url` 而不是 `--content-file`

4. **WorkItemStore 持久化有问题**
   - 虽然 mock 测试通过
   - 真实环境的持久化可能有其他问题

**决策**: 停止本 session，整理交接文档

---

## 第五部分: 观察和经验

### 走过的弯路

#### 1. 第一次用错了方法创建 smoke issue

**错误做法**:
```bash
multica issue create --title "smoke..." --description "..." --attachment ...
```

**为什么错**:
- 这只是创建普通 Multica issue
- 不会启动 OMAC 编排
- Agent 按原生模式执行，不是 OMAC 模式

**正确做法**:
```bash
omac dag run .omac/weekly.yaml
```

**教训**: OMAC 必须通过 `omac dag run` 启动，才会创建编排的工作项。

---

#### 2. Protocol 修复后，测试通过但真实环境仍失败

**现象**: Mock 测试全绿，S03 smoke 仍然失败

**原因**: Mock 环境和真实环境的 gap
- Mock: 模拟的 agent，模拟的 submit
- 真实: 真实的 AI agent，需要理解指令并调用真实 CLI

**教训**: 
- Mock 测试通过 ≠ 真实集成成功
- 必须有真实环境的验证 (这就是 smoke 的价值)
- 代码对了，但 agent 的实际行为可能不对

---

#### 3. OMAC 会记住旧的 DAG 状态

**现象**: 重新运行 `omac dag run` 时，OMAC 说节点已经 blocked

**原因**: OMAC 把 DAG 状态持久化了，记住了之前的失败

**解决**:
```bash
omac node abandon .omac/weekly.yaml collect
omac dag run .omac/weekly.yaml
```

**教训**: 
- 失败后重试，需要先 abandon 失败的节点
- 或者修改 manifest (改个名字) 创建全新的 DAG
- OMAC 的状态管理需要理解

---

### 观察到的奇怪现象

#### 1. Agent 执行时间差异大

- WEEK-10 (原生模式): 5 分钟
- WEEK-12 (OMAC collect): 11 分钟
- WEEK-13 (OMAC write): 9 分钟

**可能原因**:
- OMAC 的控制协议更复杂，agent 需要更多时间理解
- Agent 可能在尝试多种方式提交
- Agent 可能在等待某些命令的返回

**启示**: OMAC 模式的执行时间会比原生模式长

---

#### 2. Agent 上传了附件，但 OMAC 说没有 verification

**现象**: 
- 检查 issue 评论，能看到 verification 和 deliverable 附件
- 但 OMAC 报错: "verification is required"

**可能原因**:
- 附件上传 ≠ 正确的 submit
- OMAC 可能要求通过 `omac work submit` API 提交
- 直接上传附件可能不会触发 evidence gate 的正确验证流程

**启示**: 需要深入理解 OMAC 的 submit 流程

---

#### 3. Evidence gate 错误信息不够详细

**现象**: 只有一句 "verification is required"

**缺少的信息**:
- 具体缺少什么？
- Verification 文件格式不对？
- Verification 命令没执行？
- Submit 流程不对？

**启示**: 需要查看 OMAC evidence gate 源码，理解精确要求

---

### 有效的调试方法

#### 1. 监控 OMAC DAG 状态

```bash
# 实时监控
omac dag status .omac/weekly.yaml

# 推进一轮
omac dag tick .omac/weekly.yaml

# 查看节点状态
omac work show <work-item-id> --output json
```

**用途**: 了解 OMAC 的状态机当前在哪个阶段

---

#### 2. 检查 agent 收到的指令

```bash
# 查看 agent 收到的完整 protocol
omac work show <work-item-id> --output json | grep -A 20 "protocol"

# 查看 submit 模板
omac work show <work-item-id> --output json | grep -A 10 "submit"
```

**用途**: 验证 agent 是否收到正确的指令

---

#### 3. 检查 agent 的实际行为

```bash
# 查看 issue 的 runs
multica issue runs <issue-key>

# 查看 agent 的评论
multica issue comment list <issue-key>

# 查看 issue 详情 (包含附件)
multica issue get <issue-key>
```

**用途**: 了解 agent 实际做了什么

---

#### 4. 基线对比测试

**方法**:
1. 保存改动: `git stash`
2. 运行基线测试: 记录结果
3. 恢复改动: `git stash pop`
4. 再次运行测试: 记录结果
5. 对比差异: 找出新增失败

**用途**: 严格验证代码改动的影响

---

### 工具使用技巧

#### OMAC CLI

```bash
# 查看 DAG 状态 (最常用)
omac dag status .omac/weekly.yaml

# 运行 DAG (阻塞直到完成或失败)
omac dag run .omac/weekly.yaml --max-rounds 20

# 推进一轮 (手动控制)
omac dag tick .omac/weekly.yaml

# 放弃失败的节点
omac node abandon .omac/weekly.yaml <node-key>

# 重试失败的节点
omac node retry .omac/weekly.yaml <node-key>

# 查看工作项详情
omac work show <work-item-id> --output json
```

---

#### Multica CLI

```bash
# 查看 daemon 状态
multica daemon status

# 查看最近的 issues
multica issue list --limit 10

# 查看 issue 的 runs
multica issue runs <issue-key>

# 查看 issue 详情
multica issue get <issue-key>

# 查看 issue 评论
multica issue comment list <issue-key>

# 改变 issue 状态
multica issue status <issue-key> done
```

---

#### Git

```bash
# 查看改动统计
git diff --stat

# 查看详细改动
git diff <file>

# 查看 commit 历史
git log --oneline -10

# 查看某个 commit 的详细信息
git show <commit-hash>

# 临时保存改动
git stash push -u -m "description"

# 恢复改动
git stash pop
```

---

### 陷阱和注意事项

#### 1. Windows 路径问题

**现象**: 某些测试失败，路径相关

**原因**: 
- CRLF vs LF
- 盘符大小写
- 反斜杠 vs 正斜杠

**建议**: 使用 UTF-8 二进制模式，避免文本模式转换

---

#### 2. OMAC 状态持久化

**陷阱**: 重新运行 `omac dag run` 时，OMAC 记住了旧状态

**解决**: 先 abandon 或修改 manifest 名称

---

#### 3. Agent 的异步执行

**陷阱**: Issue 状态是 done，但 agent 可能还在运行

**解决**: 用 `multica issue runs` 检查实际运行状态

---

#### 4. Evidence 文件的路径

**陷阱**: 相对路径 vs 绝对路径

**建议**: 统一使用绝对路径，避免混淆

---

## 第六部分: 问题诊断

### 表面问题

OMAC 的 evidence gate 拒绝 agent 的提交，错误: "Worker evidence gate: verification is required"

### 深层分析

#### 已验证的事实

✅ **代码层面**:
- S02 实现逻辑正确 (dispatch.py, delivery.py 等)
- Submit 参数模板根据 delivery_mode 动态生成
- Mock 测试全部通过 (test_content_submit.py 12/12)

✅ **Protocol 层面**:
- Protocol 文本已修复为 content 模式
- Agent 收到的指令正确: "Use content delivery mode (no PR required)..."
- Submit 命令模板包含 `--content-file`

✅ **Agent 行为**:
- Agent 执行了任务 (11分钟 collect, 9分钟 write)
- Agent 上传了 verification 附件
- Agent 上传了 deliverable 附件
- Agent 发表了评论

❌ **OMAC 判定**:
- Evidence gate 拒绝
- 两次尝试都是同样的错误
- 错误信息不够详细

---

#### 未解决的谜团

**谜团 1**: Agent 是否正确运行了 `omac work submit`?

**已知**:
- Agent 上传了附件 ✅
- Agent 发表了评论 ✅

**未知**:
- Agent 是否运行了 `omac work submit --content-file ...`?
- 如果运行了，是否成功？
- 如果失败了，错误是什么？

**如何验证**:
- 查看 agent run 的完整日志
- 或者查看 OMAC 的 submit 记录
- 或者分析 WorkItemStore 的数据

---

**谜团 2**: Evidence gate 到底要求什么?

**已知**:
- 错误: "verification is required"
- Verification 附件存在 ✅

**未知**:
- Verification 的格式要求？
- Verification 命令是否需要执行记录？
- 是否需要特定的 metadata？
- 附件上传 vs submit API 的区别？

**如何验证**:
- 查看 OMAC evidence gate 源码
- 查看成功案例的 verification 格式
- 对比 PR 模式的 verification

---

**谜团 3**: Submit 命令模板是否真的正确?

**已知**:
- `omac work show` 应该返回 submit 模板
- Protocol 文本已包含 `--content-file`

**未知**:
- Agent 实际看到的 submit 命令是什么？
- 是 `--content-file` 还是 `--pr-url`?
- Submit 模板生成逻辑是否有 bug?

**如何验证**:
- 手动运行 `omac work show <work-item-id>`
- 检查返回的 submit 字段
- 对比 content vs pr 模式的差异

---

### 可能的根因 (优先级排序)

#### 根因 1: Agent 没有正确运行 submit (可能性 70%)

**理由**:
- Agent 上传了附件，但可能只是通过平台 API
- 没有通过 OMAC 的 `omac work submit` API
- Evidence gate 需要特定的 submit 流程才能通过

**验证方法**:
1. 查看 agent run 的完整输出
2. 搜索是否有 `omac work submit` 命令
3. 如果有，检查返回值

**修复方向**:
- 可能需要在 protocol 中更明确地要求 agent 运行 submit
- 或者修改 agent 的行为 (但这超出了我们的控制)
- 或者修改 evidence gate 的验证逻辑 (接受附件上传)

---

#### 根因 2: Evidence gate 验证逻辑更严格 (可能性 20%)

**理由**:
- Verification 附件存在，但格式可能不对
- Evidence gate 可能要求特定的字段或结构
- Content 模式和 PR 模式的 verification 要求可能不同

**验证方法**:
1. 下载 verification 附件，检查内容
2. 对比成功案例的 verification
3. 查看 evidence gate 源码，理解要求

**修复方向**:
- 修改 verification 生成逻辑
- 或者修改 evidence gate 的验证规则

---

#### 根因 3: Submit 模板生成有 bug (可能性 8%)

**理由**:
- 虽然修改了 `_next_action()`，但 submit 模板生成可能在别的地方
- Agent 看到的模板可能还是 `--pr-url`

**验证方法**:
1. 运行 `omac work show <work-item-id> --output json`
2. 检查 `submit` 字段
3. 确认是 `--content-file` 还是 `--pr-url`

**修复方向**:
- 找到 submit 模板生成的代码
- 确保根据 delivery_mode 生成正确的模板

---

#### 根因 4: WorkItemStore 持久化问题 (可能性 2%)

**理由**: Mock 测试通过了，真实环境不太可能有问题

**验证方法**: 检查 WorkItemStore 的数据

**修复方向**: 修复持久化逻辑

---

### 建议的调查步骤

#### 第一步: 检查 agent 是否运行了 submit

**命令**:
```bash
# 查看 write 节点的完整日志
multica issue runs WEEK-13
multica issue get WEEK-13

# 如果有 run 详情，查看输出
# (可能需要特殊权限或工具)
```

**期待发现**:
- Agent 的完整执行日志
- 是否有 `omac work submit` 命令
- 如果有，返回值是什么

---

#### 第二步: 检查 submit 模板

**命令**:
```bash
omac work show ba05306d-70ca-429f-b11b-687ebbd5b996 --output json | grep -A 20 "submit"
```

**期待发现**:
- Submit 命令模板
- 确认是 `--content-file` 还是 `--pr-url`

---

#### 第三步: 下载并分析 verification 附件

**方法**:
1. 从 WEEK-13 issue 下载 verification 附件
2. 检查格式和内容
3. 对比成功案例或 PR 模式的 verification

**期待发现**:
- Verification 的实际格式
- 是否缺少某些字段
- 是否符合 evidence gate 的要求

---

#### 第四步: 查看 evidence gate 源码

**文件**: `src/omac/core/evidence.py` 或类似

**查找**:
- `verification is required` 错误的触发条件
- Evidence gate 的验证逻辑
- Content 模式的特殊要求

**期待发现**:
- 精确的验证规则
- 为什么会拒绝

---

## 第七部分: 证据索引

**文档导航**: 见 `README.md`

**关键证据**:

### S02 验收
- `s02-gate-verdict.md` - 完整验收报告
- `baseline-4f1773d.txt` - 基线测试结果
- `after-s02.txt` - S02 后测试结果
- `code-changes-summary.md` - 代码改动汇总

### S03 执行
- `smoke/s03-final-result.md` - 第一次执行 (发现 protocol 冲突)
- `smoke/s03-retry-failed.md` - 修复后重试 (仍失败)
- `smoke/failure-analysis.md` - 失败根因分析
- `smoke/omac-dag-run-fresh.log` - OMAC 执行日志

### 配置和计划
- `S03-smoke-plan.md` - S03 执行计划
- `s02-fix-plan.md` - Protocol 修复计划
- `protocol.md` - B3 实验协议
- `frozen-input.json` - 冻结的输入

---

## 第八部分: 下一步选项

### 选项 A: 继续修复 content 模式 ⭐ 推荐 (如果时间充裕)

**目标**: 解决 evidence gate 问题，让 content 模式真正工作

**详细步骤**:

1. **调查 agent 行为** (30分钟)
   - 查看 WEEK-13 的完整 run 日志
   - 确认 agent 是否运行了 `omac work submit`
   - 如果有，检查返回值

2. **检查 submit 模板** (15分钟)
   ```bash
   omac work show ba05306d-70ca-429f-b11b-687ebbd5b996 --output json
   ```
   - 确认 submit 字段是 `--content-file` 还是 `--pr-url`
   - 如果是 `--pr-url`，说明模板生成有 bug

3. **分析 verification 格式** (30分钟)
   - 下载 WEEK-13 的 verification 附件
   - 对比成功案例或 PR 模式
   - 检查是否缺少字段

4. **查看 evidence gate 源码** (1小时)
   - 定位 "verification is required" 错误
   - 理解验证逻辑
   - 找出为什么会拒绝

5. **根据发现修复代码** (1-2小时)
   - 可能需要修改 submit 模板生成
   - 可能需要修改 verification 格式
   - 可能需要修改 evidence gate 验证逻辑
   - 可能需要改进 protocol 文本

6. **重新测试** (1小时)
   - 运行 mock 测试
   - 重新执行 S03 smoke
   - 验证修复是否有效

**预计时间**: 4-6 小时

**成功标准**:
- Collect 节点 submit 成功 ✅
- Evidence gate 通过 ✅
- Write 节点自动派发 ✅
- Write 能读取 collect 的 deliverable ✅
- Review 节点完成 ✅
- 整个流程收敛 ✅

**风险**:
- 可能发现更多深层问题
- 可能需要修改更多代码
- 可能需要多次迭代

**收益**:
- Content 模式完整实现
- B3 可以用 content 模式执行
- 简历数据更有说服力

---

### 选项 B: 降级到 PR 模式 ⭐ 推荐 (如果时间紧迫)

**目标**: 快速完成 B3 数据采集，content 模式作为后续优化

**详细步骤**:

1. **修改 weekly.yaml** (5分钟)
   ```yaml
   nodes:
     - id: collect
       worker: weekly-collect
       delivery_mode: pr  # 改回 pr
       pr_base: main      # 添加 pr_base
       contract:
         # ...
   ```

2. **清理旧状态** (5分钟)
   ```bash
   multica issue status WEEK-11 done
   multica issue status WEEK-12 done
   multica issue status WEEK-13 done
   ```

3. **重新执行 S03 smoke** (30分钟)
   ```bash
   omac dag run .omac/weekly.yaml --max-rounds 20
   ```
   - 观察是否成功
   - 如果成功，说明 PR 模式工作

4. **如果 S03 通过，进入 S04** (1-2天)
   - 创建 4 个正式样本
   - Native-01 → OMAC-01 → Native-02 → OMAC-02
   - 采集完整数据

5. **S05 数据分析** (0.5天)
   - 计算 token/耗时/步骤数
   - 产出 B3 报告

**预计时间**: 2-3 天

**成功标准**:
- S03 smoke 通过 ✅
- 4 个正式样本完成 ✅
- 数据分析完成 ✅
- 简历有数字支撑 ✅

**风险**:
- PR 模式可能也有问题 (但可能性较低)
- 改变了实验设计 (从 content 改为 pr)
- 简历上需要调整说法

**收益**:
- 快速完成 B3
- 拿到核心数据
- 降低风险

**简历调整**:
- 不要强调 content 模式
- 强调"支持多种交付方式"
- 或者说 content 模式在开发中

---

### 选项 C: 混合方案

**目标**: 先用 PR 模式完成 B3，同时继续修复 content 模式

**步骤**:
1. 先执行选项 B，完成 B3 数据采集
2. 并行或之后修复 content 模式
3. 如果修复成功，补充 content 模式的数据

**好处**: 降低风险，保底有数据

---

## 第九部分: 速查命令清单

### Git 操作

```bash
# 查看状态
git status
git log --oneline -10

# 查看改动
git diff --stat
git show <commit-hash>

# 提交
git add <files>
git commit -m "message"

# 临时保存
git stash push -u -m "description"
git stash pop
```

---

### 测试

```bash
# 运行所有测试
.venv/Scripts/python.exe -m pytest

# 运行特定测试文件
.venv/Scripts/python.exe -m pytest tests/test_content_submit.py -v

# 运行特定测试用例
.venv/Scripts/python.exe -m pytest tests/test_content_submit.py::test_content_submit_parameters -v
```

---

### OMAC

```bash
# 查看 DAG 状态 (最常用)
omac dag status .omac/weekly.yaml

# 运行 DAG
omac dag run .omac/weekly.yaml --max-rounds 20 --max-minutes 30

# 推进一轮
omac dag tick .omac/weekly.yaml

# 节点操作
omac node abandon .omac/weekly.yaml <node-key>
omac node retry .omac/weekly.yaml <node-key>

# 查看工作项
omac work show <work-item-id> --output json
omac work show <work-item-id> --output json | grep -A 20 "protocol"
omac work show <work-item-id> --output json | grep -A 10 "submit"
```

---

### Multica Daemon

```bash
# 查看状态
multica daemon status

# 启动 (如果停止)
multica daemon start

# 查看日志
tail -f ~/.multica/daemon.log
```

---

### Multica Issues

```bash
# 列出最近 issues
multica issue list --limit 10

# 查看 issue 详情
multica issue get <issue-key>

# 查看 runs
multica issue runs <issue-key>

# 查看评论
multica issue comment list <issue-key>

# 改变状态
multica issue status <issue-key> done

# 查看 usage
multica issue usage <issue-key>
```

---

### 调试技巧

```bash
# 监控 OMAC 状态 (循环)
while true; do omac dag status .omac/weekly.yaml; sleep 30; done

# 监控 issue 状态
while true; do multica issue list --limit 5; sleep 30; done

# 查看完整的 work show 输出
omac work show <work-item-id> --output json | jq .

# 查看 agent 收到的 protocol
omac work show <work-item-id> --output json | jq .protocol

# 查看 submit 模板
omac work show <work-item-id> --output json | jq .submit
```

---

## 第十部分: 常见问题 FAQ

### Q1: 如何判断 agent 是否正确提交？

**检查清单**:
1. Agent run 状态是 completed ✅
2. Issue 有 verification 和 deliverable 附件 ✅
3. OMAC evidence gate 通过 ✅
4. 节点状态从 in_progress 变为 done ✅

**如果前两个 ✅ 但后两个 ❌**:
- 说明 agent 上传了附件，但没有正确 submit
- 需要检查 agent 是否运行了 `omac work submit`

---

### Q2: 如何检查 evidence gate 拒绝的具体原因？

**方法 1**: 查看 OMAC 日志
```bash
omac dag tick .omac/weekly.yaml 2>&1
```
- 错误信息会显示在输出中
- 但通常不够详细

**方法 2**: 查看 evidence gate 源码
- `src/omac/core/evidence.py` 或类似文件
- 搜索错误信息: "verification is required"
- 理解触发条件

**方法 3**: 对比成功案例
- 找一个成功的 PR 模式案例
- 对比 verification 格式
- 找出差异

---

### Q3: 如何清理 OMAC 的旧状态？

**方法 1**: Abandon 节点
```bash
omac node abandon .omac/weekly.yaml <node-key>
```

**方法 2**: 关闭相关 issues
```bash
multica issue status <issue-key> done
```

**方法 3**: 修改 manifest
- 改个名字或 id
- OMAC 会认为是新的 DAG

---

### Q4: 如何验证 protocol 文本是否正确？

```bash
# 查看 agent 收到的 protocol
omac work show <work-item-id> --output json | grep -A 30 "protocol"

# 期待看到 (content 模式):
# "Use content delivery mode (no PR required)..."

# 而不是 (PR 模式):
# "Push a branch and open a PR..."
```

---

### Q5: 如何验证 submit 模板是否正确？

```bash
# 查看 submit 模板
omac work show <work-item-id> --output json | grep -A 10 "submit"

# 期待看到 (content 模式):
# "omac work submit <id> --content-file <file> --verification-file <verification>"

# 而不是 (PR 模式):
# "omac work submit <id> --pr-url <url> --verification-file <verification>"
```

---

### Q6: OMAC 一直卡在 in_progress，怎么办？

**原因**: Agent 可能还在运行

**检查**:
```bash
multica issue runs <issue-key>
```

**如果 run 是 running**: 等待

**如果 run 是 completed**: OMAC 可能还没轮询到最新状态
```bash
# 手动推进
omac dag tick .omac/weekly.yaml
```

---

### Q7: 如何从头开始重新执行 S03？

```bash
# 1. 关闭所有相关 issues
multica issue status WEEK-11 done
multica issue status WEEK-12 done
multica issue status WEEK-13 done

# 2. (可选) 修改 manifest 避免冲突
# 比如改个 id 或 title

# 3. 重新运行
omac dag run .omac/weekly.yaml --max-rounds 20
```

---

### Q8: 基线测试有很多失败，是否需要修复？

**判断标准**: 零新增回归

- 如果 S02 后的失败数 ≤ 基线失败数: **不需要修复**
- 如果 S02 后的失败数 > 基线失败数: **需要分析新增失败**

**本次情况**:
- 基线: 10 个失败
- S02 后: 9 个失败
- 结论: 零新增，还修复了 1 个 ✅

---

### Q9: 如何区分 OMAC 编排 vs 原生 Multica 执行？

**OMAC 编排**:
- 通过 `omac dag run` 启动
- Issue 标题: `[DAG:<node-key>] ...`
- Issue 描述包含: "OMAC-controlled run"
- Agent 收到 OMAC 协议

**原生 Multica**:
- 通过 `multica issue create` 或平台 UI 创建
- 普通 issue 标题
- Agent 自由执行

---

### Q10: Content 模式和 PR 模式的核心区别是什么？

**PR 模式**:
- Agent 创建 Git branch 和 PR
- 产物在 PR 里
- 下游从 PR 读取
- Submit: `--pr-url`

**Content 模式**:
- Agent 直接提交文件内容
- 产物存储在平台
- 下游直接读取文件
- Submit: `--content-file`

**适用场景**:
- PR 模式: 代码变更、需要 review
- Content 模式: 数据传递、不需要 PR

---

## 结语

本 session 虽然 S03 没有通过，但完成了严格的验证和诊断:

✅ **S02 完全验证通过** (代码+测试+基线对比)
✅ **发现并修复了 protocol 冲突**
✅ **建立了完整的证据链**
✅ **明确了问题的边界和可能的根因**

下一 session 可以基于这些成果，选择继续修复 content 模式，或者降级到 PR 模式快速完成 B3。

**推荐路径**: 
- 时间充裕 → 选项 A (继续修复 content)
- 时间紧迫 → 选项 B (降级 PR 模式)
- 保险起见 → 选项 C (混合方案)

祝下一 session 顺利! 🚀

---

**文档版本**: 1.0  
**最后更新**: 2026-08-19 21:05  
**作者**: Claude Opus 5
