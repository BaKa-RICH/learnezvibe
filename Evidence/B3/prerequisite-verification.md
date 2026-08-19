# B3 S02 前置实现验收记录

日期：2026-08-19  
代码 revision（执行前）：`4f1773d`  
状态：实现完成；Desktop smoke 和正式样本尚未运行。

## 实现范围

- `develop x authoring` 按 `Contract.delivery_mode` 路由：`pr` 保持
  `--pr-url + --verification-file`；`content` 使用
  `--content-file + --verification-file`。
- `work show`、review rollout 文本和 `work submit` 共用同一 content 参数模板。
- content 提交先读取并校验正文与 verification，再通过 `WorkItemStore` 写入
  `deliverable`、`verification` 和 `artifact_paths`；Multica adapter 的既有
  payload attachment/ref 路径承载正文，保存 SHA-256 与字节数。
- `omac work read` 在独立目录按 source ref 读取；当 ref 声明
  `content_sha256`/`content_bytes` 时重新校验摘要和字节数，并以 UTF-8 原始字节
  写出，拒绝篡改或换行转换。当前 weekly pipeline 的依赖 ref 仍是 issue identity，
  因此真实跨节点 SHA 采集仍需 S03 smoke 验证，不能由本地 mock 测试替代。
- `delivery_mode` 解析同时支持 `Contract` 对象和平台读回的 mapping。
- `weekly.yaml` 已固定逐节点 worker：`collect=weekly-collect`、
  `write=weekly-write`、`review=weekly-review`；review 节点未配置额外 reviewer，
  保持 B3 三个业务节点各一个主调用。
- 已按冻结合同更新 `learnezvibe/.omac/weekly.yaml` 的三个 worker 映射并移除
  额外 reviewer；未修改 `WEEK-9`、squad、agent、daemon，未执行 Desktop
  smoke 或 Native/OMAC 正式样本。

## 测试证据

使用仓库 `.venv`（当前 Windows shell 中 `python3` launcher 不存在；直接调用
`python3 -m pytest tests/` 返回 command-not-found/9009）：

| 命令 | 结果 |
|---|---|
| `.venv\\Scripts\\python.exe -m pytest tests/test_content_submit.py tests/test_delivery_mode.py -q` | **12 passed** |
| `.venv\\Scripts\\python.exe -m pytest tests/test_content_submit.py tests/test_delivery_mode.py tests/test_cli_work.py::test_work_read_materializes_named_upstream_deliverable -q` | **13 passed** |
| `.venv\\Scripts\\python.exe -m pytest tests/test_loop.py -q --tb=short` | **2 failed, 512 passed**；失败为 Windows 临时绝对路径被 CLI 参数规范化为无盘符路径，属于 HEAD 既有问题 |
| `.venv\\Scripts\\python.exe -m pytest tests/ -q --tb=short > Evidence/B3/pytest-full.txt 2>&1` | **未完成**；运行至 13% 后因执行时间超出本任务边界而人工中止，无终态 summary/退出码可报告。部分日志保存于 `pytest-full.txt`，不是绿证据 |
| `git diff --check` | **通过** |

新增 content 测试覆盖：参数模板选择、缺失参数教学错误、正文与 verification
持久化、Multica adapter payload/ref 摘要、独立 workdir 实际 `work read` 写出相同
字节、digest drift 拒绝和 PR 路径回归。adapter 测试通过 monkeypatch 隔离平台
命令，因此不需要凭据；真实平台附件下载、Desktop runtime 和 agent 因果身份仍
必须由后续 smoke 验证。

## 基线归因

当前代码 HEAD 已包含 `_command_env_prefix()` 返回空串的跨平台修复，但旧测试仍
断言 `OMAC_ENGINE=... omac ...` 前缀；`git show HEAD:tests/test_dispatch.py` 和
`git show HEAD:tests/test_tasks.py` 可直接看到这些断言，故相关失败不是本次
content 改动引入。`work read` 原实现用 Windows 文本模式写出 CRLF，而摘要按 UTF-8
LF 计算；本次改为二进制 UTF-8 写出，相关回归测试已通过。

## 配置验证

通过 `.venv\\Scripts\\python.exe -c "import yaml; p=yaml.safe_load(open(r'D:\\agentlearn\\learnezvibe\\.omac\\weekly.yaml', encoding='utf-8')); print([(n['id'], n['worker'], n.get('reviewer')) for n in p['nodes']])"` 验证得到：

```text
[('collect', 'weekly-collect', None), ('write', 'weekly-write', None), ('review', 'weekly-review', None)]
```

三个节点均保留 `delivery_mode: content`；`WEEK-9` 未修改。

## Gate 判断

S02 content submit/deliverable/read 代码与回归测试已完成。由于全量 pytest 仍受
既有 Windows 环境失败影响且本轮未完成终态全量 summary，Desktop smoke 也尚未
执行，因此 **S02 gate FAIL / B3 保持 NO-GO**。应先获得完整全量测试结论并完成
S03 smoke，不能把本轮定向测试替代为正式开跑证据。
