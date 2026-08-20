# Multica × omac 联调排障手册(Windows)

> 适用环境:Windows + Git Bash + PowerShell + multica CLI v0.4.26 + oh-my-multica(omca) v1.0.0 + uv + codex agent
> 本文档记录联调过程中遇到的全部问题、根因与正确解法。
> 最后更新: 2026-08-20 (问题 20 根因定案为 hydration bug, 总览表补齐 20-24, 新增问题 24; 2026-08-20 S04 新增问题 25: agent 找不到引擎配置)
> 原则:**先看现场(日志/文件/命令输出),再下结论;所有结论基于源码核实,不靠猜。**

---

## 0. 背景:我们在干什么

omca(oh-my-multica)是一个 Python 编排引擎,通过 multica CLI 指挥 Multica 平台:
**manifest(流程说明书)→ omac(监理机器人)→ Multica(公司:工单+agent)→ codex(员工)**。

全链路:OMAC 读 manifest → 在 Multica 开工单 → 唤醒 agent → agent 跑 `omac work show` 读任务书
→ 干活(push 分支/开 PR/交证据)→ `omac work submit` → 机器验收(证据门)→ 合并 PR → 节点 done。

**最终成功标准(已达成)**:1 节点 manifest 完整跑通,PR #1 MERGED,exit 0。

---

## 1. 问题总览表(25 个,按出现顺序)

| # | 阶段 | 问题 | 根因类别 | 一句话修复 |
|---|---|---|---|---|
| 1 | 安装 | `ModuleNotFoundError: No module named 'fcntl'` | Windows 兼容 | fcntl → msvcrt.locking 跨平台封装 |
| 2 | 安装 | `UnicodeDecodeError: 'gbk' codec` | Windows 编码 | 所有文本读写补 `encoding="utf-8"` |
| 3 | 安装 | `AttributeError: 'NoneType' object has no attribute 'strip'` | 子进程解码 | subprocess 显式 UTF-8 + 空保护 |
| 4 | 运行 | `dag check` 过但 `dag run` 报 "Configuration not found" | Windows 路径 | `startswith("/")` → `os.path.isabs` |
| 5 | 运行 | 工单建了但唤醒失败 "contract attachment digest does not match" | Windows 换行 | 文本写加 `newline="\n"`(CRLF 翻译) |
| 6 | 运行 | Multica 拒绝建单 "Active duplicate issue exists" | 平台防重 | 旧工单 `issue status <id> done` |
| 7 | 运行 | codex 不执行协议命令(绕开 omac) | Shell 语法 | dispatch.py 去掉 bash 风格 env 前缀 |
| 8 | 运行 | codex 找不到 `omac` 命令 | agent PATH 沙箱 | omac.exe/cmd 放进 `~/.multica/bin` |
| 9 | 运行 | agent push 失败 "GitHub credential problem" | 凭据管理器不可读 | token 直写 URL 重写(gitconfig insteadOf) |
| 10 | 运行 | 交付后 "Remote PR HEAD observation failed [WinError 2]" | 缺 gh | gh 加 PATH + hosts.yml 认证 |
| 11 | 运行 | gh 认证报 "missing required scope 'read:org'" | token 权限 | 直接写 hosts.yml 绕过完整校验 |
| 12 | 工具 | uv tool install 装的是快照,源码修改不生效 | 安装方式 | 用 `uv tool install -e`(可编辑) |
| 13 | 工具 | daemon 环境不更新 | 进程环境快照 | 改 PATH 后必须 `multica daemon restart` |
| 14 | 工具 | Git Bash 的 /tmp 和 Windows python 不互通 | 路径差异 | 用 `cygpath -w` 转换后给 python |
| 15 | 工具 | 我自己的补丁脚本把 `\n` 写成真换行(SyntaxError) | heredoc 转义 | 用 write 工具写脚本文件再执行 |
| 16 | 平台 | 和 pi runtime 聊天,中文消息变 "???"(codex 正常) | PowerShell GBK | pi-node.cmd 包装器 + MULTICA_PI_PATH(见第 8 节) |
| 17 | 测试 | mock 引擎 `dag run` 节点反复 blocked("Merge confirmation failed"/sealed delivery 报错) | 配置传导 | merge 命令跟随 config.yaml 的 engine 键,`--engine mock` 覆盖不传导;用隔离测试场 mocksite/ |
| 18 | 测试 | 本地跑 omac 单测报 `No module named 'pytest'` | 测试环境缺失 | `uv pip install pytest --python .venv/Scripts/python.exe` |
| 19 | 测试 | Windows 本地全量回归 88 条预存失败,无法"全绿" | 环境基线 | 回归判定改"相对基线零新增":git stash 对比改动前后失败清单(comm -23 为空即过) |
| 20 | 集成 | Agent 上传附件但 OMAC evidence gate 拒绝 | OMAC 读回 bug | 修复 `206f3b4`: complete-unsealed 收口前补 hydrate verification (详见问题 20) |
| 21 | 集成 | Content 模式 protocol 冲突 (Contract vs Protocol) | 生成逻辑 | dispatch.py 按 delivery_mode 动态选 protocol (a605a34) |
| 22 | 集成 | OMAC 记住旧 DAG 状态需要 abandon | 状态持久化 | `omac node abandon` 或关 issue 后重跑 |
| 23 | 集成 | 如何验证 agent 是否正确运行 submit | 排查方法 | 四层验证: run 日志/submit 模板/评论附件/工作项状态 |
| 24 | 集成 | `dag check` 评审流程无限轮询挂死 | OMAC 轮询 bug | reviewer 只发文本 verdict 不写 review_verdict 元数据;规避 `--no-review` 或直接 dag tick (详见问题 24) |
| 25 | 集成 | agent 跑 `omac work show` 报 "Engine type is missing" | agent 环境缺引擎配置 | workdir 无 .omac/config.yaml 且无 env;给 weekly agents 设 OMAC_ENGINE/WORKSPACE_ID/PROJECT_ID (详见问题 25) |

---

## 2. 详细问题与解法

### 阶段一:安装与首次启动(问题 1-3)

#### 问题 1:`No module named 'fcntl'`

