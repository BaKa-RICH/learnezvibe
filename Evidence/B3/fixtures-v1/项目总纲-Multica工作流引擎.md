# 项目总纲:Multica 工作流引擎

> 定位:从当前阶段到项目完成的唯一总纲(全景 + 双系统技术对照 + 开发计划 SPEC)。
> 生成:2026-08-17,基于本 session 的源码级调研(文件:行号锚点均实测)。

---

## 〇、文档定位与使用规则

1. **本文档是活文档,是当前认知的快照**:技术对照结论、迁移清单、阶段划分、实现方案,全部为暂定,均可质疑、均可修改。执行任何阶段前,开发 agent 应**自行核验源码**,发现本文档与源码实况不符时,以源码为准并回头修订本文档。
2. **阶段可拆、可并、可调序**:编号仅为当前视图,不是承诺。
3. **文档分工**:本文档管行动方向;《学习笔记-omca与multica协作机制.md》管机制认知细节;《面试准备-简历问答拆解.md》管表达;《omac联调排障手册.md》管环境故障。内容冲突时:机制问题看学习笔记,行动问题看本文档。
4. **使用方式**:每个阶段开工时,以本文档对应小节为 Spec 起点;阶段 Done 时更新本文档状态标记。

---

## 一、项目全景

### 1.1 问题与机会

开源 Agent 平台 Multica 原生采用"leader LLM 临场编排":leader agent 临场拆解、评论区@派活、自己验收。实测问题:同样输入多次执行步骤不一致(pi 在 Windows 全盘遍历卡死 35 分钟;codex 亲眼见协议仍绕开执行);leader 每步临场决策持续消耗 token;失败可能无限打转或静默。

业界方向(详见学习笔记"业界对标弹药库"):workflows 与 agents 是同一光谱两端(Anthropic 官方分类),按"任务步骤能否预先枚举"选层;生产系统普遍收敛于"确定性骨架 + 节点内 LLM 自主";最动态的框架(AutoGen)也在补确定性层,Cursor 底层用 Temporal。**在平台上补确定性 workflow 是被业界验证的补全,不是哲学对抗。**

### 1.2 终态全景:Multica 长出流程引擎

**一句话:Multica 还是那个 Multica,但多了一种任务形态——以前 issue 只能交给 AI 临场发挥,现在 issue 可以挂上一条"标准流程":平台自己按流程推进、验收、派发,不需要任何外挂工具。**

改造的全部核心,落在事件链的一个分支上,极小:

```
原来:子工单完成 ──► 唤醒 leader AI ──► AI 决定下一步

现在:子工单完成 ──► 这个工单挂了流程吗?
     ├─ 没挂 ──► 原路不变,唤醒 leader AI(一字不动)
     └─ 挂了 ──► 跑验收门 ──► 过:推进状态机,派下一个节点
                            └─ 不过:打回重做,超限通知人
```

这个分支背后是一个角色拆分的故事:leader AI 身上原本扛着两个职责--"下一步派谁"(决策)和"上个 agent 干完没、干得好不好"(验收)。现在决策交给状态机(确定性代码),验收交给验收门(确定性代码校验,或节点声明的 AI 评审员)。leader 没有被取代:灵活任务它照旧临场发挥,甚至流程里的某个节点也可以声明为"交给 leader 动态处理"。

**没变的东西(这是关键):**

- issue、评论、附件、agent 调度、daemon、沙箱:原样
- 不挂流程的普通 issue:照旧交给 leader AI 临场发挥,一条代码没动
- worker agent:无感——收到的还是平台原生任务,不知道自己身处流程,不用学任何新协议

**新增的东西:**

- 三张表:workflow_definition(菜谱)/ workflow_run(订单)/ node_run(工序),加 issue 与流程的应用层关联
- 界面:创建/编辑流程定义(表单,或让 AI 帮你生成、你确认);流程运行视图(哪个节点在跑/完成/失败,像看快递物流);失败时的决策按钮(重试/接受风险/放弃);定时与事件触发

**消失的东西:**

- 外挂 CLI 工具(原型期用它验证了模型,使命完成,逻辑并入平台)
- 轮询(原型期引擎每 30 秒问一次平台"干完没";现在是任务完成事件直接触发,零空转)

