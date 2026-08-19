# S02 修复计划

> 创建日期: 2026-08-19  
> 前置: S03 Smoke 发现真实集成问题  
> 目标: 修复 content 模式的 protocol 生成

## 问题诊断

### 根本问题
`src/omac/pipeline/dispatch.py` 在生成 worker protocol 时,没有根据 `delivery_mode` 调整指令文本。

### 当前行为
无论 contract 是什么 delivery_mode,都生成:
```
"Push a branch and open a PR (base=contract.pr_base; the worker creates it, OMAC does not)."
```

### 期望行为
- 如果 `delivery_mode: pr` → 生成 PR 模式指令
- 如果 `delivery_mode: content` → 生成 content 模式指令

## 修复范围

### 需要修改的文件
1. `src/omac/pipeline/dispatch.py`
   - `_render_worker_protocol()` 或类似函数
   - 根据 `contract.delivery_mode` 生成不同的 protocol 文本

2. `src/omac/cli/commands/work.py` (可能已修复)
   - 验证 `work show` 的 submit 模板生成
   - 确保 content 模式返回 `--content-file` 参数

### Protocol 文本规范

#### PR 模式 (现有)
```
Push a branch and open a PR (base=contract.pr_base; the worker creates it, OMAC does not). 
Work test-first, map every full-flow claim and Action contribution to a concrete business test 
on a successful command, and submit structured verification evidence. 
Deliver the complete contract without skeletons, placeholders, or production synthetic-data fallbacks.
```

#### Content 模式 (新增)
```
Use content delivery mode (no PR required). Create the deliverable file(s) as specified in the contract, 
execute all verification commands, and submit via:

    omac work submit <work-item-id> --content-file <deliverable-file> --verification-file <verification-file>

Work test-first, map every full-flow claim to a concrete business test on a successful command, 
and submit structured verification evidence. Deliver the complete contract without skeletons, 
placeholders, or production synthetic-data fallbacks.
```

## 实现步骤

### Step 1: 定位代码
```bash
cd /d/agentlearn/oh-my-multica
grep -r "Push a branch and open a PR" src/
```

找到生成 protocol 的函数。

### Step 2: 修改 protocol 生成逻辑
```python
def _render_worker_protocol(contract: Contract) -> str:
    base_protocol = "..."  # 共同部分
    
    if contract.delivery_mode == "content":
        delivery_instruction = """
Use content delivery mode (no PR required). Create the deliverable file(s) as specified in the contract, 
execute all verification commands, and submit via:

    omac work submit <work-item-id> --content-file <deliverable-file> --verification-file <verification-file>
"""
    else:  # pr mode (default)
        delivery_instruction = """
Push a branch and open a PR (base=contract.pr_base; the worker creates it, OMAC does not).
"""
    
    return delivery_instruction + base_protocol
```

### Step 3: 验证 work show 模板
确保 `work show` 返回的 submit 模板也是动态的:
```json
{
  "submit_command": "omac work submit <id> --content-file weekly-data.md --verification-file <verification>"
}
```

而不是:
```json
{
  "submit_command": "omac work submit <id> --pr-url <pr_url> --verification-file <verification>"
}
```

### Step 4: 测试
1. 单元测试: 验证 protocol 文本生成
2. Mock 测试: 确认 content 模式下的完整流程
3. 真实 smoke: 重新执行 S03

## 验收标准

### 代码层面
- [ ] dispatch.py 根据 delivery_mode 生成不同 protocol
- [ ] work.py 的 show 模板根据 delivery_mode 生成不同 submit 命令
- [ ] PR 模式回归测试通过(确保没有破坏现有功能)

### 测试层面
- [ ] 新增测试: test_protocol_content_mode()
- [ ] 新增测试: test_work_show_content_template()
- [ ] 现有测试: test_delivery_mode.py 全部通过
- [ ] 现有测试: test_content_submit.py 全部通过

### 集成层面
- [ ] Mock engine: content 模式全链路通过
- [ ] 真实 smoke: collect 节点提交成功
- [ ] 真实 smoke: OMAC evidence gate 通过
- [ ] 真实 smoke: write 节点能读取 collect 产物

## 修复后的 S02 验收

修复完成后,S02 应该满足:
1. ✅ content submit 参数模板生成正确
2. ✅ protocol 文本与 delivery_mode 一致
3. ✅ Mock 测试全部通过
4. ✅ 真实 S03 smoke 通过
5. ✅ PR 模式回归零变化

然后 S02 才能从 PARTIAL PASS 升级为 **FULL PASS**。

## 预估工作量

- 代码修改: 30-60 分钟
- 测试编写: 30 分钟
- S03 重新执行: 30-60 分钟
- **总计**: 2-3 小时

## 风险

### 低风险
- Protocol 文本生成是纯字符串拼接
- 改动局部且清晰
- 有完整的测试保护

### 需要注意
- 确保 PR 模式的回归保护
- 验证 work show 返回的 JSON 结构正确
- 确认 agent 能够理解新的 protocol 指令

---

准备开始修复?
