# S03 Desktop Smoke 执行计划

> 日期: 2026-08-19  
> 前置: S02 PASS (commit ab9d0fe)  
> 状态: 待执行

## 目标

验证 Desktop daemon 能够实际调用 OMAC,完成 content deliverable 跨节点传递,为 S04 正式样本建立信心。

**关键**: 这是**非计量 smoke**,不占用四个正式样本槽,不计入 B3 结果数据。

## Smoke 验收标准 (4 项断言)

| # | 断言 | 证据要求 |
|---|------|----------|
| 1 | Desktop daemon 实际调用目标 OMAC 版本 (ab9d0fe) | run log 显示 omac 版本,workdir 中 `git log` 输出 |
| 2 | 独立 workdir checkout 到冻结 learnezvibe revision (4ae97c9) | workdir 中 `git rev-parse HEAD` 输出 |
| 3 | Fixture 文件 SHA-256 与冻结合同一致 | 四个文件的 `Get-FileHash` 输出,aggregate digest 计算 |
| 4 | content deliverable 跨节点真实传递成功 | collect 产出 SHA-256 = write 输入 SHA-256,且 ref 可解析 |

## 前置检查 (在创建 smoke issue 前执行)

### 环境检查
```bash
# 1. 确认 Desktop daemon 存活
multica daemon status
# 期待: running 或 active

# 2. 确认 CLI daemon 保持 stopped
# 不执行 multica daemon start (CLI)
# 不混用两套 daemon

# 3. 确认 agent 可用
multica issue list --limit 1
# 能返回结果即可
```

### 配置检查
```bash
# 1. 确认 weekly.yaml 三角色映射
cd D:\agentlearn\learnezvibe
python -c "import yaml; p=yaml.safe_load(open('.omac/weekly.yaml', encoding='utf-8')); print([(n['id'], n['worker'], n.get('reviewer')) for n in p['nodes']])"
# 期待: [('collect', 'weekly-collect', None), ('write', 'weekly-write', None), ('review', 'weekly-review', None)]

# 2. 确认 OMAC 版本
cd D:\agentlearn\oh-my-multica
git log --oneline -1
# 期待: ab9d0fe feat(content): S02 content 交付前置实现

# 3. 确认 weekly-collect, weekly-write, weekly-review 三个 agent 存在
multica agent list | grep -E "weekly-collect|weekly-write|weekly-review"
```

## Smoke Issue 创建

### Issue 标题
```
[B3-SMOKE 非计量] weekly content 跨节点传递验证
```

### Issue 描述模板
```markdown
> **非计量 smoke**: 本 issue 用于 B3 S03 前置验证,不计入正式样本,不占用 Native-01/OMAC-01/Native-02/OMAC-02 槽位。

请完成一条三阶段周报流程 (content 交付模式验证):

1. collect: 收集并整理本周数据,产出 weekly-data.md
2. write: 基于 weekly-data.md 生成 weekly-report.md  
3. review: 检查 weekly-report.md 的准确性和结构

依赖关系: collect -> write -> review

验收标准:
- weekly-data.md 存在且内容有效
- weekly-report.md 存在且包含"本周进展"和"下周计划"
- write 使用 collect 的产物
- review 检查 write 的产物

---

**OMAC 控制**: 本 issue 由 OMAC 引擎编排

manifest: `.omac/weekly.yaml`

fixture: 
- 交接信-新session.md
- 项目总纲-Multica工作流引擎.md
- Evidence/B1卡点清单.md
- Evidence/B2验收记录.md

(请在创建时以附件形式添加这四个文件)
```

### 创建步骤

1. **准备 fixture 附件**
   ```bash
   cd D:\agentlearn\learnezvibe
   # 验证四个文件存在且哈希匹配
   Get-FileHash -Algorithm SHA256 "交接信-新session.md"
   Get-FileHash -Algorithm SHA256 "项目总纲-Multica工作流引擎.md"
   Get-FileHash -Algorithm SHA256 "Evidence/B1卡点清单.md"
   Get-FileHash -Algorithm SHA256 "Evidence/B2验收记录.md"
   ```

2. **通过 Desktop 平台创建 issue**
   - 打开 Multica Desktop
   - 创建新 issue,标题和描述如上
   - 添加四个 fixture 文件作为附件
   - 指派给 workspace 的"周报" squad 或直接指派给有 OMAC 编排权限的 agent
   - 记录 issue ID (例如 WEEK-10)

3. **启动并观察**
   - 让 Desktop daemon 自动派发
   - 观察三个节点依次执行
   - 不要人工干预或修改 WEEK-9

## 证据采集 (在 smoke 完成或失败后执行)

创建目录:
```bash
mkdir -p D:\agentlearn\learnezvibe\Evidence\B3\smoke
```

### 采集项清单

1. **Issue 基本信息**
   ```bash
   multica issue show <smoke-issue-id> --output json > Evidence/B3/smoke/issue.json
   ```

2. **Run lineage**
   ```bash
   multica run list --issue <smoke-issue-id> --output json > Evidence/B3/smoke/runs.json
   ```

3. **每个 run 的详细信息**
   ```bash
   # 对每个 run id:
   multica run show <run-id> --output json > Evidence/B3/smoke/run-<node>.json
   ```