**运行起来的样子(周报):** 周一 9 点定时触发->平台自动建流程实例->建工单"收集本周数据"->叫醒 agent->agent 干完交证据->验收门核验(命令结果/产物检查)->自动派"撰写周报"->评审复核->周报发布,界面标绿,全程留痕可回放。中途任何节点失败:下游自动挂起不白干、重试有界、超限弹决策按钮等人;断电重启:状态在数据库,接着干,完成的不重跑。

### 1.3 核心设计思想(四条)

1. **拆解 leader**(故事见 1.2):决策确定化、验收声明化,leader 不被取代、可留在流程内。
2. **确定性骨架 + 节点内自主**:结构/推进/验收由定义和代码决定;节点内部 agent 充分自主。
3. **验收哲学**:agent 说 done 只是主张不是保证;确定性代码门前置 + 有界 LLM 评审后置(业界 grader 栈共识);交付以远端事实为准。
4. **共生嵌套而非并列替换**:workflow 是 issue 的可选属性,不是独立入口;leader 可把重复子任务派给流程,流程节点可以是动态步骤;真正要防的风险是入口割裂,不是哲学冲突。

### 1.4 两条铁律

1. **平台硬规则**(开发时必须遵守,来自 Multica 仓库 AGENTS.md 与源码调研):
   - 数据库不加外键/级联,关系在应用层维护,需要原子性用事务;
   - 每个索引用 `CREATE INDEX CONCURRENTLY`,单独迁移文件;
   - 事件只做"提前唤醒",正确性由 DB 条件写 + 兜底扫描保证(平台惯用法,见 2.3);
   - 原生路径零改动:不挂 workflow 的 issue 行为回归必须零变化。
2. **渐进交付**:每个阶段独立成立、独立可验收,不做大爆炸式整合。

---

## 二、OMAC 与 Multica 技术对照(事实层)

### 2.1 两个系统的角色

- **omac**(D:/agentlearn/oh-my-multica,Python,~27,000 行):外挂式工作流引擎原型。终局角色 = 内核版的**行为规格 + 对照实现**(双引擎对齐的基准),长期保留用于开发调试。
- **Multica**(D:/agentlearn/multica,Go server + Next.js):宿主平台,内核版的目标代码库。

### 2.2 OMAC 构成盘点(实测)

| 成分 | 占比 | 内容 |
|---|---|---|
| 编排本质 | ~50% | 五块核心 IP:**证据门校验**(evidence.py)、**评审收敛**(review_convergence.py,1131 行,最值钱)、**契约边界**(contract_boundaries.py:produces/consumes/依赖闭包)、**验收外层循环**(acceptance)、**amendment 受控变更**;外加 DAG 就绪推进(graph.py 仅 77 行)、返工预算、kind×phase 模型、plan 流水线、prompt 资产 |
| 外挂形态税 | ~33% | multica.py 适配层(90% 是税)/loop.py 的 2/3(handoff intent 全家/wake-pending 补偿/瞬时失败正则/hydration 编排)/gitsync/reconcile_audit/文件锁/CLI+web+i18n |
| 混合 | ~17% | config/dispatch 文案/delivery 标记机制等,拆开处理 |

### 2.3 Multica 已有设施(踩用它,带锚点)

| 设施 | 锚点 | 说明 |
|---|---|---|
| 任务队列与去重 | service/task.go:954+ EnqueueTaskFor*;migrations/037 (issue_id,agent_id) 唯一;task.go:1028 head_sha 去重 | 派发/去重/交接(WithHandoff)全有 |
| child-done/阶段闸门 | handler/issue_child_done.go:69/455/560 | 子任务终态->屏障关闭->唤醒父 assignee;服务端自述"no declarative workflow model" |
| 失败分类+有界重试 | migrations/055;task.go:4245 retryableReasons 白名单 | 瞬时失败(runtime_offline/timeout 等)自动重试,业务失败故意排除--与引擎语义几乎一致 |
| 定时/事件触发 | service/cron.go;migrations/113 sys_cron_executions(DB 级分布式租约);093 webhook_deliveries(持久化投递+幂等 admit);042 autopilot_trigger(schedule/webhook/api) | 触发层完整,复用 |
| PR 观测 | handler/github.go:1080/1899(MERGED webhook 才推 issue 到 done);091/096 check_suite+乱序 stash 重放;integrations/ghsnapshot(REST 兜底) | 远端事实确认闭环已有;**平台不主动 merge**(无 merge API 调用) |
| 可靠性骨架 | task.go:4797 runInTx;cmd/server/runtime_sweeper.go:113(30s 兜底扫描);scheduler/db_ops.go(lease/stale-steal) | 事务/幂等/自愈的平台惯用法 |

