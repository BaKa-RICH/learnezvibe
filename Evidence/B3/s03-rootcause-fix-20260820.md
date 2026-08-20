# S03 Evidence Gate 根因定位与修复 (2026-08-20)

> 执行时间: 2026-08-20  
> 执行者: Claude (诊断 + 修复 session)  
> 前置: `session-handoff-20260819.md` (上一 session 的交接, 其根因猜测本文已纠正)  
> 状态: **已收尾 (2026-08-20)** -- 真实环境验证通过 (write/review 过门), 全新 S03 smoke PASS (collect/write/review 三节点一次过门, 见 `smoke/s03-final-pass.md`)

## 一句话状态

**S03 失败的根因是 OMAC loop 的读回 bug (不是 agent 的问题), 已修复并用 mock+全量测试验证, 下一步是对 WEEK-13 执行 `omac node retry` 做真实环境验证, 通过即 S03 完成。**

## 重要纠正: 上一交接文档的猜测是错的

`session-handoff-20260819.md` 里"可能的根因"排序 (70% agent 没跑 submit) **已被证伪**:

- ✅ Agent **确实运行了** `omac work submit --content-file ... --verification-file ...` 且**成功**
- ✅ Agent 提交的 verification 数据**完全合法** (直接喂给 evidence gate 代码是 0 错误)
- ❌ 失败发生在 OMAC 自己的读回 (hydrate) 路径上

证据链 (全部基于真实平台数据):
1. WEEK-13 metadata 里有 `verification_ref`/`deliverable_ref` (带 comment_id/attachment_id/sha256) -- 这正是 `omac work submit` 在真实 multica 引擎写 metadata 的产物 (大正文走 payload comment)
2. 附件上传者 `uploader_type: agent` (13:00:44/13:00:51) -- submit 是 agent 在自己环境里跑的
3. 时间线: 12:52 dispatch -> 13:00 agent submit 成功 -> 13:01 run 完成 -> **13:02** OMAC 评论 "Evidence gate failed: verification is required" (失败发生在 submit 之后)
4. 把 WEEK-13 的 verification 附件 hydrate 后直接喂 evidence gate: **0 错误通过**

## 根因 (bug 完整链条)

角色说明: OMAC 验收 (evidence gate) 需要读三样东西: contract (小, 在 metadata), deliverable/verification (大, 是平台附件, metadata 里只有指针 ref)。**验收前必须有人按指针把附件下载解析好 (hydrate), 否则 gate 看到的就是 None。**

| 环节 | 位置 | 发生了什么 |
|---|---|---|
| ① dispatch (12:52) | loop 写入 `worker_handoff` waiting intent | 后续读取被 handoff 路径接管 |
| ② agent submit (13:00) | agent 正确提交 | metadata 写入 verification_ref, 状态 DONE |
| ③ tick reconcile | `loop.py::_build_work_item_hydration_plan` (~L1063) | handoff intent 存在 + 检测到新交付 -> plan **只含 CONTRACT 不含 VERIFICATION** (注释假设: PR 路径的封印观察会自己读 verification 附件) |
| ④ handoff 观察 | `loop.py::_observe_worker_handoff` (~L2621) | B2 content 分支直接返回 `complete-unsealed` (免 PR 封印), **不读 verification 附件** |
| ⑤ collect 收口 | `loop.py` collect_results `complete-unsealed` 分支 (~L3325) | 清掉 handoff, 但**没有 hydrate VERIFICATION** |
| ⑥ DONE 分支 | `loop.py` ~L3501 `validate_worker_evidence` | `item.verification is None` -> "verification is required" -> blocked |

一句话: **PR 流程的搬运逻辑写死了"交接观察环节会搬证据"; content 流程新增了免封印捷径, 捷径上没人搬证据, 两条流程互相踢皮球。**

为什么 mock 测试没抓住: `complete-unsealed` 和 content 交付的 loop collect 路径**此前零测试覆盖** (S02 的 12 个测试只覆盖 submit/dispatch 层)。

## 修复内容 (oh-my-multica commit `206f3b4`)

- **`src/omac/pipeline/loop.py`** (1 处): `collect_results` 的 `complete-unsealed` 分支, 清 handoff 后补调 `_hydrate_worker_collect_evidence` (PR 封印路径 `_finalize_worker_handoff_delivery` 本来就有同样的调用, content 路径漏了), 并把 hydrate 后的 projection 写回局部变量
- **`tests/test_lightweight_reconcile.py`**: 新增回归测试 `test_content_delivery_handoff_collect_hydrates_verification_before_gate` -- 完整复刻 WEEK-13 场景 (explicit-dispatch handoff intent + content 合同 + 合法 submit + 终态 run), 断言 gate 看到 hydrate 后的 verification、节点收敛 done。测试内 `OMAC_GIT_SYNC=0` 绕开 Windows 跨盘符 gitsync 崩溃 (既有环境问题, 与本修复无关)

