# S03 Smoke 最终结果 (2026-08-20 全新链路)

> 执行时间: 2026-08-20 05:33 - 06:06 UTC (33 分钟,零人工干预)  
> Manifest: `.omac/weekly-smoke.yaml` (非计量 smoke,不占 S04 样本槽)  
> OMAC: oh-my-multica `206f3b4` (含 hydration 修复)  
> 驱动方式: `.omac/smoke-driver.sh` 后台有界 tick 循环,日志 `.omac/smoke-run.log`

## 结论: **PASS** -- 三节点全链路一次过门收敛,零 gate 失败

## 节点时间线

| 节点 | Issue | 派发 | 收敛 | 耗时 | 用量 (in/out/cache) |
|---|---|---|---|---|---|
| collect | WEEK-16 (`48b7cd31`) | 05:34:39 | 05:49:20 | 14m41s | 102,910 / 12,167 / 851,200 |
| write | WEEK-17 (`6d6d7716`) | 05:50:23 | 05:56:15 | 5m52s | 70,293 / 6,209 / 847,360 |
| review | WEEK-18 (`322d8e2a`) | 05:57:14 | 06:06:06 | 8m52s | 84,630 / 7,722 / 939,776 |
| **DAG** | | | 06:06:06 converged (done=3/3) | **33 分钟** | 合计 in 257,833 / out 26,098 |

## 关键验证点

### 1. evidence gate (本次修复目标) -- 全部通过
- 三个节点全部走 complete-unsealed 收口路径 (content 模式),一次过门
- 三个 issue 评论中 **零** "Evidence gate failed"

### 2. collect agent 提交质量 (S04 前的关键保险) -- 合格
- 本次提交: 真实 `weekly-data.md` 内容 (735B, 4 条要点, sha `7ce872c20134...`), artifacts=["weekly-data.md"]
- 对比 08-19 的不合格提交 (254B 摘要+PR 链接, artifacts=["delivery.md"],当时未被验收): 现行协议下 agent 行为正确

### 3. 跨节点 content 传递 (断言 4) -- 数据真实流动
- write 的 source_refs -> collect issue; review 的 source_refs -> write issue (结构引用链完整)
- **语义验证**: write 周报正文 (1034B) 明确覆盖 collect 的 4 条要点 (DAG 职责划分/OMAC 受控交付/可执行验证/环境配置),非旧文件复用
- review 提交的是真正的评审结论 (296B, "评审通过并定稿",声明覆盖 weekly-data.md 四项来源要点)

### 4. 幂等收敛
- 驱动脚本每 150s 一轮 `omac dag tick` (有界单轮),收敛时 exit 0 自动退出
- 全程零人工干预,无重试无 blocked

## 交付物 sha256 链

| 节点 | deliverable sha256 | bytes |
|---|---|---|
| collect | 7ce872c201346b99cc29c1531b733519bca341cf71852aca1b1225eac6962a5b | 735 |
| write | d71bae46701af7878c28f2fba03231e6f355f679428163babe03c2bf058fe263 | 1034 |
| review | 224a28731f299738e5cbc98ed3579fbb97775304f8e6b06e4f6484270b77db1c | 296 |

## 已知事项 (不阻塞 S03,记录备查)

1. **`omac dag check` 的评审流程会无限轮询**: reviewer agent (代码评审与开发助手) 只发文本 verdict 评论、不写结构化 review_verdict 元数据,`run_review` 的 `while True` 无超时挂死 (WEEK-11/WEEK-15 两次复现)。规避: `--no-review` 或直接 `dag run/tick` (已确认 run 不依赖 check)。**建议作为 OMAC backlog bug 修复**
2. **WEEK-15 的 reviewer REJECT 意见** (合同可执行性弱: gate 命令只查文件存在、collect 3-5 条上限未验等) 被人工 override -- smoke 为机制验证,合同质量改进记为 S04 前可选优化项 (两个 arm 同步改,公平性不受影响)
3. 本 smoke 各 issue 均为 `[DAG:*]` 自动创建 (WEEK-16/17/18),原 WEEK-10~15 已全部标 done

## S04 准备状态

- [x] OMAC 管线真实环境全链路验证 (修复 + 三节点类型 + 跨节点传递)
- [x] 三个 weekly agent 在现行协议下提交行为合规
- [x] token 用量可采集 (`multica issue usage`)
- [ ] S04 执行环境准备 (按 `protocol.md`: Native-01 -> OMAC-01 -> Native-02 -> OMAC-02 串行)
- [ ] (可选) 收紧 manifest 合同 (吸收 WEEK-15 review 意见)
