# B3 当前 Session 交接记录

> 记录日期：2026-08-19（Asia/Shanghai）  
> 记录范围：本 session 从用户批准开工到交接文档生成时的全部主要操作、证据、判断和下一步。  
> 当前结论：**S02 前置实现已部分完成，但 S02 gate 为 FAIL；B3 仍为 NO-GO。未执行 Desktop smoke，未执行四个正式样本。**

## 1. 任务合同与权威证据

本 session 按以下文件工作；下一 session 开始时必须重新阅读它们，不要只依赖本交接摘要：

- [B3 计划](D:/agentlearn/learnezvibe/plan/B3计划.md)
- [B3 开工前检查](D:/agentlearn/learnezvibe/Evidence/B3开工前检查.md)
- [B3 实验合同](D:/agentlearn/learnezvibe/Evidence/B3/protocol.md)
- [冻结输入](D:/agentlearn/learnezvibe/Evidence/B3/frozen-input.json)
- [配置快照](D:/agentlearn/learnezvibe/Evidence/B3/config-snapshot.json)
- [S02 前置验收记录](D:/agentlearn/learnezvibe/Evidence/B3/prerequisite-verification.md)
- [全量 pytest 未完成日志](D:/agentlearn/learnezvibe/Evidence/B3/pytest-full.txt)

冻结合同的核心目标没有改变：在相同冻结输入、相同角色 agent 配置、相同
`collect -> write -> review` 拓扑和相同验收目标下，对比 Multica Native squad
与 OMAC 编排；固定样本顺序为 `Native-01 -> OMAC-01 -> Native-02 -> OMAC-02`，
每组取得 2 个有效正式样本。`WEEK-9` 只是模板和预演参考，不能作为正式样本。

冻结的 OMAC 目标是三个业务节点各一次主调用：

| 节点 | 目标 agent | 目标 role | 依赖 |
|---|---|---|---|
| `collect` | `weekly-collect` | `collect` | 无 |
| `write` | `weekly-write` | `write` | `collect` |
| `review` | `weekly-review` | `review` | `write` |

`review` 不配置额外 OMAC reviewer。Native 组仍由“周报” squad 的 leader 自主拆解
和派发，但必须完成同一条三阶段业务拓扑。

## 2. 本 session 已执行的操作

### 2.1 读取与环境核验

1. 读取了 `交接信-新session.md`，确认 B3 目标、N=2、Multica/OMAC 真实联动要求、
   Windows 环境、`.venv` 测试入口和旧联调故障记录。
2. 读取了 `devola-flow` skill，并遵守其 L0/L1/L2 只调度和验收、L3 执行文件及
   测试的边界。
3. 重新读取 B3 计划和 S01 冻结证据，确认当前阶段是 S02，不得越过 gate 开始 S03
   或正式样本。
4. 复核了工作区状态、源码 diff、测试文件、`weekly.yaml`、Multica adapter、
   `WorkItemStore` 接口和 OMAC loop 的交接路径。
5. 复核平台前置事实：Desktop Codex runtime 仍为 online；CLI `multica daemon`
   保持 stopped；没有启动第二套 CLI daemon；没有修改 `WEEK-9`、squad 或 agent。
6. 确认旧取消 workdir 不能作为真实 Desktop smoke 证据；它只能说明曾经存在可调用的
   `omac 1.0.0`，不能证明本次 smoke 或正式样本闭环。

### 2.2 DevolaFlow 派发与 S02 实现

由于旧 completed agent 占用线程槽，常规 S02 层级派发多次遇到 `agent thread limit
reached`。在中断无效的旧代理后，最终使用了隔离的 S02 L3 任务执行源码和测试；没有
让 root 直接编辑源码。

当前 oh-my-multica 工作区的未提交改动为：

- [work.py](D:/agentlearn/oh-my-multica/src/omac/cli/commands/work.py)：增加
  `--content-file` 入口；`work read` 以 UTF-8 原始字节写出并校验 digest/字节数。
- [delivery.py](D:/agentlearn/oh-my-multica/src/omac/core/delivery.py)：允许从
  `Contract` 对象或平台读回的 mapping 解析 `delivery_mode`。
