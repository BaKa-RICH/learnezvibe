# 交接信:新 Session 入口

> 写于 2026-08-19(承接 2026-08-17 版,状态已前进:B1/B2 完成)。新 agent 先读本文档 + 《项目总纲-Multica工作流引擎.md》+ Evidence 下的验收记录,按总纲核验源码后报告,再讨论开工。四份文档都在 learnezvibe。

## 一、入口指引(先读什么)

| 仓库/目录 | 角色 |
|---|---|
| D:/agentlearn/learnezvibe | 项目资产 + playground(四份文档 + Evidence/ + plan/ + mocksite/ + .omac 现场) |
| D:/agentlearn/oh-my-multica | 外挂引擎源码(omac,Python;HEAD = 4f1773d,B2 交付形态骨架已落地) |
| D:/agentlearn/multica | 宿主平台源码(Go server + Next.js),Phase D 的目标库 |

四份文档(均在 learnezvibe):**项目总纲**(行动:全景/技术对照/迁移清单/计划 B-E)、**学习笔记-omca与multica协作机制**(认知:机制/源码锚点/ID)、**面试准备-简历问答拆解**(表达:37 问/P0/终态全景/项目组合)、**omac联调排障手册**(环境:19 类故障/环境配置)。Evidence/ 存各阶段验收与卡点现场;plan/ 存各阶段计划。

## 二、当前状态与第一步(本 session 的任务)

**进度**:Phase A ✅ -> B1 ✅ -> B2 ✅,**B3 未开工**。总纲 3.1 已同步状态。

本 session 目标 = **从当前状态接着做 B3**,第一步是 B3 开工前的环境检查(与 B1 时相同的跨 session 检查):

1. `multica daemon status` 确认 daemon 存活;若 stopped 则 `multica daemon restart` 后复查。
2. 确认 agent 可用(代码评审与开发助手,codex agent 93b08860;Mika c7b07bcb),`multica issue` 或平台 CLI 查询成员/agent 存活。
3. 对照总纲 3.1 的 B3 小节写 `plan/B3计划.md`(核心决策点需用户参与:原生版手臂怎么跑/指令怎么给/N 取几/token 从哪抽),落盘后汇报,批准再执行。

B3 要点(总纲):multica 真引擎跑 weekly,与原生 LLM 编排对比,同场景/同 agent/同参数各跑 N 次,产出四组数字:总 token/总耗时/步骤数/失败率(token 从平台执行记录提取,不编数)。这是简历第 4 条空位的数据来源。

## 三、B1/B2 已完成的现场(新 agent 必读)

- **B1 卡点清单**:`Evidence/B1卡点清单.md`。5 卡点含修正:①lint 强制 pr_base(已解决 B2)②evidence pr_url mock 假过(已解决 B2)③dag check 第二道门 ④⑤ mock 引擎限制(修正后不影响全链路)。核心教训:差异点以实测为准,不迷信预扫描。
- **B2 交付形态骨架**:`Evidence/B2验收记录.md`;代码 omac commit `4f1773d`。实现了节点级 `delivery_mode: pr|content` + 单一策略模块 `src/omac/core/delivery.py`,7 处差异点(merge 收口/PR 封印/done 终态/评审因果基线/mock 假交付等)全部路由该模块。TDD:tests/test_delivery_mode.py 7/7。回归判定=相对基线零新增(Windows 本地 88 条预存环境失败,排障手册问题 19)。
- **mocksite 测试场**:`learnezvibe/mocksite/`(自有 .omac/config.yaml,engine: mock)。weekly 三节点 content 零 PR 字段全链路收敛含评审 verdict=pass 已验证。
- **正式草案**:`learnezvibe/.omac/weekly.yaml` 已声明 delivery_mode: content(零 PR 字段)。

## 四、协作约定(用户已定,勿犯已纠正过的错)

- 每讲必查源码,不猜;故事化讲解;用户先理解再推进,随时可打断。
- 术语口径:**简历/面试材料禁用"内核/二开/移植"等内部词**(用"事件驱动版");文档内部不受限。
- 简历写法:动词面向结果、括号只做轻举例、不做时间估算(vibe coding 共识)。
- 文档纪律:每阶段/大任务先写 plan/ 计划落盘+汇报,批准再执行;每个阶段 Done 更新总纲状态 + 排障手册 + 面试文档;面试文档更新要归位到条目,不是追加末尾;记录类文件落 Evidence/,计划类落 plan/(用户 2026-08-19 定下此归档规则)。
- 用户的尖锐追问往往就是面试题,追问后应更新面试文档(已验证多轮)。
- 指挥 AI 下指令四要素:读什么/做什么/禁什么/交什么;标准护身符两句:"禁改旧 .omac/manifest.yaml + 禁对已有 issue(尤其 WEEK-8)任何写操作"。机制细节见学习笔记第 11 节,本地部署见排障手册。

## 五、未落盘的决策记录(为什么)

- **MCP 支线已砍**:Multica 已有 MCP gateway(workspace_mcp_server 等表),引擎 MCP server 增量故事不成立,降为 E4 实现细节。
- **轨迹评测不立支线**:其有用部分已在主线 B3/回归测试集内。
- **路线选择论证**(新 agent 若重提"跳过 B/C 直做内核"时参考):纯外挂打磨把握约 90%、直接内核约 65-70%(本地环境/格式未冻结/迭代半径大)、混合路线 85-90%,故定混合路线。
- **GR(GPT Researcher)支线开工前需再派调研**(见面试文档附三)。

## 六、代码现场(截至交接)

- omac 仓库 HEAD = `4f1773d`(B2),工作区干净;历史 daa225b(Windows 补丁 5 处)。
- 测试环境:项目 `.venv/Scripts/python.exe` 已装 pytest(排障手册问题 18 有安装命令);`uv run pytest` 不保证可用。
- 排障手册已 19 问题;本地 Windows 全量回归有 88 条预存环境失败,回归判定用"相对基线零新增"口径(问题 19)。
- 关键 ID:workspace 466eb7c0-2554-45e6-91a8-6890663bb359 / project 6e64ba4b-8856-4ac2-aa24-a47b9169ae71 / codex agent 93b08860 / Mika c7b07bcb。
