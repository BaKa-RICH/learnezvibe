# 学习笔记:OMAC 与 Multica 的机制、重点逻辑、协作机制

> 本笔记是学习存档,内容全部来自源码核验(文件:行号级)与真实运行(WEEK-8)证据。
> 生成于 2026-08-16,2026-08-18 新增 §10 生态与竞品核查。配套:《omac联调排障手册.md》《面试准备-简历问答拆解.md》

---

## 1. 总模型:四个角色 + 三种架构

```
你(人)
  ├─ 写 manifest(流程定义)/ 在 UI 干预
OMAC(机器队长,Python CLI,平台外面的普通用户)
  ├─ 用 multica CLI 指挥平台;手里攥着 manifest 账本(进 git)
Multica 平台(公司:云端 server + 本地 daemon)
  ├─ 工单/评论/附件存储;daemon 在本地拉起 agent(沙箱/worktree)
agent(codex/claude/pi,员工)
  ├─ 被唤醒->读信封->干活->交活
```

三种架构定位(用户尖锐质疑引出的结论):

| 方案 | 形态 | 得 | 失 |
|---|---|---|---|
| A 直调 agent SDK | 单机轻量 | 无适配税 | 自建:队列/环境/UI/审计 |
| B 外挂平台(OMAC 现状) | 引擎在平台外 | 白拿基础设施+UI | 适配层重、轮询低效、评论区闲置 |
| C 引擎进内核(终极方案) | 引擎成为平台一部分 | 事件驱动(复用现成 child-done 链)、税消失 | 需改 Go 内核 |

**B 的"重"是外挂形态的税,不是平台无价值。**

## 2. Multica 原生:单 issue 协作(七幕,supervisor-worker)

```
①任务进门:人把 issue 指派给 squad -> 平台自动唤醒 leader
②队长简报:三段(协作硬规则 + 花名册[含@格式和技能] + 任务说明)——leader 独家
③派活 = 白板点名:leader 评论 @worker -> 平台解析 mention -> 建 agent 任务
   去重:同一 issue 内每个 agent 同时只能有一个 pending 任务(唯一索引)
④worker 醒来:桌上便条只有"任务号+交接说明+取资料的路标"(指针,不是全量资料)
⑤交活:写评论(结果)+ 子 issue 置 done
⑥通知 = 事件驱动(非轮询):子 issue 完成且"阶段闸门关闭"(整阶段全部完成)
   -> 平台发 system 评论(@leader+进度摘要)-> 自动重新入队 leader
   注意:单个子任务完成是静默的;worker 的结果评论只唤醒 leader(worker 间无直连)
⑦循环:leader 审阅 -> 派下一阶段或收尾(把父 issue 状态推到终点)
```

**组织形式判定:supervisor-worker,不是对等 swarm。**(源码:worker 结果评论窄路径只回 leader,comment.go:2669)

## 3. 信息载体全景(登记表)

