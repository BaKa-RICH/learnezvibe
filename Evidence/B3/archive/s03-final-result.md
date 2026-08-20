# S03 Smoke 最终结果

> 执行日期: 2026-08-19  
> 判定: **FAIL** - 发现 S02 真实集成问题  
> 决策: 停止 S03,修复 S02 后重新执行

## 执行概况

### 启动方式
通过 `omac dag run .omac/weekly.yaml` 正确启动 OMAC 编排。

### 创建的 Issues
- WEEK-11: [DAG:plan-check] - OMAC 内部检查
- WEEK-12: [DAG:collect] collect - 业务节点

### Collect 节点执行
- Work Item ID: c382fcfb-b623-4b7d-b7c0-dd48621e90fd
- Agent: weekly-collect
- Run ID: 62a4df67
- 开始时间: 2026-08-19T12:26
- 完成时间: 2026-08-19T12:37
- 耗时: 11 分钟
- Agent 状态: **completed**
- Agent 行为:
  - ✅ 上传了 verification 附件 (omac-verification-ffdb85d2d053.yaml, 1141 bytes)
  - ✅ 上传了 deliverable 附件
  - ✅ 发表了评论

### OMAC 验收结果
- **判定: FAILED**
- 错误: `node_failed: Worker evidence gate: verification is required`
- 级联影响: collect/write/review 全部 blocked
- Exit code: 20 (需要人工决策)

## 失败原因

### 直接原因
OMAC 的 evidence gate 检查失败,认为 verification 不符合要求。

### 根本原因: 配置冲突

**Contract 与 Protocol 不一致**:

```yaml
# Contract (来自 weekly.yaml)
delivery_mode: content  # 不需要 PR
```

```text
# Protocol (由 dispatch.py 生成)
"Push a branch and open a PR (base=contract.pr_base; the worker creates it, OMAC does not)."
```

这导致 weekly-collect agent 收到矛盾指令:
- Contract 明确说用 content 模式
- Protocol 仍然要求开 PR

Agent 最终只上传了附件,但可能:
1. 没有正确执行 `omac work submit`
2. 或者执行了但参数不对(用了 PR 参数而不是 content 参数)
3. 导致 OMAC 认为验收未通过

### 这验证了什么

**B3 开工前检查文档的硬阻塞 #1 完全正确**:

> "真实 content submit 参数合同仍是 PR 形态...
> 影响：真实 content agent 即使生成 `weekly-data.md`，也没有符合当前 CLI 合同的无 PR 提交方式。
> B2 只改了 lint/evidence/loop/mock 策略，未打通真实 authoring submit。"

**S02 状态评估修正**:
- S02 代码实现: ✅ PASS (dispatch.py, delivery.py 等支持 content)
- S02 Mock 测试: ✅ PASS (test_content_submit.py 12/12)
- S02 真实集成: ❌ **FAIL** (Agent 不知道如何在实际任务中使用)
- **S02 综合判定: PARTIAL PASS** (代码完成但集成未完成)

## S03 四项断言验证结果

| # | 断言 | 结果 | 证据 |
|---|------|------|------|
| 1 | Desktop daemon 调用目标 OMAC 版本 | ✅ PASS | OMAC 1.0.0 成功启动编排 |
| 2 | checkout 到冻结 learnezvibe revision | 未验证 | Collect 节点失败,未到达验证点 |
| 3 | Fixture 文件 SHA-256 一致 | 未验证 | Collect 节点失败,未到达验证点 |
| 4 | content deliverable 跨节点传递成功 | ❌ FAIL | Collect 节点提交失败,无法传递到 write |

**S03 Gate 判定: FAIL**

## 已采集的证据

所有证据保存在 `Evidence/B3/smoke/`:
- `issue-description.md` - Smoke issue 描述
- `issue-create-result.json` - WEEK-10 创建记录(错误尝试)
- `omac-dag-run.log` - OMAC 编排启动日志
- `progress-report.md` - 执行进度报告
- `current-situation.md` - 问题发现记录
- `failure-analysis.md` - 详细失败分析
- `s03-final-result.md` - 本文档

OMAC 状态快照:
```
omac dag status .omac/weekly.yaml
Progress: 0/3 done (running 1, todo 2, blocked 0, failed 0, abandoned 0)
Exit code: 20 (Caller decision required)
```

## 决策与下一步

### 决策
**停止 S03,不继续尝试 retry 或修复此次 smoke。**

理由:
1. 问题根源在 S02 的真实集成
2. 修复需要改代码,不是配置调整
3. 正确的流程是修复后重新 smoke

### S02 需要修复的问题

**核心问题**: dispatch.py 在生成 protocol 时没有根据 `delivery_mode` 调整指令。

**需要修改的地方**:
1. `src/omac/pipeline/dispatch.py` - 生成 protocol 时检查 delivery_mode
2. 如果是 content 模式,protocol 应该说明:
   - "使用 content delivery 模式,不需要 PR"
   - "通过 omac work submit --content-file <file> 提交"
3. 确保 `omac work show` 返回的 submit 模板使用正确的参数

**验证方式**:
1. 修改代码
2. 运行 mock 测试验证 protocol 文本正确
3. 重新执行 S03 smoke
4. 确认 collect 节点成功提交

### S03 重新执行条件

S02 修复完成并验证后:
1. 提交修复代码
2. 更新 frozen-input.json 的 revision
3. 清理本次 smoke 的 issues (WEEK-11, WEEK-12)
4. 创建新的 S03 smoke
5. 验证四项断言全部通过

## 价值与教训

### S03 的价值
✅ **这正是 smoke 存在的意义**

- 在正式样本前发现了 S02 的集成问题
- 避免了在 S04 正式样本中浪费时间和 token
- 验证了"分阶段 gate"的必要性

### 教训
1. **代码测试 ≠ 真实集成**: Mock 测试全过不代表真实环境可用
2. **Protocol 生成需要动态**: 不能硬编码 PR 模式的指令
3. **验收标准要严格**: OMAC 的 evidence gate 正确地拒绝了不完整的提交

## S03 判定总结

| 项目 | 状态 |
|------|------|
| S03 Smoke 执行 | FAIL |
| S02 真实集成 | FAIL (发现问题) |
| OMAC 编排能力 | PASS (引擎本身工作正常) |
| Desktop daemon | PASS (成功派发) |
| B3 可以开始正式样本 | NO (需要先修复 S02) |

---

**下一步**: 修复 S02 的 protocol 生成逻辑