- **现象**:`omac init --check` 直接崩,`import fcntl` 报错。
- **根因**:`fcntl` 是 **Linux 专用**文件锁模块。omca 用它给 manifest 加互斥锁
  (防止两个 omac 进程同时改同一个 manifest)。Windows 没有。
- **位置**:`src/omac/core/manifest.py`(manifest_write_lock,3 处调用)。
- **解法**:用 Windows 等价物 `msvcrt.locking` 做跨平台封装,保留非阻塞独占锁语义:
  - Windows:`os.lseek(fd,0,0)` → `msvcrt.locking(fd, msvcrt.LK_NBLCK, 1)`(锁 1 字节)
  - 空文件先写 1 个占位字节再锁
  - 锁冲突时抛 `BlockingIOError`(与 fcntl 路径一致,调用方 catch 不变)
  - Linux/macOS 保留原 fcntl 分支
- **验证**:`omac init --check` 越过此错误。
- **防复发**:任何 Linux 写的 Python 工具上 Windows,第一波基本都是 fcntl/信号量/unix 专用模块。

#### 问题 2:`UnicodeDecodeError: 'gbk' codec can't decode`

- **现象**:读到含中文的 config.yaml 时崩溃(GBK 是 Windows 中文版默认编码)。
- **根因**:omca 源码所有 `open(path)` 都没指定编码 → Windows 上用 GBK 解码
  → UTF-8 写的中文文件必炸。
- **解法**:全部文本读写显式 `encoding="utf-8"`:
  - `src/omac/core/config.py`(load/save config)
  - `src/omac/core/manifest.py`(load manifest)
  - `src/omac/engines/multica.py`(fdopen 临时文件)
- **防复发**:Windows 上写/改任何 Python 文件读写,一律 `encoding="utf-8"`。
  检查:`grep -rn "open(" src/ | grep -v encoding= | grep -v 'rb\|wb'`。

#### 问题 3:`AttributeError: 'NoneType' object has no attribute 'strip'`

- **现象**:`_run_multica` 里 `result.stdout.strip()` 崩。
- **根因**:`subprocess.run(..., text=True)` 在 Windows 上解码行为不同 + 无空保护。
- **解法**(`src/omac/engines/multica.py::_run_multica`):
  - `subprocess.run` 显式 `encoding="utf-8", errors="replace"`
  - `if capture and (result.stdout or "").strip()`
- **防复发**:所有 subprocess 文本捕获都带 `encoding + errors="replace"` + 空保护。

---

### 阶段二:config 与运行(问题 4-6)

#### 问题 4:`dag check` 过、`dag run` 报 "Configuration not found"

- **现象**:`dag check` 正常(lint 通过),`dag run` 却报
  `Configuration not found: D:\...\config.yaml. Run omac init first.`,但文件明明在。
- **根因**(`src/omac/core/gitsync.py::ensure_config_synced`):
  ```python
  abs_path = config_path if config_path.startswith("/") else f"{repo_root}/{config_path}"
  ```
  判断"是否绝对路径"只认 POSIX 写法(`/` 开头)。Windows 盘符路径 `D:\...`
  不以 `/` 开头 → 被当成相对路径 → 拼出 `./D:\...` 的假路径 → 找不到。
  而 `dag run` 比 `dag check` 多走一步 `ensure_config_synced`(把 config 自动
  commit+push 到 git,给 agent clone 用),所以 check 过、run 挂。
- **解法**:`config_path.startswith("/")` → `os.path.isabs(config_path)`(跨平台正确)。
- **防复发**:Windows 上判断绝对路径一律用 `os.path.isabs`,别用 `startswith("/")`。

#### 问题 5:工单建了、唤醒失败 "contract attachment digest does not match"

- **现象**:`node_failed ... reason='Failed to wake worker 代码评审与开发助手'`,
  工单评论里完整异常:`Downloaded contract attachment digest does not match declared SHA-256`。
  下载的附件 777 字节 vs 声明的 750 字节。
- **根因**:**CRLF 换行翻译**。Python 在 Windows 上 `open(path, "w")` 默认把 `\n`
  翻译成 `\r\n` 写盘。omca 算 sha256 用内存字符串(LF,750 字节),但写进磁盘的
  附件文件是 CRLF(777 字节 = 750 + 27 个 \r),上传的自然是 CRLF 版本 →
  唤醒时下载回来字节对不上 → digest 校验失败。
- **定位过程**(值得记的方法):
  1. 看工单评论拿完整异常
  2. 看源码找到 digest 校验点(上传算 sha → 下载再算 → 比对)
  3. 下载附件实测 sha256 ≠ 声明值,且字节数多了 27 → 字节真变了
  4. **往返实验**:用纯 LF 文件上传下载 → 原样回来 → 排除服务器转码
  5. 十六进制看下载文件:`0d 0a`(CRLF)→ 元凶是本地写入
- **解法**:所有文本写入加 `newline="\n"`(与 encoding="utf-8" 配套,共 7 处):
  - `src/omac/engines/multica.py`(payload 附件/评论、--content-file 等 5 处 fdopen/open)
  - `src/omac/core/config.py`(save_config)
  - `src/omac/core/manifest.py`(save_manifest)
- **防复发**:**编码(encoding)和换行(newline)是两个独立的坑,修一个不算修完。**
  Windows 上 `open(path,"w")` 默认 = GBK 编码 + CRLF 翻译,两个都要显式指定。

#### 问题 6:Multica 拒绝建单 "Active duplicate issue exists"

- **现象**:重置 manifest 重跑 `dag run` 时:
  `Active duplicate issue exists: WEEK-4 [DAG:node1] node1 (status: blocked)`。
- **根因**:Multica 服务器按标题防重:同名 issue 还处于活跃状态(blocked)时,
  不允许再建同名的。
- **解法**:把旧工单置为终结状态:`multica issue status <旧id> done`。
- **防复发**:重置重跑前,先查同名旧工单并置 done(或改名)。

---

### 阶段三:agent 行为与交付(问题 7-11)——最耗时的部分

#### 问题 7:codex 不执行协议命令(绕开 omac 自己干)