**两个重要事实**:①平台事件总线是进程内同步 pub/sub,无持久化--平台对策是"副作用幂等下沉 DB 唯一键 + 兜底扫描",内核版照抄此模式,不引外部队列、不自建消息级幂等;②issue_dependency 表是空壳(Go 代码零消费)。

### 2.4 能力对照表(引擎 12 项本质 × 平台状态)

| # | 引擎能力 | 平台状态 |
|---|---|---|
| 1 | DAG 状态机与就绪推进 | 部分(stage barrier 有,声明式模型无,失败传播 blocked 无) |
| 2 | kind×phase 阶段流转 | 部分(in_review/assign/handoff 有,结构化 phase 机无) |
| 3 | 有界返工预算+人工三出口 | 部分(基础设施失败有界重试有,业务返工预算无) |
| 4 | 证据门(命令匹配/验收覆盖/远端事实) | 部分(远端事实有,结构化校验无) |
| 5 | 评审收敛(verdict 分类/防漂移) | 真空缺 |
| 6 | 契约边界(produces/consumes) | 真空缺 |
| 7 | CI/merge 门 | 部分(CI 观测+MERGED->done 有,CLOSED_UNMERGED 回退无) |
| 8 | 受控定义变更 amendment | 部分(rule_version 版本化模式有,proposal->apply 流程无) |
| 9 | 验收外层循环 | 真空缺 |
| 10 | 瞬时/业务失败分离 | **已有**(直接复用) |
| 11 | LLM 生成定义+human-in-loop | 部分(manual run 模式有,定义对象无) |
| 12 | 定时/事件触发 | **已有**(直接复用) |

### 2.5 迁移清单(四类)

| 类别 | 内容 | 处置 |
|---|---|---|
| 零迁移 | 触发器/失败分类/PR 远端事实+MERGED->done/派发去重交接/事务与 sweeper 骨架 | 写薄胶水;**merge 执行留 agent 侧 gh CLI + 平台远端确认**(平台现成分工) |
| 搬语义不搬代码 | DAG 就绪推进/返工预算计数/CI 门判定 | Go 重写,量小 |
| 必须搬的核心 IP | 证据门 schema+规则/评审收敛/契约边界/验收外层循环/amendment 控制流 | 真正的迁移工作量 |
| 直接丢弃 | 外挂税全部:multica.py 适配层/gitsync/reconcile_audit/handoff intent/wake-pending/DeliveryIdentity/文件锁/CLI+web | 一行不搬 |

### 2.6 当前技术倾向(暂定,可被源码实况推翻)

- merge 闭环不搬:agent 侧执行 + 平台远端确认;
- issue_dependency 空壳不动(避免与上游未来用途冲突),workflow 自建 node_run 表带 blocked_by;
- 触发入口复用 autopilot_trigger(天然满足"入口不割裂",配置已在平台 UI);
- 事件可靠性照抄平台模式:条件 UPDATE 幂等 + sweeper 扫超时 RUNNING;
- omac 的 30+ metadata 键中,kind/phase/四类 bounce/verdict 等直接变 DB 列,handoff 基/identity 封印等补偿结构直接删。

---

## 三、开发计划 SPEC(压缩版混合路线)

### 3.0 路线总览

```
Phase A ✅ 引擎模型验证(外挂全链路跑通/源码调研/通用化设计/业界对标)
Phase B 🔧 外挂版通用化:delivery_mode 抽象落地 + weekly 全链路 + 基线数字
Phase C 📋 格式冻结与第三样本设计(文档化,混合流程实跑挪到内核时代)
Phase D 📐 内核实现(Go):本地环境 -> 三张表 -> 事件分支 -> 证据门
        -> 评审收敛 -> 双引擎对齐
Phase E 📐 平台整合:运行视图/决策交互/触发器/嵌套互通/引擎复验/固化叙事
```

路线理由:B 在外挂版上验证通用化(迭代半径最小),最先产出面试资产;C 把格式冻结成文档作为 D 的输入规格(bug_triage 混合流程在内核版上做反而更简单,不必在外挂版实跑);D 之后外挂版转型为对照实现。