| 载体 | 存储 | 谁写 | 给谁看 | 到达方式 |
|---|---|---|---|---|
| 白板(评论) | 平台 DB,线程树 | 人/agent/**system**(type 字段之一) | 所有人 | **拉**(没人自动收到) |
| 便条(issue_context.md) | agent 工作目录的临时文件 | daemon | 本次被唤醒的 agent | **推**(放眼前) |
| 排班表(agent_task_queue) | 平台 DB | 服务端 | 只有平台/daemon(agent 看不到) | 不可见 |
| 交接说明(handoff_note) | 排班表字段 | 派活的人/agent | 被派活的 agent | **推**(印进 prompt+便条) |
| 队长简报(squad briefing) | 不存储,认领时现场拼 | 服务端代码 | 只有 leader | **推**(注入 prompt) |

**handoff 的一生**:出生于派活瞬间 -> 抄进两个信封(prompt + issue_context.md)-> 接活人当场读 -> 随本轮任务结束消失。**handoff 跟"派活"走,不跟"交活"走**(交活只写评论,不产生 handoff)。

## 4. agent 的三层信封(核心概念:三者不相等)

```
第1层:工单 issue(平台持久档案,存 DB,永久)
第2层:prompt 任务书(daemon 现场拼,用完即弃;执行消息另存为 run 记录)
第3层:事实包(OMAC 特有,work show 现场生成 JSON,即消散)
```

- **推拉结合**:推给 agent 的只有:触发评论全文(内联)+ handoff + 路标命令;其余(issue 全文/评论历史/代码)按路标自取
- **目录式读法(平台规定的阅读协议)**:先扫线程目录(--roots-only --summary,一行一话题)-> 挑重要的展开(--thread <id> --tail 30)-> 防上下文爆炸
- **捎带机制(coalesce)**:agent 干活期间来的新评论不打断,折进下一轮 prompt 全文内联("这几条也必须处理")
- **session 续跑**:平台存 session_id,同 agent 同 issue 再唤醒时 daemon resume 原会话;续不上则注入"连续性通知"让 agent 用 issue+评论补课

## 5. 数据库层(仓库-柜台-索书条)

- **~100 张表 / 716 次迁移**。分类:协作核心(issue 系列 8 张/comment/attachment/project)、agent 世界(agent/agent_task_queue/squad...)、自动化(autopilot 6 张)、外部连接(github/vcs/飞书钉钉 ~20 张)、聊天、用量统计、插件
- **agent 永不进仓库**:一切查询走 multica CLI(柜台),人/agent/OMAC 在数据访问上平等
- 核心表:
  - `issue`:status 七态(backlog/todo/in_progress/in_review/done/blocked/cancelled)、parent_issue_id(子任务树)、stage(阶段闸门)、metadata **JSONB**(自由栏位)、acceptance_criteria
  - `comment`:content/author_type/**type(comment/status_change/progress_update/system)**/parent_id(线程树)
  - `attachment`:挂 issue 或挂 comment;OMAC 的契约/验证附件就是它
  - `agent_task_queue`:排班表,(issue_id,agent_id) pending 唯一(迁移 037)

## 6. OMAC 如何参与(六步:接管/复用/改造)

```
①派活【OMAC 接管】(原生:leader LLM 评论@)
   tick 第4步:issue create(body=守则:"第一动作必须 omac work show")
   + 契约附件 omac-contract-*.yaml + metadata 贴标签(dag_key/worker/kind/blocked_by)
   + manifest 记账(work_item_id/status)
②排队【完全复用】同一张排班表、同一条唯一约束
③叫醒【复用 assign 即 wake,但信封换血】平台照发便条;body 是 OMAC 守则
④干活【agent 照常+头尾协议】omac work show(动态事实包)-> 干活 -> git push + gh pr create
⑤交活【改造:不写白板,交结构化证据】omac work submit:
   沙箱跑验证命令 -> 验证附件 omac-verification-*.yaml -> metadata 交付标识
⑥通知【改造:不靠事件,靠轮询】tick 循环(见下)
```

**tick 四步循环**(OMAC 的"听消息"方式,替代事件通知):

```
1 reconcile 对账:issue get 拉平台真实状态回账本(metadata 的 dag_key 对号)
2 collect 收果:下载验证附件 -> 证据门校验 -> 通过则 gh pr view/merge
   (只认 GitHub 远端说 MERGED);不过则打回(返工预算-1)
3 失败隔离:失败节点的下游全标 blocked
4 decide+dispatch:派下一个 ready 节点(回到①),没有则空转下一轮
每轮结束:manifest 写回 + git commit("chore(omac): manifest sync")
终止:全 done -> exit 0;失败待决策 -> exit 20 停下等人(node retry/accept/abandon)
```

**OMAC 版载体变化**:白板降级为公告栏(只挂守则+附件,agent 间不对话);handoff_note 不用(被 body 守则+事实包接管);metadata 重度使用(30+ 键,taskmeta.py:kind/phase/四类 bounce/deliverable/contract_ref/verification_ref...);新增 manifest 账本(进 git)和 PR 交付通道。**评论区闲置是移植性取舍**(mock/multica 双引擎只用最小公约数)。

**metadata 双镜像**:引擎手里的 manifest 账本(git,可审计)+ 工单上的 metadata 标签(平台侧状态镜像),对账时互相对号。

**契约附件三用**(静态,永不改,改则走显式修订流程):agent 的任务书原文 / 证据门校验基准 / 人工审计对照。