- **现象**:codex 收到工单后,不执行描述里的"第一动作必须精确执行
  `omac work show <id>`",而是自己 `multica issue get`、手动改状态、手动评论。
  连续 4 轮 run 从未尝试过 omac 命令(核实 run-messages 里没有任何 omac 命令)。
- **根因**:描述里的协议命令是 **bash 风格 env 前缀**:
  ```text
  OMAC_ENGINE=multica OMAC_WORKSPACE_ID=... OMAC_PROJECT_ID=... omac work show <id>
  ```
  在 PowerShell(agent 的 shell)里 `VAR=val cmd` 是**语法错误**。
  LLM 无法执行"精确命令"后,选择了绕开协议自己干(它以为任务只是小编辑)。
- **解法**(`src/omac/pipeline/dispatch.py::_command_env_prefix`):直接返回空串。
  engine/workspace/project 本来就在 config.yaml 里,env 前缀是冗余的;去掉后命令
  `omac work show <id>` 在 bash/PowerShell 都合法。
- **验证**:改后新工单描述里是干净的 `omac work show <id> --output json`,
  codex 这次真的执行了 submit(交付里有 pr_url + verification 附件)。
- **教训**:**给 agent 的指令必须是目标 shell 可执行的精确命令**;跨平台时用
  最简单的形式(能从 config 读的不要用 env)。

#### 问题 8:codex 找不到 `omac` 命令

- **现象**:即使命令干净,codex 依然不执行 omac(4 轮都没跑过一次)。
- **根因**:daemon 给 agent 的**受管 shell 环境**(codex 的 config.toml 里
  `shell_environment_policy.include_only` 白名单 + 沙箱)不含 `~/.local/bin`
  (uv tool 安装 omac 的位置)。agent 能找到 multica(在 `~/.multica/bin`),
  但找不到 omac。
- **解法**:把 omac 放进 **agent 确定能找到的目录** `~/.multica/bin`:
  - 复制 `~/.local/bin/omac.exe` → `~/.multica/bin/omac.exe`(pip 启动器自带解释器路径,复制可用)
  - 另写 `omac.cmd` 包装:`@"C:\Users\...\.local\bin\omac.exe" %*`
- **验证**:复制后直接运行 `~/.multica/bin/omac.exe --version` → `omac 1.0.0`。
- **防复发**:agent 环境变量/工具可见性 = **daemon 启动时的环境**,不是你的终端环境;
  不确定时把工具放 `~/.multica/bin`(与 multica.exe 同级)最稳。

#### 问题 9:agent push 失败( GitHub 认证 )

- **现象**:codex 提交了 commit,但 push 报 "GitHub credential problem";
  daemon 日志里有 `fatal: Unable to persist credentials with the 'wincredman'
  credential store` 和 `could not read Username`(无 tty,提示失败)。
- **根因**:agent 进程读不到 Windows 凭据管理器(wincred/GCM)里的 GitHub 凭据。
  奇怪的是:同用户同会话,我的 PowerShell 里 `git credential fill` 能读到 token,
  agent 的进程却读不到(沙箱/进程令牌差异,未彻底定位,用确定性方案绕开)。
- **解决过程**:
  1. 先确认基础事实:用户 git 走代理 `http://127.0.0.1:7892`(全局 gitconfig,GFW 环境必备);
  2. GCM 在 `D:\Git\mingw64\bin\git-credential-manager.exe`(不在 Windows PATH,加进用户 PATH);
  3. 重启 daemon 让新 PATH 生效(否则 agent 还是旧环境);
  4. 验证 PowerShell(模拟 agent 环境)下 `git ls-remote` 全链路 OK;
  5. 但 agent 沙箱仍失败 → 放弃 GCM 依赖,**用确定性方案**。
- **确定性解法**(token 直写 URL,绕开 GCM/存储/交互):
  ```powershell
  # 从凭据管理器读 token(不打印)
  'protocol=https','host=github.com' | git credential fill
  # 写入 URL 重写(全局 gitconfig,agent 继承)
  git config --global --add url."https://<TOKEN>@github.com/.insteadOf" "https://github.com/"
  ```
- **验证**:PATH 里只留 `D:\Git\cmd` + 系统目录(模拟 agent 最小环境,无 GCM),
  `git ls-remote https://github.com/...` 直接返回 HEAD → 证明不再依赖 GCM。
- **安全提示**:token 明文躺在 `~/.gitconfig`。长期用建议换成 GitHub fine-grained PAT
  (仅授权目标仓库)。learnzvibe 是游乐场,风险可控。
- **防复发**:给 agent 的 git 操作,用 URL 内嵌凭据或 CI token,别依赖交互式凭据管理器。

#### 问题 10:交付后 "Remote PR HEAD observation failed [WinError 2]"

- **现象**:PR 已创建成功,但 omac 报:
  `Remote PR HEAD observation failed for https://github.com/.../pull/1: [WinError 2] 系统找不到指定的文件`。
