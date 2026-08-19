# S03 Smoke 当前情况分析

## 问题发现

创建了 WEEK-10 issue,但它**不是通过 OMAC 编排启动的**,而是直接指派给了 weekly-collect agent。

### WEEK-10 当前状态
- Issue ID: WEEK-10 (db173d75-d402-43e8-a2c1-fa8c207a744f)
- Status: in_review
- Assignee: weekly-collect (已完成)
- Run: 5727cbc6 completed (2026-08-19T12:14 - 12:19)
- 这是一个**原生 Multica 执行**,不是 OMAC 编排

### OMAC DAG 状态
```
omac dag status .omac/weekly.yaml 显示:
Progress: 0/3 done (running 0, todo 3)
KEY      STATUS  WORK_ITEM_ID
collect  todo    -
write    todo    -
review   todo    -
```

所有节点都没有 work_item_id,说明 OMAC 还没有创建实际的工作项。

## 根本原因

OMAC 的启动方式有两种:

1. **通过 `omac dag run` 启动** - OMAC 引擎会创建并编排 issues
2. **手动创建 issue** - 这只是原生 Multica 执行,不会触发 OMAC 编排

我们用的是方式 1 的变体(直接创建 issue),但没有正确启动 OMAC 引擎。

## 正确的做法

应该使用:
```bash
omac dag run .omac/weekly.yaml
```

这会:
1. OMAC 为每个节点创建独立的 issue
2. 按照 DAG 依赖关系编排执行
3. 使用 content delivery 模式传递产物
4. 自动推进状态机

## 当前决策

我们有两个选择:

### 选项 A: 放弃 WEEK-10,用 OMAC 正确启动
- 优点: 这才是真正的 OMAC 编排 smoke
- 缺点: WEEK-10 已经跑完了 collect 节点

### 选项 B: 把 WEEK-10 当作"原生 Native 执行"的参考
- WEEK-10 实际上演示了原生 Multica 的执行方式
- 可以用它来对照 OMAC 编排的差异
- 但它不是 B3 smoke 的目标(smoke 应该测试 OMAC)

## 建议

**执行选项 A**: 启动真正的 OMAC 编排 smoke

```bash
cd /d/agentlearn/learnezvibe
omac dag run .omac/weekly.yaml --max-rounds 10
```

这会创建 3 个新的 issues (可能是 WEEK-11, WEEK-12, WEEK-13),每个对应一个节点。
