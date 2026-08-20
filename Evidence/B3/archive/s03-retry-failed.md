# S03 Smoke 重试失败分析

> 日期: 2026-08-19  
> 状态: write 节点也失败,同样的 evidence gate 问题

## 执行情况

### Write 节点
- Issue: WEEK-13
- Work Item: ba05306d-70ca-429f-b11b-687ebbd5b996
- Agent: weekly-write
- Run: 41538692 completed (12:52-13:01, 9分钟)
- Agent 行为: ✅ 上传了 verification 和 deliverable 附件
- **OMAC 判定: ❌ FAILED** - "Worker evidence gate: verification is required"

### 与 Collect 节点相同的失败

这和之前 collect 节点的失败模式完全一样,说明:
1. Protocol 修复可能不完整
2. 或者还有其他问题导致 evidence gate 失败

## 可能的原因

### 1. Protocol 文本已修复,但 Agent 仍未正确使用

即使 protocol 文本正确了,agent 可能:
- 没有正确理解 content 模式的 submit 命令
- 只是上传附件,但没有运行 `omac work submit --content-file`
- 或者运行了但参数不对

### 2. Evidence Gate 的要求可能更严格

OMAC 的 evidence gate 可能要求:
- Verification 命令必须在 workdir 中执行并通过
- Deliverable 文件必须通过特定的持久化路径
- Submit 必须使用正确的 OMAC API

### 3. 上游依赖问题

Write 节点依赖 collect 的产物,但:
- Collect 被 abandoned
- Write 可能无法读取到正确的 upstream deliverable
- 导致验证失败

## 当前决策

我建议**停止当前 S03 尝试**,原因:

1. **两次失败都是同样的问题** - 说明根本问题未解决
2. **Protocol 修复不够** - 需要更深入的分析和修复
3. **时间成本** - 继续尝试可能浪费更多时间

## 下一步建议

### 选项 A: 深入分析 evidence gate 失败原因 (推荐)

**需要做的事**:
1. 下载并检查 write 节点的 verification 附件内容
2. 对比 OMAC 的 evidence gate 源码,理解它的精确要求
3. 检查 agent 是否正确调用了 `omac work submit`
4. 可能需要修复更多代码 (不只是 protocol 文本)

**预计时间**: 2-4 小时

### 选项 B: 暂时降级到 PR 模式验证 OMAC 编排

**目的**: 
- 区分问题是"content 模式集成"还是"OMAC 编排本身"
- 如果 PR 模式能通过,说明 content 模式的集成确实有问题

**方法**:
```yaml
# weekly.yaml
nodes:
  - id: collect
    delivery_mode: pr  # 改回 pr
```

**风险**: 这不是 B3 要测的目标

### 选项 C: 直接跳到 B3 正式样本,使用 PR 模式

**判断**: 
- Content 模式集成太复杂,短期无法完成
- 先用 PR 模式完成 B3,产出数据
- Content 模式作为后续优化

**风险**: 
- 改变了 B3 的实验设计
- 简历上的说法需要调整

## 我的判断

**当前问题比预期复杂**

S02 的 protocol 文本修复只是表层,真正的问题可能在:
- Agent 不知道如何正确调用 `omac work submit --content-file`
- OMAC 的 evidence gate 对 content 模式有特殊要求
- Deliverable 持久化的实际机制还有问题

**建议**: 暂停 S03,选择:
1. 如果时间充裕 → 选项 A (深入修复)
2. 如果时间紧迫 → 选项 C (降级到 PR 模式完成 B3)

---

你想选择哪个选项?