- **根因**:`[WinError 2]` = 文件/程序找不到。看源码
  (`src/omac/engines/multica.py::read_pull_request_readiness`)发现 omac 用
  **`gh pr view <url> --json isDraft,state,headRefOid`** 观察 PR——你的机器上
  gh 虽然装了(`C:\Program Files\GitHub CLI\`),但**不在 PATH**里,subprocess 找不到。
- **解法**:
  1. `C:\Program Files\GitHub CLI` 加进用户 PATH;
  2. 用已有 GitHub token 认证 gh(见问题 11);
  3. 验证:`gh pr view <url> --json isDraft,state,headRefOid` 返回 JSON。
- **防复发**:装完新工具先确认它在 PATH(新终端里 `which` 一下)。

#### 问题 11:gh 认证报 "missing required scope 'read:org'"

- **现象**:`echo <token> | gh auth login --with-token` 报
  `error validating token: missing required scope 'read:org'`。
- **根因**:GCM 里的 token 权限不够 gh 完整登录校验的要求(gh 要求 repo/read:org 等)。
  但 omac 只需要 `gh pr view`(公开仓库读操作),不需要完整登录。
- **解法**:绕过校验,直接写 gh 的认证配置(Windows 路径是
  `%APPDATA%\GitHub CLI\hosts.yml`,**不是** `~/.config/gh/`):
  ```yaml
  github.com:
      oauth_token: <TOKEN>
      user: BaKa-RICH
      git_protocol: https
  ```
- **验证**:`gh auth status` → `✓ Logged in to github.com account BaKa-RICH`;
  `gh pr view` 直接返回 PR JSON。
- **防复发**:gh 配置目录按平台不同(`gh config` 相关命令可查),别套 Linux 路径。

---

### 阶段四:工具链踩坑(问题 12-15)

#### 问题 12:uv tool install 装的是快照,源码修改不生效

- **现象**:改完 omca 源码,agent/终端里的 omac 行为不变。
- **根因**:`uv tool install <path>` 默认装的是**快照**,不跟踪源码变化。
- **解法**:用可编辑安装 `uv tool install -e <path>`(源码变更即时生效,二开必须)。
- **验证**:`find %APPDATA%\uv\tools\<name> -name "*.pth"` 或直接验证加载路径指向源码。
- **防复发**:开发期一律 `-e`。

#### 问题 13:改 PATH 后 agent 环境不更新

- **现象**:改了用户 PATH,agent 还是找不到新工具。
- **根因**:daemon 继承的是**启动时**的环境,不会动态刷新。
- **解法**:任何环境变更( PATH/安装 )后执行 `multica daemon restart`。
  重启会中断正在跑的任务——先确认没有任务在跑。
- **验证**:`multica daemon status` 看 uptime/pid 变了。

#### 问题 14:Git Bash 的 /tmp 和 Windows python 不互通

- **现象**:bash 里 `> /tmp/x.json` 写文件,Git Bash 的 grep 能读,但 Windows 原生
  python(venv/anaconda)读不到 `/tmp/...`。
- **根因**:Git Bash 的 `/tmp` 是虚拟挂载,Windows 程序不认识。
- **解法**:`cygpath -w /tmp/x.json` 拿到 Windows 路径再喂给 python。
- **防复发**:跨 shell 传文件路径,统一用 Windows 路径或项目内相对路径。

#### 问题 15:heredoc 里写 `\\n` 被弄成真换行(SyntaxError)

- **现象**:补丁脚本 `newline="\\n"` 写进文件后变成真换行,Python 语法错误
  (`unterminated string literal`)。
- **根因**:bash heredoc + 多层转义不可控(具体在哪层被处理未复现)。
- **解法**:放弃 heredoc,**用 write 工具写一个 .py 修复脚本文件**再执行,
  一次性修完 7 处。
- **防复发**:凡是含转义序列的批量修改,先写成脚本文件,别用内联 heredoc。

### 阶段五:引擎测试环境(问题 17-18)

#### 问题 17:mock 引擎 dag run 节点反复 blocked(merge 命令用错)

- **现象**:`omac dag run <manifest> --engine mock` 跑 develop 节点,dispatch 后节点 blocked:
  无 contract 时 reason='Merge confirmation failed';带 contract 时 PlatformError
  "Current delivery projection does not match sealed identity"。
- **根因**:merge 命令解析(`config.py resolve_merge_command`)读 **config.yaml 的 engine 键**,
  CLI `--engine mock` 覆盖**不传导**。learnezvibe/.omac/config.yaml 是 `engine: multica` ->
  mock 引擎跑却执行真 `gh pr merge <假URL>` -> 必失败 -> 节点 blocked。
  单测能过是靠 autouse fixture patch 掉 gh 命令(tests/test_loop.py 顶部),本地直跑必现。
- **解法**:建隔离测试场(如 `learnezvibe/mocksite/`,自有 `.omac/config.yaml` 声明
  `engine: mock` + `engine_extra` 传 MOCK_AUTO_COMPLETE_DELAY 等),manifest 放同目录,
  config 按 manifest 同目录解析自动生效。
- **验证**:mocksite 全链路 3 节点收敛(converged done=3,含 reviewer verdict=pass)。
- **通用教训**:CLI 引擎覆盖只影响引擎创建,不影响 config 语义解析;凡是"按
  `config.get('engine')` 分叉"的逻辑(merge 命令/mock-vs-gh)都会踩这个坑。


#### 问题 19:Windows 本地全量回归 88 条预存失败,无法做到"全绿"

- **现象**:`pytest tests/ -m "not live"` 在干净基线(daa225b)上就有约 88 条失败
  (test_taskmeta 20 / test_cli_plan 19 / test_multica_attachment_retry 14 / web_static 全量等,
  GBK 编码与 Windows subprocess 环境类,CI/Linux 上应正常)。
- **根因**:本地 Windows 环境 vs CI 环境差异;与任何代码改动无关(基线即失败)。
- **解法**:回归门槛改为**"相对基线零新增"**:
  ```bash
  pytest tests/ -q -m "not live" --ignore=tests/test_web_static.py 2>&1 | grep "^FAILED" | sort > /tmp/now.txt
  git stash && pytest ... | grep "^FAILED" | sort > /tmp/base.txt && git stash pop
  comm -23 /tmp/now.txt /tmp/base.txt   # 空输出 = 零新增 = 回归通过
  ```
- **通用教训**:环境不完整的本地跑不了"全绿"时,回归判定的正确口径是**对比基线的差分**,
  而不是绝对绿灯;差分口径要写进验收记录留痕。

#### 问题 18:本地跑 omac 单测报 No module named 'pytest'

- **现象**:`python -m pytest` / `uv run pytest` 找不到 pytest(structlog 同理可能缺失)。
- **根因**:omac CLI 用 `uv tool install -e` 安装(uv tool 环境带运行依赖),但项目 `.venv`
  没装测试依赖;pyproject 也没声明 dev 依赖组,`uv sync` 只解析运行依赖。
- **解法**:`uv pip install pytest --python .venv/Scripts/python.exe`,
  之后 `.venv/Scripts/python.exe -m pytest tests/...`。
- **验证**:test_loop.py::TestHappyPath::test_linear_dag_converges 本地通过。
- **通用教训**:CLI 安装环境 ≠ 测试环境;两套环境要分别确认。

---

### 阶段六:B3 真实集成问题 (问题 20-23)

#### 问题 20: Agent 上传附件但 OMAC evidence gate 拒绝

- **现象** (2026-08-19 B3-S03):
  - OMAC 编排的 collect/write 节点执行完成
  - Agent 上传了 verification 和 deliverable 附件
  - Agent 发表了完成评论
  - 但 OMAC 判定: `node_failed: Worker evidence gate: verification is required`
  - 两次尝试 (collect, write) 都是同样错误
- **根因** (2026-08-20 已定案): OMAC loop 读回 bug——`complete-unsealed` 收口分支没 hydrate verification 附件。**不是 agent 的问题**。早先"70% agent 没跑 submit"的猜测已被证伪: 用真实平台数据 (WEEK-13) 复现, agent 的 submit 完全合法 (metadata 有 verification_ref/deliverable_ref, uploader_type=agent), verification 数据直接喂证据门是 0 错误。
- **bug 链条**: dispatch 写 handoff intent → reconcile 的 hydration plan 对 handoff 只预载 CONTRACT (PR 形态假设封印观察会自读附件) → content 分支 complete-unsealed 免封印不读附件 → DONE 分支证据门在 verification=None 上误判 `verification is required`。
- **修复** (commit `206f3b4`): collect_results 的 complete-unsealed 分支清 handoff 后补调 `_hydrate_worker_collect_evidence` (与 PR 封印路径 `_finalize_worker_handoff_delivery` 同款调用)。回归测试 `test_content_delivery_handoff_collect_hydrates_verification_before_gate`, 全量 101 失败基线零新增。
- **验证**: 真实环境 write/review 过门 + 全新 S03 smoke 三节点一次过门 (零 gate 失败评论)。
- **详细分析**: `Evidence/B3/s03-rootcause-fix-20260820.md`、`Evidence/B3/smoke/s03-final-pass.md`
- **通用教训**: 附件上传且 metadata ref 正确 ≠ 证据门通过; 引用式附件需要"搬运"(hydrate) 才进得了 gate, 新增交付捷径时必须同步搬运逻辑。

#### 问题 21: Content 模式 protocol 冲突 (Contract vs Protocol)

- **现象** (2026-08-19 B3-S03 第一次):
  - weekly.yaml Contract 声明: `delivery_mode: content`
  - 但 agent 收到的 protocol 文本: "Push a branch and open a PR..."
  - Agent 收到矛盾指令,困惑
- **根因** (`src/omac/pipeline/dispatch.py`):
  - S02 修改了代码逻辑 (dispatch.py, delivery.py 支持 content)
  - 但 `_next_action()` 生成 protocol 时没有根据 `delivery_mode` 分支
  - Protocol 文本硬编码为 PR 模式
- **解法** (commit a605a34):
  ```python
  # i18n.py: 新增 content 模式 protocol 文案
  "work.protocol.develop_content": "Use content delivery mode (no PR required)..."
  
  # dispatch.py: 动态选择 protocol
  def _next_action(kind, phase, language, contract=None):
      if kind == TaskKind.DEVELOP and contract and is_content_delivery(contract):
          action = t("work.protocol.develop_content", language=language)
      else:
          action = t(key, language=language) if key else ""
  ```
- **验证**: Protocol 文本已正确,但问题 20 仍存在 (说明问题更深)
- **通用教训**: Protocol 文本是 agent 的关键输入,必须与 Contract 一致

#### 问题 22: OMAC 记住旧 DAG 状态需要 abandon

- **现象** (2026-08-19 B3-S03 重试):
  - 重新运行 `omac dag run .omac/weekly.yaml`
  - OMAC 报告: nodes already blocked
  - 无法开始新的执行
- **根因**: OMAC 把 DAG 状态持久化了,记住了之前的失败
- **解法**:
  ```bash
  # 放弃失败的节点
  omac node abandon .omac/weekly.yaml <node-key>
  
  # 或者关闭相关 issues
  multica issue status <issue-key> done
  
  # 然后重新运行
  omac dag run .omac/weekly.yaml
  ```
- **验证**: Abandon 后可以重新开始
- **通用教训**: OMAC 的状态管理需要理解; 失败后重试需要先清理状态

#### 问题 23: 如何验证 agent 是否正确运行 submit

- **背景**: 问题 20 需要确认 agent 的实际行为
- **检查方法**:
  1. **查看 agent run 日志**:
     ```bash
     multica issue runs <issue-key>
     # 如果有详细日志,查看是否有 `omac work submit` 命令
     ```
  2. **检查 submit 模板**:
     ```bash
     omac work show <work-item-id> --output json | grep -A 10 "submit"
     # 确认是 --content-file 还是 --pr-url
     ```
  3. **查看 issue 评论和附件**:
     ```bash
     multica issue comment list <issue-key>
     multica issue get <issue-key>
     # 检查附件类型和内容
     ```
  4. **检查 OMAC 的工作项状态**:
     ```bash
     omac work show <work-item-id> --output json
     # 查看 task.status 和相关 metadata
     ```
- **常见判断**:
  - Agent run 是 completed ✅
  - 有 verification/deliverable 附件 ✅
  - Evidence gate 通过 ✅
  - 节点状态变为 done ✅
  - **如果前两个 ✅ 但后两个 ❌**: 说明附件上传了,但没有正确 submit
- **通用教训**: 需要多层次验证,不能只看表面状态

#### 问题 24: `dag check` 评审流程无限轮询挂死

- **现象** (2026-08-20, WEEK-11/15 两次复现):
  - `omac dag check <manifest>` 对新建 manifest 跑 lint 后进入"plan-check 评审"流程
  - 创建 `[DAG:plan-check]` issue 并派发给 reviewer agent (代码评审与开发助手)
  - reviewer 在评论里写了 "Verdict: REJECT" 文本
  - 但命令**不退出**, `while True` 无限轮询, 前台挂死 44 分钟 (直到人工中止)
- **根因** (`src/omac/pipeline/review.py` `run_review`):
  - 轮询循环只认 work item 的结构化 `review_verdict` 元数据 (pass/pass-with-nits/reject)
  - 该 reviewer agent 只发文本评论, **从不写 `review_verdict` 元数据**
  - `while True` 轮询**无超时、无人工逃生口** → 永远等一个不会来的字段
  - WEEK-11 (2026-08-19) 同样: agent 只交 deliverable 附件, `review_verdict` 空, 当时也是挂死后人工处理
- **规避方式**:
  ```bash
  # 只做 lint,跳过 agent 评审 (manifest 是拷贝/已验证时用)
  omac dag check <manifest> --no-review
  # 或干脆跳过 check,直接跑 (dag run/tick 不依赖 check 通过)
  omac dag tick <manifest>
  ```
- **建议**: 作为 OMAC backlog bug 修复——`run_review` 轮询加超时 + 检测 reviewer 未按协议提交时给出人工逃生口 (或校验 reviewer 必须走 `omac work submit` 结构化提交)
- **通用教训**: 命令可能远比名字暗示的复杂; `check` 不是静态校验而是完整评审流程, 涉及平台/agent 的命令一律带 timeout 或后台跑, 没读过源码先读源码

---

#### 问题 25: agent 跑 `omac work show` 报 "Engine type is missing"

- **现象** (2026-08-20, S04 OMAC-01 collect run f34cb5e0):
  - OMAC 派发的 collect agent 读到自己工单上的 sealed contract 后, 执行 `omac work show <issue> --output json`
  - 返回 `ValidationError: Engine type is missing. Set config.yaml engine, environment variable OMAC_ENGINE, or --engine.`
  - agent 以"Blocked by the issue's sealed OMAC contract"结束, 不交付
- **根因** (agent workdir 无引擎配置):
  - omac 的 `load_config` 只读 cwd 下 `.omac/config.yaml` (config.py CONFIG_PATH)
  - agent workdir (multica_workspaces/.../workdir) **不是 repo 全量 checkout**, 只有 AGENTS.md + .multica, 没有 .omac/config.yaml
  - 配置另可从 env `OMAC_ENGINE/OMAC_WORKSPACE_ID/OMAC_PROJECT_ID` 提供
  - **为什么 smoke 没踩到**: smoke 的 collect agent 自己机灵地 `$env:OMAC_ENGINE=...` 再跑 omac (run-message 里可见), 碰巧兜底; 但这是依赖 agent 运气
- **修复** (基础设施接线, 不改模型/thinking/runtime):
  ```bash
  # 给三个 weekly agent 设置持久 env (multica agent env set, 用 --custom-env-file)
  {"OMAC_ENGINE": "multica", "OMAC_WORKSPACE_ID": "<workspace>", "OMAC_PROJECT_ID": "<project>"}
  ```
- **通用教训**: 靠 agent 临场自愈的"碰巧能跑"不是真配置; 正式采样前要把依赖运气的地方变成确定配置。另一个判读提醒: 大批会话同时空转/截断时先查账号余额/资源(问题 25 同窗口即 codex 欠费所致), 别急着改架构。

---

## 3. omca 源码补丁清单(本次累计,全部为 Windows 兼容修复)

```text
src/omac/core/manifest.py   fcntl → msvcrt 跨平台文件锁;load_manifest 补 utf-8;save 补 utf-8+newline
src/omac/core/config.py     load/save 补 utf-8(+newline)
src/omac/core/gitsync.py    startswith("/") → os.path.isabs
src/omac/engines/multica.py subprocess 显式 utf-8+errors+空保护;fdopen/open 补 utf-8+newline(共 5 处)
src/omac/pipeline/dispatch.py _command_env_prefix 恒返回空串(去 bash 前缀)
```

回滚方式:`cd D:\agentlearn\oh-my-multica && git checkout -- <文件>`。

---

## 4. 一次性环境配置清单(新机器照做)

```powershell
# 1. multica CLI + 登录 + daemon
multica setup                        # 或:装 CLI → multica login → multica daemon start

# 2. omac(可编辑,全局)
uv tool install -e D:\agentlearn\oh-my-multica
# 若已装快照:uv tool uninstall oh-my-multica 再装

# 3. agent 能找到 omac(关键!)
copy ~\.local\bin\omac.exe ~\.multica\bin\omac.exe
# 写 ~\.multica\bin\omac.cmd: @"C:\Users\<user>\.local\bin\omac.exe" %*

# 4. git/GCM/代理
# - 确保 D:\Git\mingw64\bin 在用户 PATH(GCM 所在)
# - 确保代理(如 127.0.0.1:7892)在跑,gitconfig 有 proxy 配置
# - token 注入 URL 重写(绕 GCM,见问题 9)

# 5. gh
# - C:\Program Files\GitHub CLI 加入用户 PATH
# - hosts.yml 写入 %APPDATA%\GitHub CLI\hosts.yml(见问题 11)

# 6. pi 中文修复(见第 8 节)
# - 创建 ~/.multica/bin/pi-node.cmd(直连 node + cli.js)
# - 用户环境变量 MULTICA_PI_PATH 指向它

# 7. 重启 daemon 让全部生效
multica daemon restart
# 注意:Desktop 应用要彻底退出重开(它有自己的 daemon,见 8.5)
```

---

## 5. 本地部署与开发环境(阶段 D 备用)

**概念一句话**:Multica=三程序(Go server+PostgreSQL+网页)。官方云=官方电脑上的一套,数据库不外借;自部署=本机完整一套,与官方云物理隔离(零连接)——本机怎么折腾,官方云的 WEEK-8 证据无恙。**不需要租云**:localhost 自用,面试演示本机/录屏即可。

**官方路径(已查证 multica 仓库)**:
- 开发(我们的场景):`make dev` 一键(自动建配置/确保 PG/跑迁移/起服务);前置 Node 20+/pnpm/Go 1.26+/Docker,数据库 PostgreSQL 17
- 纯部署(不改代码):`docker-compose.selfhost.yml`,或 Windows 官方安装器 `install.ps1 --with-server`(拉官方镜像,需 Docker)
- 推荐开发布局:**数据库用 Docker 跑**(环境要干净,坏了整个丢弃重来),**Go 代码本机跑**(作品要热乎,改一行重启生效),网页本机跑后浏览器开 localhost
- 预见坑:Docker Desktop 需 WSL2;新坑按惯例记入本手册

**daemon 快查**:查询类命令不需要 daemon;agent 真实干活前 `multica daemon start` + `multica daemon status` 确认;跨 session/重启后 daemon 默认是停的。

## 6. 诊断命令速查

```bash
# daemon
multica daemon status | logs | restart        # 日志: C:\Users\<user>\.multica\daemon.log

# 工单(诊断 agent 行为)
multica issue list                            # 看所有工单
multica issue get <id> --output json          # 状态/metadata(assignee、dag_key 等)
multica issue runs <id>                       # 执行历史(每个 run 的起止/状态)
multica issue run-messages <runid> --issue <id>  # agent 实际执行了什么(关键!用 JSON 解析)
multica issue comment list <id>               # 评论(异常详情、agent 自述)
multica issue status <id> done                # 终结旧工单(防重)
multica issue cancel-task <taskid> --issue <id>  # 取消卡住的 run

# agent 工作目录(daemon 管理)
# C:\Users\<user>\multica_workspaces\<workspace_id>\<task_id>\workdir\<repo>\
#   该目录下的 codex-home/config.toml 有 shell_environment_policy(agent 环境白名单)

# 凭据
echo -e "protocol=https\nhost=github.com\n" | git credential fill   # 读 GitHub token
gh pr view <pr_url> --json isDraft,state,headRefOid                 # PR 观察(omac 同款)

# omac
omac init --check                    # 配置体检
omac dag check --no-review <mf>      # lint(跳过评审)
omac dag run <mf>                    # 执行循环(幂等,可中断续跑)
```

**诊断铁律**:任务卡住 → 先 `issue runs` 看状态 → 再 `run-messages` 看 agent 到底干了啥
→ 再看 daemon 日志 → 最后才改代码。**不要看 agent 的评论自述就信**(codex 的叙述
和它实际执行的命令经常不一致)。

---

## 7. 防复发 Checklist(每次改动后自查)

- [ ] 改了 omca 源码?→ 确认全局 omac 是 `-e` 可编辑安装,或重装
- [ ] 改了 PATH/装了新工具?→ `multica daemon restart`
- [ ] 新工具是否在 PATH?→ 新终端 `which <tool>`
- [ ] 涉及文件读写?→ `encoding="utf-8"` + `newline="\n"` 都带上
- [ ] 涉及绝对路径判断?→ `os.path.isabs`,不用 `startswith("/")`
- [ ] 涉及给 agent 的命令?→ 必须是目标 shell(PowerShell)可执行的精确命令
- [ ] 涉及 git 认证?→ 用 URL 内嵌凭据/CI token,别依赖交互式凭据管理器
- [ ] 重跑前?→ 检查同名旧工单是否还活跃,先置 done;确认 manifest 已重置(todo)
- [ ] 跑起来了?→ 别开第二个 `dag run`(manifest 有锁);别改 manifest 文件
- [ ] 怀疑 agent 行为?→ 用 `run-messages` 看实际命令,不信自述
- [ ] agent 收到乱码/问号?-> 先分 runtime(codex 正常+pi 坏=GBK 问题,见第 8 节);核对 pi-sessions 原始字节
- [ ] 环境变量/PATH 类修复?-> CLI daemon 和 Desktop 应用都要重启(8.5 双 daemon 坑)

---

## 8. 本次联调的最终状态(可复现的基线)

- 仓库:D:\agentlearn\learnezvibe(playground)
- 配置:.omac/config.yaml(engine=multica, workspace=466eb7c0..., project=6e64ba4b...)
- manifest:.omac/manifest.yaml(1 节点 node1:codex 生成 report.md + 证据门)
- 结果:WEEK-8 工单 done,PR #1 MERGED,`converged done=1 total=1`,exit 0
- 现场痕迹:WEEK-4/6/7/8 工单见证了全部修 bug 过程,可随时围观

---

## 9. Multica 平台自身的坑(问题 16:与 pi runtime 聊天,中文消息变 "???")

> 前面 15 个问题都是 omca/Multica **联调环境**的坑;这一节记录 Multica 平台(Windows 中文环境)
> **自身**的坑。排查方法与前面一致:先看现场字节,再做对照/复现实验,不猜。

### 8.1 现象

- 和 **pi runtime** 的 agent(如 Mika)聊天,发"你好",agent 的思考/回复里分析的是 `???`
  (hex `3f 3f 3f`,三个 ASCII 问号)——**中文消息在到达模型前就被损坏**。
- **codex runtime 的 agent 完全正常**(同一服务端、同一条消息,codex 收到正确的"你好")。
- 任何非 ASCII 内容(中文、emoji)都会损坏;纯英文不受影响。

### 8.2 根因(损坏链路)

```
daemon 启动 pi:powershell -NoProfile -ExecutionPolicy Bypass -File <npm>\pi.ps1 -p --mode json --session <path>
  (daemon 源码 pi_invocation_windows.go:为避免 cmd.exe %* 重分词 #3306,特意改走 pi.ps1)

prompt(含"你好")经 stdin 管道交给 powershell.exe
  ↓
pi.ps1(npm 生成的 shim):$input | & node cli.js
  ↓                    ← PowerShell 的 $input 管道用【系统代码页】解码 stdin 字节流
  ↓                    ← 中文 Windows 系统代码页 = GBK(936)
"你好"的 UTF-8 字节(E4 BD A0 E5 A5 BD)按 GBK 解码全是非法序列 → 被替换成 "?"
  ↓
node/pi 收到 "???" → 模型只能分析三个问号
```

**codex 为什么正常**:codex 后端走 stdio JSON-RPC 协议(`codex.cmd app-server --listen stdio://`),
编码在协议层显式处理,不经过 PowerShell 的文本管道。

### 8.3 定位过程(方法可复用)

| 步骤 | 操作 | 结果 |
|---|---|---|
| 1. 会话字节对照 | `~/.multica/pi-sessions/*.jsonl` 里 pi 收到的 user 消息 hex | `3f3f3f`(???)❌ |
| 2. 对照实验 | 同时期的 codex 会话(`...codex-home/sessions/rollout-*.jsonl`) | 同一消息 = "你好" ✅ |
| 3. **复现实验** | 模拟 daemon 的确切命令:`printf 'User message:\n你好\n' \| powershell -File pi.ps1 -p --mode json --session <t>` | pi 收到 `3f3f3f` ✅ 复现成功 |
| 4. **修复实验** | 同一 prompt 直连 `node cli.js`(绕过 PowerShell) | pi 收到 `e4bda0e5a5bd`(你好)✅ 损坏点=PowerShell shim |
| 5. 无效方案实测 | 在 pi.ps1 **脚本内部**设 `[Console]::InputEncoding=UTF8` | ❌ 无效——管道解码编码在脚本启动前已绑定;必须在外层进程设置 |

### 8.4 修复(已部署并验证)

```text
① 新增 ~/.multica/bin/pi-node.cmd(直连 node,stdin 原始字节透传):
     node "C:\Program Files\nodejs\node.exe" "<npm>\node_modules\@earendil-works\pi-coding-agent\dist\cli.js" %*
② 设置用户环境变量(注册表持久化):
     MULTICA_PI_PATH = C:\Users\liangyunxuan\.multica\bin\pi-node.cmd
   (daemon 的 agents_probe 会优先用 MULTICA_PI_PATH 覆盖 PATH 探测)
③ 重启 daemon(见 8.5 的双 daemon 坑)
④ 验证:daemon 日志出现 path=...pi-node.cmd;聊天后最新 pi-sessions 的 user 消息 hex = e4bda0e5a5bd
```

### 8.5 关键坑:一台机器上有【两个 daemon】

| daemon | 启动方式 | workspace 任务根目录 |
|---|---|---|
| CLI daemon | `multica daemon start`(~/.multica/bin/multica.exe) | `%USERPROFILE%\multica_workspaces\` |
| **Desktop daemon** | Desktop 应用派生(`--profile desktop-api.multica.ai`) | `%USERPROFILE%\multica_workspaces_desktop-api.multica.ai\` |

**环境变量类修复必须两个 daemon 都生效**。而环境变量只对"新启动的进程"有效:
- 修 CLI daemon:`multica daemon restart`(在设了环境变量的终端里,或重启后新终端)
- 修 Desktop daemon:**彻底退出并重启 Desktop 应用**(托盘也要退)——
  运行中的 Desktop 应用不会获得新环境变量,它再派生的 daemon 也不会

> 实测:只重启 CLI daemon 后,从 Desktop 聊天依然损坏(任务走 Desktop daemon);
> 彻底重启 Desktop 后修复生效(最新会话 hex = e4bda0e5a5bd ✅)。

### 8.6 已知 tradeoff(记录在案)

1. **#3306 的回归风险**:daemon 把 pi.cmd 改写为 pi.ps1 本是为了避免 cmd.exe `%*` 重分词
   多行参数;本修复走回 cmd `%*` 透传。当前安全的前提:
   - prompt 走 stdin(#6457 之后),不经 argv → 主要风险已消除
   - daemon 生成的 args(session 路径等)无空格/换行
   - **若未来给 pi 配置含多行值的 custom_args,%* 重分词问题会回归**
2. **pi 升级风险**:pi-node.cmd 硬编码 cli.js 路径(`@earendil-works/pi-coding-agent`)。
   npm 同包名升级 → 路径不变仍有效;若包改名 → wrapper 失效(daemon 探测失败退回 pi.cmd,
   GBK 问题回归)。**pi 升级后跑一次 `pi-node.cmd --version` 验证**。
3. 附注:聊天里"X 步"折叠区(展示思考/工具时间线)是**界面设计**不是 bug;
   pi 后端转发思考消息(pi.go),codex 后端从不转发(codex.go 无 MessageThinking)——
   这就是 codex 聊天"更干净"的原因。排查时别被它带偏(本次就先被带偏了)。

### 8.7 与既有问题的关联(同族问题第 3 次出现)

| 问题 | 层 | 同族点 |
|---|---|---|
| #2 GBK 解码崩 | Python `open()` 默认编码 | Windows 中文系统默认代码页 = GBK |
| #3 subprocess 解码/None | Python `subprocess text=True` | 同上 |
| **#16 本问题** | **PowerShell `$input` 管道** | **同上** |

**规律:Windows 中文系统上,"任何不显式指定编码的文本通道"都可能是 GBK**
(Python 文件读写、PowerShell 管道、进程 stdio)。全部显式 UTF-8 才安全。

问题 #13(改 PATH 后 agent 环境不更新)是同一"进程环境快照"模式的再现,且本次多一层:
**父亲进程(Desktop 应用)不重启,孩子(daemon)也拿不到新环境变量**。

### 8.8 改动交互分析(为什么互不冲突)

| 本次改动 | 与既有改动的关系 | 结论 |
|---|---|---|
| `pi-node.cmd` | 与同目录 `omac.cmd/omac.exe`(omac 联调时加的)不同文件不同用途 | 无冲突 |
| `MULTICA_PI_PATH` 环境变量 | probe 只覆盖 pi 的 executable;claude/codex 各有独立 env 前缀 | 无冲突 |
| `pi.ps1` 实验补丁 | 已还原为 npm 原样(diff 验证一致),实验备份已删除 | 回到初始状态 |
| Mika `thinking_level` | 实验过 off/low(均被 daemon 拒绝:模型只支持 high/max),已回滚为空(原始状态) | 无残留 |
| 对 omca 联调链路 | omac 派活给 codex,不经 pi;若未来派给 pi agent,中文 contract/issue 不再损坏 | 增益 |
| Mika 模型 doubao-seed-2.0-lite | 用户自己换的(保留);注意:换无思考模型也挡不住此 bug(思考内容来自模型 API 返回,与模型思考能力无关) | 无冲突 |

### 8.9 防复发

- [ ] agent 收到乱码/问号 → 先看 runtime:codex 正常 + pi 坏 = 本问题特征
- [ ] 验证命令:最新 `~/.multica/pi-sessions/*.jsonl` 的 user 消息 hex
      (你好 = `e4bda0e5a5bd`;损坏 = `3f3f3f`)
- [ ] 环境变量类修复 → CLI daemon 和 Desktop 应用**都要**重启(后者必须彻底退出含托盘)
- [ ] pi 升级后 → `pi-node.cmd --version` 验证 wrapper 仍有效
- [ ] 排查聊天异常 → 别先盯"思考折叠区"(那是设计);先核对"agent 收到的原始消息字节"