- [dispatch.py](D:/agentlearn/oh-my-multica/src/omac/pipeline/dispatch.py)：content
  模式使用 `--content-file + --verification-file`；提交前校验正文与 verification；
  通过 `WorkItemStore.update_work_item_metadata(deliverable=...)` 持久化；PR 模式
  仍使用 `--pr-url + --verification-file`。
- [mock.py](D:/agentlearn/oh-my-multica/src/omac/engines/mock.py)：mock deliverable
  生成可校验的 `deliverable_ref`，支持本地 source/ref 测试。
- [loop.py](D:/agentlearn/oh-my-multica/src/omac/pipeline/loop.py)：在依赖 source ref
  中带出上游 deliverable 的 `delivery_key`、SHA-256 和字节数。
- [test_content_submit.py](D:/agentlearn/oh-my-multica/tests/test_content_submit.py)：
  增加 content 参数、提交、持久化、source read、digest drift、PR 回归及 Multica
  adapter contract 测试。

Multica adapter 本身没有被本轮修改。源码检查确认它已有闭环：
`update_work_item_metadata(deliverable=...)` 调用 `_publish_payload_comment()`，以
附件和 metadata ref 保存正文；`get_work_item()` 再 hydration 读取附件。新增代码
复用了这个 `WorkItemStore` 接口，没有在 pipeline/CLI 中直接 shell 出平台 CLI。

### 2.3 OMAC manifest 配置调整

已更新外部仓库 `D:\agentlearn\learnezvibe\.omac\weekly.yaml`：

```text
collect.worker = weekly-collect
write.worker   = weekly-write
review.worker  = weekly-review
review.reviewer = absent
```

三个节点仍为 `delivery_mode: content`，依赖仍为 `collect -> write -> review`。
YAML 解析校验输出为：

```text
[('collect', 'weekly-collect', None),
 ('write', 'weekly-write', None),
 ('review', 'weekly-review', None)]
```

当前文件 SHA-256 为：
`7902c7e960f953fdd684b25f67e8a169bebcad30ef67da938e001c5e4cab261b`。
注意：S01 的 `config-snapshot.json` 记录的是配置修改前的观察值，文件中的旧 hash、
共享 worker 和额外 reviewer 不能当作当前配置事实；下一 session 必须重新生成或
追加一份变更后脱敏快照，并明确其与 S01 快照的差异。

## 3. 测试与验证结果

### 3.1 已通过的定向验证

- `.venv\Scripts\python.exe -m pytest tests/test_content_submit.py tests/test_delivery_mode.py -q`
  ：**12 passed**。
- 加上 `tests/test_cli_work.py::test_work_read_materializes_named_upstream_deliverable`：
  **13 passed**。
- `git diff --check`：通过。
- `weekly.yaml` YAML 解析和三角色映射检查：通过。
- `tests/test_engines_mock.py`：该分批执行中通过。
- content 测试覆盖了 MockStore 闭环和隔离的 Multica adapter contract；但没有真实
  Desktop/Multica 网络附件下载证据。

### 3.2 已观察到的失败或未完成验证

1. `tests/test_loop.py`：**512 passed, 2 failed**。失败是 Windows 临时绝对路径被
   CLI 参数规范化为无盘符路径；尚未证明由本轮 content 改动引入。
2. 旧的 5 个环境变量前缀断言失败：来自 `test_dispatch.py`、`test_tasks.py`。父提交
   对照确认测试文件未变；`daa225b` 的 Windows 修复已将 `_command_env_prefix()` 固定
   为空字符串，因为 PowerShell 不能执行 Bash 风格 `VAR=value command`。这 5 个失败
   是基线/旧断言不一致，不是本轮 content 改动回归。
3. 分批测试进一步观察到：
   - `test_cli_work.py` 有 1 个旧环境前缀断言失败；
   - `test_tasks.py` 有 2 个旧环境前缀断言失败；
   - `test_dispatch.py` 有 3 个旧环境前缀断言失败；
   - `test_engines_mock.py` 通过；
   - `test_engines_multica.py` 有 1 个 CRLF/LF 断言失败：实际读取为 `verdict: reject\r\n`，
     旧断言期待 `\n`；这是 Windows 换行基线问题，需独立归因。