### 3.1 Phase B:外挂版通用化

**B1 诊断** ✅(2026-08-19 Done;现场:Evidence/B1卡点清单.md,mocksite 全链路 3/3 收敛含评审)
- 目标:用 mock 引擎跑手写 weekly manifest,实测卡点。
- Done:卡点清单(每条带报错现场),对照 2.5 迁移清单校验预判。✓
- 实测修正:预判 pr_url 卡点在 mock 下"假过";真卡点 = lint pr_base 强制 + evidence pr_url 假过;另发现 merge 命令跟随 config.yaml engine 键不传导(排障手册);mocksite 隔离测试场成为后续回归资产。

**B2 交付形态骨架** ✅(2026-08-19 Done;现场:Evidence/B2验收记录.md;代码:omac commit 4f1773d)
- 目标:contract 增加节点级 delivery_mode(默认 pr,现有行为不变);**新建单一交付策略模块**,所有差异点指向它(不用散点 if,防散弹式修改);差异点以 B1 实测为准,不迷信预扫描。
- Done:①weekly manifest 声明面零 PR 字段过 check ✓;②现有 develop mock/e2e 回归相对基线零新增 ✓(Windows 本地 88 条预存环境失败,口径见排障手册问题 19);③mocksite 全链路 content 三节点收敛(含评审 verdict=pass)✓。
- 测试思路(TDD,红测试先行):content 模式 lint 通过/content 节点无 merge 收口/验证命令验收生效/PR 形态回归不变。全部落地(tests/test_delivery_mode.py 7/7)。
- 实测补录:差异点比 B1 预判多 4 处(merge 收口之外还有 PR 封印/done 终态 reconcile/评审因果基线),全部路由 core/delivery.py;评审机制在 content 下可用(verification 附件时间替代封印时间)。

**B3 真实基线**
- 目标:multica 引擎真跑 weekly,与原生 LLM 编排对比。
- Done:同场景/同 agent/同参数各跑 N 次,四组数字:总 token/总耗时/步骤数/失败率(token 从平台执行记录提取)。
- 要点:这是简历第 4 条空位的数据来源,不编数。

**B4 内容形态全链路**
- 目标:weekly 多节点(收集->撰写->评审)完整跑通 content 交付。
- Done:全流程收敛,产物为文档而非 PR;验证 content 形态下 reviewer/返工/收口行为。

### 3.2 Phase C:格式冻结与第三样本设计(文档化)

- 目标:产出《流程定义格式规范》:字段语义/验收规则/收口行为/交付形态声明;bug_triage 作 Spec 级第三样本(拆解设计+形态声明,预留"平台动作交付"扩展位)。
- Done:规范文档评审通过,可支撑 D 阶段解析器直接消费;格式在此冻结,D 期间变更需走"新事实"。
- 说明:混合流程(分析=content+修复=PR)的真实验证放在内核时代,不在外挂版实跑。

### 3.3 Phase D:内核实现(Go)

**D1 本地环境**
- 目标:Windows 本地跑通完整 Multica(server+Postgres+web+daemon+agent)。
- Done:本地环境完成一次真实的原生 agent 任务闭环;排障手册新增本地环境章节。
- 要点:这是 D 阶段最大不确定项,先行趟平;新坑即入排障手册。

**D2 数据层**
- 目标:三张表 workflow_definition/workflow_run/node_run + issue 关联(应用层维护,无外键);Go 版定义解析器消费 Phase C 冻结格式。
- Done:迁移文件符合平台硬规则(CONCURRENTLY 单文件);解析器对三形态样本(weekly/bug_triage/develop)解析一致。

**D3 事件分支**
- 目标:child-done 处理链加分支(挂流程->验收->状态机推进->复用 EnqueueTaskFor* 派发下游);PR webhook 路径挂钩。
- Done:①不挂流程的 issue 行为零变化(回归);②重复事件只推进一次(条件 UPDATE);③模拟事件丢失后 sweeper 兜底恢复。
- 要点:照抄平台 runtime_sweeper 模式做超时扫描;feature flag 控制生效范围。

**D4 证据门**
- 目标:Go 实现验证命令逐条匹配+验收条目全覆盖;PR 远端事实复用平台(github.go 挂钩,不重写)。
- Done:与外挂版 evidence 门对同一输入判定一致(用 B 阶段真实交付样本做对照)。

