新 session 任务：S04 第二组重跑（Native-03 + OMAC-03）→ S05 分析

【必读，动手前】
1. Evidence/B3/交接信-S04-第二组重跑.md —— 主信：污染两通道、同窗串行配方、证据暂存仓库外、canary 告警、踩坑清单
2. Evidence/B3/next-session-entry.md —— 3 分钟速查
3. Evidence/B3/protocol.md —— 实验合同（修订记录已含：同窗串行、新槽 Native-03/OMAC-03、污染样本排除口径）
4. 归档目录 /d/agentlearn/learnezvibe-b3-archive-20260820/samples/sample-checklist.md —— 采集清单+A1-A5 模板
   （samples 已移出仓库做清场；污染事件原文 incident-pair-02-contamination.md 也在归档目录）

【用户已拍板（已登记 protocol 修订，无需再问）】
- 执行方式：同窗串行（先跑完 Native-03 全部三节点，再启动 OMAC-03；同角色 agent 严禁并发）
- 槽位：新开 Native-03 / OMAC-03（污染的 Native-02/OMAC-02 排除、不计入计量、单列披露）
- 清场：已执行（samples 移出仓库 + push 远端 d94df09，远端已验证干净）

【执行：同窗串行】
A. Native-03：新根 issue（root-issue-body.md + fixtures-v1 4 附件，标题 [B3-S04 Native-03] weekly 周报流程 (正式样本)）
   → 指派"周报"squad（6e94e57b-9c9d-4380-9304-5b9d780112f1）→ leader 自动评论区委派 collect→write→review
   → 监控至完全收敛（~15-20min）
B. Native-03 收敛且 canary1 全绿后，才建 OMAC-03：新根 issue（同正文+同附件）→ 复制 .omac/s04-omac-01.yaml 为
   .omac/s04-omac-03.yaml（改 meta.title→OMAC-03、meta.source_issues[0].issue_id→新根 issue、
   三节点 status: todo / work_item_id: null；collect 的 contract.objective 模板句保留；勿复用 -02 manifest）
   → nohup bash .omac/s04-driver.sh .omac/s04-omac-03.yaml .omac/s04-omac-03.log &
C. 等 OMAC-03 CONVERGED（rc=0，~25min）

【采集与验收（铁律：先暂存仓库外）】
- 两臂 run 期间证据（runs/runmsg/deliverables/summary 等）先写 /d/agentlearn/learnezvibe-b3-archive-20260820/tmp-collect/
- 两臂都收敛 + canary 全绿后，才把证据移入 Evidence/B3/samples/Native-03/、OMAC-03/（防 Native-03 证据污染 OMAC-03）
- 每样本：root-issue.json / runs.json / runmsg-<run>.json / deliverables(下载+哈希) / summary.json；
  Native 另存 comment-thread.json，OMAC 另存 driver.log
- run-messages：issue runs <issue-id> 拿 run id → run-messages <run-id>
- A1-A5 逐项核对；A4：OMAC 看 verification yaml（review-consistency.py），Native 人工看 review 评论
- 故障 run（空会话/usage 空/截断）不计入计量，单列披露

【污染 canary（全绿才算有效，任一告警→停下升级用户）】
- Native-03：collect 成员 run-messages 无 OMAC 工单引用（grep WEEK-2[5-9]/run-messages 01a0）；
  weekly-data.md hash 全新（≠ 14caa249/5245b7f6/c87bb483/003dc995/0f1e46f4）；根 issue 达终态
- OMAC-03：write run-messages 无 Native-0x/samples/deliverables 引用；产物 hash 全新；
  review verification 不指向 samples/deliverables 路径；三节点同 agent 无时间重叠

【跑完后 S05 分析】
- 汇总 4 有效样本（Native-01/03 + OMAC-01/03）token（4 类）/墙钟/步骤数/run 数/成功率
- Native 两种口径：成员三节点 vs 含 leader 编排开销
- 报告两层：给用户的一页结论（项目语言）+ 硬核明细；存 Evidence/B3/reports/
- 第二组污染样本单列披露（不计入计量）

【铁律】
- protocol 冻结不改（已登记的修订除外）；fixtures-v1 禁止编辑；同窗串行（禁同角色并发/禁四样本并发）
- 一律 dag tick 驱动，不用 dag check；平台/agent 命令带 timeout 或后台
- 大批会话空转 → 先查账号余额/资源，别急着改架构
- 重跑期间不 commit 任何样本证据进仓库（OMAC 引擎会自动 manifest sync，属正常）
- 完成 S05 后汇报：4 样本对比结论 + 给用户的浅白版总结