4. **Usage 数据** (如果可采集)
   ```bash
   multica issue usage <smoke-issue-id> --output json > Evidence/B3/smoke/usage.json
   ```

5. **产物哈希验证**
   - collect 产出 weekly-data.md 的 SHA-256
   - write 输入 source ref 的 SHA-256
   - write 产出 weekly-report.md 的 SHA-256
   - review 输入 source ref 的 SHA-256

6. **Workdir 验证截图**
   - collect workdir 的 `git log --oneline -1` 输出
   - write workdir 的 `git log --oneline -1` 输出
   - review workdir 的 `git log --oneline -1` 输出
   - 任一 workdir 的 fixture 文件哈希验证

7. **OMAC 版本验证**
   - 从 run log 或 agent 输出中提取 omac 版本信息
   - 如果有 `omac --version` 输出,保存

## 四项断言验证

创建验证记录:
```bash
D:\agentlearn\learnezvibe\Evidence\B3\smoke\verification.md
```

验证模板:
```markdown
# S03 Smoke 四项断言验证

Issue ID: <smoke-issue-id>
执行时间: <start> - <end>
结果: <success|failed>

## 断言 1: Desktop daemon 调用目标 OMAC 版本
- [ ] workdir git log 显示 ab9d0fe 或更新
- [ ] omac --version 或等效输出包含预期版本
- 证据: <文件路径或截图>

## 断言 2: checkout 到冻结 learnezvibe revision
- [ ] workdir `git rev-parse HEAD` = 4ae97c92...
- 证据: <文件路径>

## 断言 3: Fixture 文件 SHA-256 一致
- [ ] 交接信-新session.md: a3553b02ce6ad7de19aa9bab379b5568cb822abfeed1b094ccd6876be0997271
- [ ] 项目总纲-Multica工作流引擎.md: 17c5cb0d368aa935fd18d4922ce5a516f318ee8b6e8277a4a3194036e004cde2
- [ ] Evidence/B1卡点清单.md: 40cb15e9ba79f737bd9b549deed03f421d449a30dee7f585b580b0db07b26a48
- [ ] Evidence/B2验收记录.md: 9d744387dc9ddbf93de3814bd27794c325568e1e575e6831f78e968ce627819c
- 证据: <哈希计算输出>

## 断言 4: content deliverable 跨节点传递成功
- [ ] collect 产出 SHA-256: <hash>
- [ ] write 输入 ref 解析 SHA-256: <hash>
- [ ] 两者相等: <yes|no>
- [ ] write 产出 SHA-256: <hash>
- [ ] review 输入 ref 解析 SHA-256: <hash>
- [ ] 两者相等: <yes|no>
- 证据: <文件路径>

## S03 Gate 判定
- [ ] 四项断言全部通过
- [ ] 原始证据完整保存
- [ ] CLI daemon 未启动
- [ ] 未修改 WEEK-9

结论: <PASS|FAIL>
```

## S03 Gate 决策

### PASS 条件
- 四项断言全部通过
- 原始 issue/run/usage/timestamp 证据齐全
- 未使用 WEEK-9 或既有取消 run
- CLI daemon 保持 stopped

### FAIL 处理
如果任何断言失败:
1. 记录失败原因和完整证据
2. 判断是 S02 实现问题还是环境问题
3. 如果是 S02 问题,返回修复
4. 如果是环境问题,记录在排障手册
5. 修复后重新执行 smoke (新 issue)

### PASS 后续
S03 PASS → 可以进入 S04 正式样本:
1. 更新 B3 计划状态
2. 准备 S04 执行环境
3. 串行执行四个正式样本: Native-01 → OMAC-01 → Native-02 → OMAC-02

## 注意事项

1. **禁止事项**
   - ❌ 不要修改 WEEK-9
   - ❌ 不要修改 squad/agent 配置
   - ❌ 不要启动 CLI daemon
   - ❌ 不要把 smoke 数据混入 B3 正式结果
   - ❌ 不要人工搬运 deliverable 到下游 workdir

2. **时间预算**
   - 前置检查: 10 分钟
   - Smoke 执行: 15-30 分钟 (等待 agent 完成)
   - 证据采集: 15 分钟
   - 验证记录: 10 分钟
   - **总计**: 约 1 小时

3. **失败预案**
   - 如果 collect 节点失败: 检查 fixture 是否正确注入
   - 如果 write 读取失败: 检查 deliverable ref 是否持久化
   - 如果 review 调用两次: 检查 weekly.yaml reviewer 配置
   - 如果 Desktop 不派发: 检查 daemon 状态和 agent 可用性

## 交付物

S03 完成后在 `Evidence/B3/smoke/` 下应有:
- issue.json (smoke issue 完整信息)
- runs.json (run lineage)
- run-*.json (每个 run 的详细信息)
- usage.json (token 使用,如可采集)
- verification.md (四项断言验证记录)
- artifacts/ (产物哈希和 ref 证据)
- workdir-snapshots/ (git log/fixture 验证截图)

验证完成后更新:
- `Evidence/B3/s03-smoke-result.md` (smoke 执行总结)
- `plan/B3计划.md` (S03 状态更新为 PASS)