**D5 评审收敛**
- 目标:MVP=verdict 基本分类+有界轮次;blocker 身份保持/ledger 验签/防漂移机制延后到 Phase E。
- Done:reviewer 节点在内核跑通一轮通过/打回收敛。

**D6 双引擎对齐**
- 目标:同一组定义(三形态)在外挂引擎与内核引擎各跑,步骤序列断言一致。
- Done:对齐通过;外挂版自此定型为对照实现。

### 3.4 Phase E:平台整合(概要,允许无限后置)

| 项 | 内容 | 优先级 |
|---|---|---|
| E1 运行视图 | issue 详情嵌"属于流程 X(节点 2/5)";流程状态时间线 | 高 |
| E2 决策交互 | retry/accept/abandon 按钮+通知 | 高 |
| E3 触发器 | 对接 autopilot_trigger(定时/webhook/手动) | 高 |
| E4 嵌套互通 | leader 协议加"流程工具"(创建 run/查状态),像调工具一样派流程 | 中 |
| E5 引擎复验 | 验收门升级:平台经 daemon 在受控环境重跑验证命令,消灭 agent 申报的最后信任缺口 | 中 |
| E6 动态路径固化 | 观察 leader 重复路径,建议固化为流程并生成定义草稿 | 低(叙事加分项) |

### 3.5 贯穿工程线

1. **回归测试集**:B2 建立(develop 回归)-> B4 扩 content -> C 定稿三形态 -> D6 用于双引擎对齐 -> E 防 UI 改动破坏引擎。
2. **文档纪律**:每阶段 Done 时更新本文档状态+排障手册(新故障)+面试文档(新事实入简历/新追问入问答)。
3. **代码纪律**:omac 与 Multica fork 分仓;定义文件进 git;内核改动集中(新文件+一处分支)降低上游 rebase 冲突面。

---

## 四、面试节奏落点

时间线(相对顺序,非日期):

```
B3 完成 -> 简历第 4 条空位填上真实数字 -> 可约面试
B4/C   -> 面试期间进行,话术持续刷新
D 完成  -> 简历第 2 条"事件驱动版设计"升"实现";G2/G3 答案从设计变实战
E 完成  -> 终态全景从愿景变履历;"动态路径固化"成差异化故事
```

里程碑联动表:

| 里程碑 | 简历/问答升级 |
|---|---|
| B2+B4 | 第 1 条"交付形态抽象"从设计变事实;Q1.10 从[方案]升[已做] |
| B3 | 第 4 条空位填数字;Q4.3 从[待测]升[已做] |
| C | "三次抽象律"从方法论变真实经历 |
| D6 | 第 2 条升"实现";G3(分布式/事件)有实战答案 |
| E4 | "嵌套互通"从论证变产品事实;Q1.9 答案升级 |

---

## 五、风险与对冲(简表)

| 风险 | 对冲 |
|---|---|
| 本地环境(D1)趟不平 | 先行独立阶段;新坑入排障手册;极端情况回退云版+仅代码级测试 |
| 格式在内核期漂移 | Phase C 冻结;变更需"新事实"并记录 |
| 双引擎行为不一致 | D6 步骤序列断言;外挂版=行为规格 |
| 内核改动破坏原生路径 | feature flag + 原生回归零变化门槛 |
| 上游 Multica 更新冲突 | 改动集中;定期 rebase |
| 抽象边界有漏(B2 实测推翻预扫描) | 以 B1 实测卡点为准,不迷信文档 |

---

## 附录:资产索引

| 文档 | 位置 | 管什么 |
|---|---|---|
| 学习笔记-omca与multica协作机制.md | D:/agentlearn/learnezvibe | 机制认知+源码锚点速查(文件:行号) |
| 面试准备-简历问答拆解.md | D:/agentlearn/learnezvibe | 简历原文+37 问+P0+终态全景口述稿 |
| omac联调排障手册.md | D:/agentlearn/learnezvibe | 15 类故障+环境配置+Windows 补丁 |
| omca 源码 | D:/agentlearn/oh-my-multica | 外挂引擎 |
| Multica 源码 | D:/agentlearn/multica | 宿主平台(Go server + Next.js) |
| 关键 ID | workspace 466eb7c0 / project 6e64ba4b / codex agent 93b08860 / Mika c7b07bcb | 环境速查 |