git: `206f3b4 fix(content): complete-unsealed 收口前补 hydrate worker verification` (父提交 a605a34)

## 已完成的验证

| 验证 | 结果 |
|---|---|
| 回归测试先跑红 | ✅ 失败方式与线上完全一致 ("Worker evidence gate: verification is required") |
| 修复后回归测试 | ✅ 绿 |
| 定向子集 (loop/events_tick/content_submit/delivery_mode/lightweight_reconcile/dispatch/engines_mock, ~40秒) | ✅ 失败 9->9, 同一批, 零新增 |
| 全量 pytest (2192 tests, ~6分钟) | ✅ **101 -> 101, 完全同一批, 零新增回归** |

## 测试基线口径澄清 (重要, 避免再混淆)

**两套口径, 不要混:**

1. **全量基线 = 101 个失败** (Windows 环境类: 编码/symlink/web 静态/跨盘符 gitsync 等), 快照在 `D:\agentlearn\oh-my-multica\tests_baseline_101_a605a34.txt` (工作区文件, 未提交)。判定方法: 修复前后失败清单 (只比测试 ID) 必须完全一致
2. **旧文档说的"9 个失败"是定向子集口径** (当时 S02 验收只跑了 8 个相关文件), 不是全量

快速循环命令:
```bash
cd D:\agentlearn\oh-my-multica
# 定向 (~40秒, 开发迭代用)
.venv/Scripts/python.exe -m pytest tests/test_loop.py tests/test_events_tick.py tests/test_content_submit.py tests/test_delivery_mode.py tests/test_lightweight_reconcile.py tests/test_dispatch.py tests/test_engines_mock.py -q
# 全量 (~6分钟, 提交前一次)
.venv/Scripts/python.exe -m pytest tests/ -q
```

注意: PATH 上的 `omac` 是 uv editable 安装 (`uv tool list` 可查), 指向 `D:\agentlearn\oh-my-multica` repo 源码, CLI 与测试同一份代码, 无版本错位。

## 待做: 真实环境验证 (下个 session 第一个动作)

WEEK-13 上 agent 的合法提交数据还原封不动在平台上 (verification/deliverable 附件 + metadata refs), 是现成的真实验证素材。

**首选操作 (省, 只重跑 write 一个 agent):**
```bash
cd D:\agentlearn\learnezvibe
omac node retry .omac/weekly.yaml write
omac dag run .omac/weekly.yaml --max-rounds 20 --max-minutes 30
```

**通过判定:**
- write 节点收敛 `done` (不再 blocked)
- issue 评论里**没有**新的 "Evidence gate failed"
- (write 无 reviewer, 过门即 done; review 节点应被解封派发)

**通过后**: 清理旧 smoke issues (WEEK-10/11/12/13 标 done), 跑一次**全新完整 S03 smoke** (collect->write->review 全链路, 修改 manifest 名或 abandon 全部节点后 `omac dag run`), 全链路通过即 S03 正式完成, 进入 S04 正式采样 (Native×2 + OMAC×2)。

**若仍失败 (排查入口):**
1. `multica issue comment list WEEK-13` 看失败评论的精确时间与新报错内容
2. 对真实 work item 复现诊断: observe_work_item_control -> `_build_work_item_hydration_plan` -> hydrate -> `validate_worker_evidence` 逐环跑 (本 session 用此方法 100% 复现了原 bug; 注意模拟失败时刻需要 node.status='in_progress' + item.status=DONE)
3. 重点怀疑同类 hydration 缺失 (如 review 节点路径)

## 关键事实速查

- WEEK-13 (write 节点 work item): `ba05306d-70ca-429f-b11b-687ebbd5b996`, 状态 blocked
- collect 节点: abandoned (work item c382fcfb, WEEK-12, 已被放弃不影响下游)
- dag manifest: `D:\agentlearn\learnezvibe\.omac\weekly.yaml` (3 节点: collect->write->review)
- multica daemon: `multica daemon status` 检查; agent: weekly-collect / weekly-write / weekly-review
- OMAC 失败后节点 blocked, 重试必须显式 `omac node retry` (tick 不会自动复活 blocked 节点)
- OMAC 状态持久化在 manifest + 平台, 失败重跑前先 abandon/retry 相关节点