## 7. 确定性分界:prompt 还是代码(最重要的一张表)

| 机制 | 层级 | 违反会怎样 |
|---|---|---|
| body 守则("先 work show,禁其他") | prompt(自觉) | **无保证**--WEEK-8 开局 codex 就违反过,后自我纠正 |
| 证据门校验(evidence.py validate_worker_evidence) | **代码** | 缺一项打回:PR url 必填/每条验证命令在且 exit 0/验收项全覆盖/env_setup/pr_base 一致/coverage 达标 |
| 派发/失败隔离/绝不自动重试 | **代码** | 保证 |
| merge 收口(只信远端 MERGED) | **代码** | 保证 |
| 失败决策(node retry/accept/abandon,exit 20) | **代码** | 保证 |

**诚实边界**:验证命令的 exit_code 是 agent 申报的,引擎做结构校验不重跑;兜底=结构完整性+远端事实(PR 必须真在 GitHub)+全程留痕。**确定性来自机器验收,不来自 LLM 自觉。**

## 8. OMAC vs 直调 SDK(七项对比)

| 失去什么 | 说明 |
|---|---|
| 人的界面(最重) | exit 20 时人在哪看/干预--平台 UI 现成 |
| 执行环境管理 | worktree/环境注入/凭证,15 类故障多由 daemon 兜着 |
| 任务队列与恢复 | agent 跑 10 分钟断电,队列+认领+重放是平台的 |
| 单点真相工单 | 人/OMAC/agent 看同一张;人评论下轮 agent 能收到 |
| 行为审计 | 205 条 run-messages 是平台存档的 |
| 一份适配换 21 runtime | 2336 行适配一个接口 vs 每种 SDK 一份 |
| 云编本地执行 | daemon 在本地=agent 能摸内网;SDK 绑死单机 |

## 9. 同进程多 agent 协作机制全景

组织形式:DAG 编排(最可控)/ 群聊 GroupChat(AutoGen,灵活但贵)/ 父子 sub-agent(Claude Code,上下文隔离只回传摘要)/ swarm handoff(OpenAI SDK,控制权转移+携带对话历史)。

| 通信机制 | 代表 | Multica 对应 | OMAC 对应 |
|---|---|---|---|
| state sharing | LangGraph 共享 state | 无(指针注入替代) | manifest(但 agent 不可读) |
| 黑板/消息池 | MetaGPT 订阅过滤 | 评论流(弱黑板,无结构) | 无 |
| 讨论/互评 | AutoGen | 评论线程(可回帖) | reviewer 单向评审 |
| task checkpoint | LangGraph checkpointer | 子 issue 状态+排班表 | manifest(引擎私有) |
| handoff | OpenAI SDK | handoff_note(派活字段) | 不用(body 守则+事实包) |
| 结果回传摘要 | Claude Code subagent | worker 评论回 leader | 验证附件(结构化) |

**A2A 边界**:同进程/同机/同信任域用不上 A2A(到第三个跨域 agent 才考虑)。

**空白地带**:Multica(消息丰富+零确定)与 OMAC(确定满格+零消息)之间,"结构化黑板+确定性推进"没人做。

## 10. 2026-08-18 上游生态与竞品核查(调研快照)

> 起因疑问:Multica 是否原生 leader LLM 临场编排?源码/生态里是否已有确定性工作流引擎?以下结论均为源码级或 issue 原话核验,重查前先看本节。

**① 原生 = LLM 临场编排,源码实锤**
- `squad_briefing.go:20-79` 官方注入 leader 的 "Squad Operating Protocol" prompt 原文:"decide which squad member is best suited" / "Delegate by @mention" / "Stop after dispatching" / "Re-evaluate on each trigger"——拆解/选人/推进全在 prompt
- `comment.go:2548-2600` @mention 派发链路(-> EnqueueTaskForMention / EnqueueTaskForSquadLeader),是 agent 间主派发通道
- `issue_child_done.go:444` 上游注释自述 "The server has no declarative workflow model - stages are agent-driven";:455 推进决策交还 leader。无代码级内容验收,唯一自动化 = `github.go:1659` MERGED webhook -> done(远端事实)
- `issue_dependency` 表确认死表(Go 侧仅 workspace 删除时清理,零推进逻辑)

