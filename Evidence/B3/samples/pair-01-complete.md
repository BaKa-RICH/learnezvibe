# S04 第一组配对完成报告（Native-01 + OMAC-01）

> 完成时间：2026-08-20 ~17:46（本地）；两个样本均为 **SUCCESS**（A1-A5 达标）

## 一句话结论
同一冻结输入（fixtures-v1 4 文件，哈希全匹配）、同一三阶段拓扑（collect→write→review）、同一验收 rubric 下，
**Native 与 OMAC 双双完整跑通**，且首次在真实环境端到端验证了 fixture 注入链路（根 issue 附件 → collect 读取 → 哈希核对）。

## Native-01（WEEK-19 a2470a6f）
- 编排：**leader @mention 委派**（无子 issue）——leader 在根 issue 评论线程逐阶段派活：[@weekly-collect]→[@weekly-write]→[@weekly-review]
- 阶段 run：collect a39c86f6(40msgs) → write 2a2e6c5e(28msgs) → review b5039670(24msgs)，根 issue 转 done
- 交付：weekly-data.md(2856B, sha 5245b7f6) + weekly-report.md(1762B, sha 003dc995)；review 结论"通过验收"
- 计量（成员三节点）：in 123141 / out 10313 / cr 940288；+leader 编排开销：in 226231 / out 19642 / cr 2666240
- 步骤数：成员 39 tool_use，全样本 78（含 leader 38）
- wall_clock：成员管线 10m01s；含 leader 13m05s

## OMAC-01（根 issue d7694427，manifest .omac/s04-omac-01.yaml）
- 编排：固定三节点 DAG，逐节点派发 weekly-collect/write/review，driver CONVERGED(rc=0)
- 阶段 run：collect cba6ee44(80msgs) → write 20353f07(60msgs) → review e5123673(57msgs)
- 交付：weekly-data.md(1695B, sha 14caa249) + weekly-report.md(1892B, sha a623b42e)；review-consistency.py 独立核验通过
- **fixture 注入链路端到端验证**：collect 从根 issue 下载 4 附件，自算 SHA-256 与 frozen 全一致
  （交接信 a3553b02 / 项目总纲 17c5cb0d / B1 40cb15e9 / B2 9d744387），未用 workdir 同名文件
- 计量（三节点）：in 175384 / out 29605 / cr 2992896
- 步骤数：91 tool_use（collect 41 + write 25 + review 25）
- wall_clock：09:20:25 → 09:43:33 = 23m08s

## 过程中解决的两个环境问题（记录备查）
1. **codex 账号余额耗尽**（08:20-08:48 窗口全部会话空转/截断）：用户充值修复。已修正暂停记录。
2. **OMAC agent 缺引擎配置**：agent workdir 无 .omac/config.yaml，`omac work show` 报 engine missing
   （smoke 靠 agent 自行 setenv 兜底）。修复：给 weekly-collect/write/review 设
   `OMAC_ENGINE/WORKSPACE_ID/PROJECT_ID` agent env。之后 OMAC 链路一次跑通。

## 待办
- S05 分析：双样本指标对比（token/耗时/步骤数/run 数）；注意 Native 的 leader 开销口径、codex 故障期 run 的排除口径
- 第二组：Native-02 + OMAC-02（配对并发），fixtures-v1 已就绪