4. 全量命令曾多次启动：

   ```text
   .venv\Scripts\python.exe -m pytest tests/ -q --tb=short --disable-warnings
   ```

   日志曾推进到 42%，但无终态 summary/退出码；因运行时间过长和平台相关等待被
   人工停止。日志保存在 [pytest-full.txt](D:/agentlearn/learnezvibe/Evidence/B3/pytest-full.txt)，
   目前只是一段部分输出，**不是全量通过证据**。
5. 分批运行发现 `tests/test_cli_plan.py` 的首个核心用例会因临时 YAML 使用系统默认
   编码而触发 `UnicodeDecodeError`（`0xCF`），单用例耗时约 1--2 秒；这同样是本地
   Windows 编码/测试 fixture 问题，需由下一 session 判断是否应补兼容或仅作基线记录。
   `test_cli_plan.py` 整体曾表现为无终态等待，因此不要无限重跑。
6. `python3` launcher 在当前 Windows shell 不存在；必须使用仓库 `.venv` 的 Python
   解释器。计划文字中的“完整 `python3 -m pytest tests/` 全绿”是合同要求，当前尚未
   满足；可用等价 Windows 命令时要在证据中写明实际命令和退出码。

## 4. 当前状态判定

| 项目 | 状态 | 说明 |
|---|---|---|
| S01 冻结合同/输入 | PASS | 冻结文件已落盘；见 `Evidence/B3/` |
| content submit 路由 | PARTIAL/PASS | 定向测试通过，真实平台尚未 smoke |
| deliverable store/ref | PARTIAL | Multica adapter 结构已有，网络附件读写未实测 |
| 下游独立 workdir read | PARTIAL | Mock/adapter contract 通过，真实 Desktop 未验证 |
| weekly worker 映射 | PASS（文件层面） | 当前 YAML 已三角色、无 reviewer；需 smoke 证明实际 run 拓扑 |
| review 单调用公平性 | 未验证 | 配置层面正确，平台实际 run 数未采集 |
| 全量 pytest | FAIL/INCOMPLETE | 无终态 summary/退出码；多项基线 Windows 失败 |
| Desktop smoke | NOT RUN | `Evidence/B3/smoke/` 尚无通过证据 |
| Native 正式样本 | NOT RUN | 禁止开始 |
| OMAC 正式样本 | NOT RUN | 禁止开始 |
| B3 总 gate | **NO-GO** | S02 未 PASS，不能进入 S03/S04 |

## 5. 关键问题与风险

### 5.1 冻结 revision 与未提交实现的身份问题

S01 的 `frozen-input.json` 记录 `oh-my-multica` HEAD 为 `4f1773d`；S02 实现目前仍是
工作区未提交 diff。正式运行前必须明确 OMAC 执行版本：

- 若 smoke/正式 agent 使用已安装的 `omac 1.0.0`，必须证明该安装包含本次 content
  实现；不能只看源码工作区。
- 若使用当前工作区代码，必须记录可复算的实现身份（提交、工作树 patch/hash、或
  安装包版本），并判断是否需要重新冻结合同；不能静默把未冻结代码混入正式样本。
- 不要因为 `frozen-input.json` 的 learnzvibe checkout HEAD 正确，就忽略 OMAC 实现
  身份。两者都要在 smoke 前留证。

### 5.2 全量测试 gate 未闭合

不要把 12/13 个定向通过替代全量 gate。下一 session 可以采用“按文件、有界超时、记录
首个阻塞点”的方式继续诊断，但必须保存每个命令、退出码、耗时和失败分类。若无法在
当前环境得到完整终态，应在 gate 记录中明确是环境阻塞，并由用户决定是否调整验收口径；
不能自行把它改成 PASS。

### 5.3 真正的 Desktop 联动仍未证明

现有测试没有证明 Desktop daemon 派出的 agent 能够：调用目标 OMAC 版本、checkout
固定 learnzvibe revision、读取同一 fixture/ref、跨独立 workdir 读取 deliverable。
这四项必须作为**非计量 smoke**逐项取原始 issue/run/run-message/usage/timestamp/ref
证据。smoke issue 必须明确标记为非计量，且不得占用四个正式样本槽。