**② 上游无确定性引擎,官方路线与本项目反向**
- 官方对 workflow 诉求(#1943)的回应 = 发 Squad(LLM leader 方案);用户 HenryQW 实测 Squad 比直调 subagents 费约 6 倍 token,维护者承认在优化
- #4325 维护者确认只做了 stage 检测("the owner can review the result and promote the next stage")——引擎三件套(检测/推进/验收)平台只有半个检测

**③ fork 生态零引擎,空位干净**
- 100 个 fork 全为上游原样;fork 网络代码搜索 `workflow_definition`/`workflow_run`/`node_run`/`blocked_by`/`dag` 全部 0 命中
- `chalecao/open-agents-workflow` = 落后上游的 rebrand 快照,无引擎(源码 diff 确认)
- `rberyou/multica-dev-workflow` = 最接近的同物种:Terraform 式 desired-state 配置部署工具(doctor/plan/drift/verify/apply),流程约束靠 prompt 级 Skill,非运行时状态机(读 590 行源码确认)

**④ 需求证据(issue 硬引用)**:#1245 用户跑 13-14 个 issue DAG,靠 "external watchdog polling issue status" 打补丁,呼吁原生 `blocked_by`(= OMAC 轮询形态的社区镜像);#1998 原话 "workflow's correctness lives inside each agent's prompt rather than in declarative platform config";四个相关 issue(#970/#1218/#1245/#1943/#4325)全部 open

**未核验事项(诚实边界)**:① GitHub 代码搜索对无 star fork 索引不完整(靠源码 diff 补证了主要候选);② whatif-dev/ai-harness-multica、Time-Machine-Lab/Stein-AI 两个改名 fork 未核验(compare API 404,描述未变,风险极低)

**复查触发器**:上游 release note 出现 workflow/orchestration/dependency 字样;#1245/#1943/#4325 状态变更;D 阶段开工前。

## 11. 工单身份、证据与重跑机制

**一张工单的三个名字**:identifier(WEEK-8,平台工号,只增不改)/ title([DAG:node1],omac 建单格式;判别法:带 [DAG: 前缀=引擎建,不带=人工/模板建)/ id(UUID 主键)。

**manifest ↔ 工单的双向指针**:manifest 节点 `work_item_id` ──► 工单 UUID;工单 metadata `dag_key` ──► 节点名;两个名字只是人类可读投影。**manifest 作者只有两方**:人(菜谱:id/worker/contract)+ omac(台账:work_item_id/status/merged/merged_at);平台与 agent 均不写它。

**证据体系(本体不在 manifest)**:四处①工单 metadata 的 delivery_identity 指纹(谁/哪次运行/哪个 PR/几点)②两附件(合同原件+验证包)③执行消息记录(如 WEEK-8 的 205 条)④GitHub PR(远端事实)。物理位置:①②③在 multica 云端 DB,④在 GitHub;本地 manifest 只是索引。**毁证据唯一途径 = 对云端记录写操作**(rerun/status/metadata set/删除);建新单、改本地文件均无害。

**重跑与复用**:①omac 规则:节点有 work_item_id 就复用工单,无则建新单;原样重跑 done 节点=全跳过,删 UUID 重跑=建新单+改本地台账(云端旧行无恙)。②平台 rerun=对同一工单再派一次活:对工作中工单是正常能力(打回重跑),对已定案证据工单是时间线污染(WEEK-8 禁 rerun)。③autopilot 两种模式(autopilot.go:573/860):create_issue=每次触发建新工单(源码注释:durable audit trail,带防抖守卫)/run_only=不建工单直接派活--平台"1 次执行 1 张单"审计哲学与 omac"1 节点 1 工单"、内核版 workflow_run 同构。

**交互通道与 daemon**:三通道:multica CLI(人与 omac 共用,HTTPS->云 server);云 -> daemon(本地)-> agent 拉起;gh CLI -> GitHub。daemon=本地手脚:查询类命令不需要,agent 真实干活需要;停了 `multica daemon start`;装新工具后必须重启 daemon(环境快照)。

## 12. 速查

**源码锚点**(Multica `server/`):comment.go:2548/2626 mention 派发链路+computeCommentAgentTriggers / task.go:954/1019/1190 EnqueueTaskFor* / task.go:3543 CompleteTask / issue_trigger.go:96 WillEnqueueRun / issue_child_done.go:68/259/370/444/452(child-done 链+阶段闸门+"no declarative workflow model"注释)/ squad_briefing.go:20-79/164(Protocol 原文+roster)/ github.go:1659(MERGED->done)/ daemon/prompt.go:129/282 BuildPrompt/buildCommentPrompt / execenv/context.go:120/1000 writeContextFiles/renderIssueContext / migrations/001 issue+comment 建表 / 105 metadata JSONB / 037 唯一索引

**源码锚点**(OMAC `src/omac/`):pipeline/loop.py:4290 tick / pipeline/dispatch.py:1376 render_issue_body(守则)+359 事实包 / core/evidence.py:204 validate_worker_evidence / pipeline/delivery.py:273 run_merge_delivery / engines/multica.py:1303 create_work_item+1795 assign_work_item / core/taskmeta.py(metadata 键)/ core/reconcile_audit.py:43 tick 计数

**ID**:workspace 466eb7c0-2554-45e6-91a8-6890663bb359 / project 6e64ba4b-8856-4ac2-aa24-a47b9169ae71 / codex agent 93b08860 / Mika c7b07bcb / WEEK-8 工单 24f7de55(三次尝试:53b5dbfb/#4、b90018b3/#6、24f7de55/#8)


## 13. 引用式证据与 hydration(content 交付的核心,2026-08-20 新增)

**为什么设计成引用式**: 合同小、内联在 metadata; deliverable/verification 大, 是平台附件, metadata 只存**指针** (ref: comment_id/attachment_id/sha256/bytes)。验收前必须有人按指针把附件下载解析 (hydrate), 否则证据门看到的就是 None。

**谁负责搬运**: 不是 evidence gate 自己读附件, 而是上游某环节把附件 hydrate 成 work_item 字段再交给 gate。PR 流程里"封印观察"会顺带读 verification 附件; content 流程新增了 `complete-unsealed` 免封印捷径, **捷径上没人搬证据** → 两条流程互相踢皮球, 这就是 B3-S03 那个 bug 的本质。

**证据门只验结构不验语义**: gate 检查 verification schema + deliverable 存在 + 哈希, **不检查产物内容是否真的满足验收声明**。所以 review 节点"原样重发上游文件"也能过门——语义验收必须靠人工查验 run-message (B3 A4 rubric 的做法)。

**源码锚点** (OMAC): `pipeline/loop.py` `_build_work_item_hydration_plan` (~L1013) / `_hydrate_worker_collect_evidence` (~L1094) / collect_results complete-unsealed 分支 (~L3325) / `core/evidence.py` validate_worker_evidence (~L205)

## 14. 真实 bug 复盘: hydration 踢皮球 (2026-08-20)

**症状**: S03 smoke 两次失败在 "Worker evidence gate: verification is required", 但 agent 明明正确提交了。

**为什么难查**: 表象 (gate 拒绝) 掩盖了真凶 (读回路径缺搬运); 第一直觉归咎 agent (70% 猜测) 是错的。**正确做法**:
1. 用平台时间线证伪: metadata 有 verification_ref/deliverable_ref (submit 成功产物), 附件 uploader_type=agent, 失败评论在 submit 之后 → agent 行为合法
2. 把 verification 附件 hydrate 后直接喂证据门 → 0 错误 → 排除"提交内容非法"
3. 逐环复现: dispatch 写 handoff intent → hydration plan 只载 contract → complete-unsealed 不读附件 → gate 看到 None

**修复** (`206f3b4`, 一处 + 回归测试): complete-unsealed 分支复用 PR 路径已有的 `_hydrate_worker_collect_evidence`。**TDD**: 回归测试先红 (失败方式与线上完全一致) → 改码转绿 → 全量 101 基线零新增。

**可讲 15 分钟的结构**: 症状 → 时间线证伪 → 数据复现 → 架构根因 (引用式搬运的责任归属) → TDD 修复 → 真实环境验证 (三节点类型全过门)。
