# S03 Smoke 失败分析与建议

> 更新时间: 2026-08-19 20:43  
> 状态: collect 节点失败,需要决策

## 执行结果

### Collect 节点状态
- Issue: WEEK-12
- Agent: weekly-collect  
- Run: 62a4df67 completed (12:26-12:37, 11分钟)
- Agent 行为: ✅ 完成执行,✅ 上传了 verification 和 deliverable 附件
- **OMAC 判定: ❌ FAILED** - "Worker evidence gate: verification is required"

### DAG 状态
```
collect  blocked  (cascade导致)
write    blocked  (cascade导致)
review   blocked  (cascade导致)
```

OMAC 报告: "Caller decision required: nodes failed or are blocked. Rerun, retry, or abandon."

## 失败原因分析

### 直接原因
OMAC 的 evidence gate 检查失败,认为 verification 不符合要求。

### 深层原因
**配置冲突**: manifest 声明 `delivery_mode: content`,但 dispatch protocol 仍要求 "Push a branch and open a PR"。

这导致 weekly-collect agent 可能:
1. 看到矛盾的指令
2. 不确定该用 content 模式还是 PR 模式
3. 最终只上传了附件,但没有正确通过 `omac work submit` 提交

这正是 **B3 开工前检查文档** 中提到的硬阻塞 #1:

> "真实 content submit 参数合同仍是 PR 形态...影响：真实 content agent 即使生成 `weekly-data.md`，也没有符合当前 CLI 合同的无 PR 提交方式。"

## 这暴露了什么问题?

**S02 的实现不完整**:
- ✅ 代码层面: dispatch.py, delivery.py 等已经支持 content 模式
- ✅ Mock 测试: test_content_submit.py 通过
- ❌ **真实集成**: Agent 不知道如何在实际任务中使用 content 模式

问题在于:
1. Agent 的 protocol 文本仍然是 PR 模式的
2. weekly-collect agent 没有收到正确的 content 模式指令
3. 或者 agent 收到了,但执行时遇到了其他问题

## 你现在的选择

### 选项 A: 停止 S03,认定为发现了关键问题 ✅ 推荐
**判定**: S03 smoke 发现 S02 实现不完整,真实集成失败

**价值**:
- 这正是 smoke 的目的 - 在正式样本前发现问题
- 我们发现了 S02 的真实集成gap
- 避免了在 S04 正式样本中浪费时间

**下一步**:
1. 记录这个发现为 S03 的验收结果
2. 返回修复 S02 的真实集成问题
3. 修复后重新执行 S03
4. S03 通过后才进入 S04

### 选项 B: 尝试手动修复 collect 节点
**方法**: 
```bash
omac node retry .omac/weekly.yaml collect
```

**风险**:
- 可能仍会失败(根本问题未解决)
- 即使通过,write 和 review 可能遇到同样问题
- 浪费时间在不完整的实现上

### 选项 C: 降级到 PR 模式测试
修改 weekly.yaml 改回 `delivery_mode: pr`,看 OMAC 编排是否工作。

**风险**: 这不是 B3 要测试的(B3 需要 content 模式)

## 我的建议

**执行选项 A**: 停止当前 smoke,记录发现,修复 S02

### 立即行动:
1. 记录 S03 结果: "S03 FAIL - 发现 S02 真实集成问题"
2. 更新 S02 状态: 从 PASS 改为 PARTIAL PASS (代码/测试通过,真实集成失败)
3. 明确需要修复的问题:
   - Agent protocol 与 delivery_mode 不一致
   - Agent 不知道如何执行 content 模式的 submit
   - 可能需要更新 dispatch.py 生成正确的 protocol 文本

### 修复后:
1. 提交修复代码
2. 重新执行 S03 smoke
3. S03 通过后进入 S04

---

**这是好事**: smoke 在正式实验前抓到了问题,正是它存在的价值。

你想选择哪个选项? 或者有其他想法?