## 6. 下一 session 的开始步骤

### 6.1 先恢复上下文

依次读取：

1. 本文件；
2. [B3 计划](D:/agentlearn/learnezvibe/plan/B3计划.md)；
3. [B3 开工前检查](D:/agentlearn/learnezvibe/Evidence/B3开工前检查.md)；
4. `Evidence/B3/protocol.md`、`frozen-input.json`、`config-snapshot.json`；
5. `Evidence/B3/prerequisite-verification.md` 和 `pytest-full.txt`；
6. 当前源码 diff、`learnezvibe/.omac/weekly.yaml` 和 `git status`。

### 6.2 重新核验 S02，不要直接跑 smoke

按以下顺序：

1. 验证没有遗留 `pytest`、`multica` CLI daemon 或未完成的旧代理进程。
2. 验证当前 `weekly.yaml` 三个 worker 和 reviewer 为空；重新计算 hash，并更新一份
   变更后脱敏配置证据，不覆盖 S01 原始快照。
3. 检查当前工作树 diff 是否只包含本 session 的 S02 文件；不要回滚用户已有改动，
   也不要把 `.agents/` 自动目录混入业务证据。
4. 用 `.venv\Scripts\python.exe` 运行 content 定向测试和必要的 adapter contract 测试，
   保存完整输出和退出码。
5. 对全量测试按文件分批、有界超时运行，优先记录 `test_cli_plan.py`、Windows 编码、
   CRLF 和环境前缀失败；判断哪些属于基线、哪些由当前 diff 引入。
6. 只有 S02 gate 的代码、配置和证据结论明确后，才进入 S03。

### 6.3 S03 允许的范围

S02 若能被用户/上层判定通过，才创建一个明确写明“非计量 smoke”的新 issue。只验证：

- Desktop daemon 实际调用目标 OMAC 版本；
- 独立 workdir checkout 到冻结的 learnzvibe revision；
- 四个 fixture 文件逐文件 SHA-256 和聚合 digest 一致；
- collect 交付经真实 attachment/ref 持久化，并由 write 的独立 workdir 读回相同字节；
- review 节点实际由 `weekly-review` 执行，且没有额外 reviewer 主调用；
- 保存原始 issue、run、run-message、usage、timestamp、附件/ref 和产物 hash。

CLI daemon 继续保持 stopped。smoke 不计入 B3 样本，不得修改 `WEEK-9`。

### 6.4 S04 正式样本前的最后检查

在任何正式 issue 前，必须同时满足：

- S02 gate PASS；
- S03 smoke 四项断言全部通过；
- OMAC 实际 worker mapping 与单调用拓扑被 run lineage 证明；
- Native/OMAC 两组拿到同一 fixture/ref，fixture 哈希一致；
- OMAC 实现身份与冻结合同一致或有用户批准的重新冻结记录；
- usage、run-message、timestamp、status 和 attachment/ref 均可导出；
- CLI daemon stopped，Desktop runtime online；
- 仍未使用 `WEEK-9`、旧取消 run 或 smoke run 作为正式样本。

然后严格串行执行：`Native-01 -> OMAC-01 -> Native-02 -> OMAC-02`。

## 7. 本 session 没有做的事

- 没有启动或完成 Desktop smoke。
- 没有创建或执行 Native/OMAC 四个正式样本。
- 没有把旧 `WEEK-9`、取消 run、smoke run 或 B4 reject/rework 数据混入 B3。
- 没有修改 `WEEK-9` 的描述，也没有修改 squad/agent 配置。
- 没有启动第二套 CLI daemon。
- 没有输出凭据、cookie、Authorization header 或完整带凭据 Git remote。
- 没有使用 destructive git 命令。

## 8. 交接结论

本 session 的实际产出是：S02 content 交付前置代码、回归测试、逐节点 OMAC manifest
映射和证据记录；这些产出使后续 smoke 有了可执行入口，但尚不足以证明真实 Desktop
联动，也不足以打开 B3 正式样本闸门。下一 session 必须从“验证 S02 和 OMAC 实现身份”
开始，而不是从创建正式 issue 开始。
