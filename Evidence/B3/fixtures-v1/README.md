# fixtures-v1: B3 冻结 fixture 权威副本

> 归属: `b3-weekly-fixture-v1`（`Evidence/B3/frozen-input.json`）
> 恢复: 2026-08-20，从 WEEK-10 (`db173d75-...`) 的 issue 附件下载
> 校验: 4 个文件 SHA-256 全部与 frozen-input.json 一致（2026-08-20 复核）

## 用途

S04 每个正式样本的**根 issue 附件注入源**（Native 与 OMAC 共用同一份字节）。
protocol 要求：4 个样本在首个计量 run 前获得完全相同的 fixture attachment/ref，collect 必须读取这四个文件且 SHA-256 匹配。

## 文件

| 冻结路径 | bytes | sha256 前缀 |
|---|---|---|
| 交接信-新session.md | 5297 | a3553b02... |
| 项目总纲-Multica工作流引擎.md | 18915 | 17c5cb0d... |
| Evidence/B1卡点清单.md | 8165 | 40cb15e9... |
| Evidence/B2验收记录.md | 4205 | 9d744387... |

## 铁律

- **冻结，禁止编辑。** 此目录是实验输入快照，与同名"活文档"无关（如活版 `项目总纲-Multica工作流引擎.md` 会随进度更新，但实验用这份冻结字节）。
- 注入方式：platform `multica issue create` 时以附件形式上传这 4 个文件，记录 attachment ID。
- 校验命令：
  ```bash
  cd D:\agentlearn\learnezvibe && python -c "
  import hashlib, json, os
  d = json.load(open('Evidence/B3/frozen-input.json', encoding='utf-8'))
  for f in d['weekly_fixture']['files']:
      p = os.path.join('Evidence/B3/fixtures-v1', f['path'])
      h = hashlib.sha256(open(p,'rb').read()).hexdigest()
      print(f['path'], 'OK' if h==f['sha256'] else 'BAD')"
  ```
