> **非计量 smoke**: 本 issue 用于 B3 S03 前置验证,不计入正式样本,不占用 Native-01/OMAC-01/Native-02/OMAC-02 槽位。

请完成一条三阶段周报流程 (content 交付模式验证):

1. **collect**: 收集并整理本周数据,产出 weekly-data.md
2. **write**: 基于 weekly-data.md 生成 weekly-report.md  
3. **review**: 检查 weekly-report.md 的准确性和结构

**依赖关系**: collect -> write -> review

**验收标准**:
- weekly-data.md 存在且内容有效
- weekly-report.md 存在且包含"本周进展"和"下周计划"
- write 使用 collect 的产物
- review 检查 write 的产物

---

## OMAC 控制信息

本 issue 由 OMAC 引擎编排

**manifest 路径**: `.omac/weekly.yaml`

**fixture 文件** (本周数据源):
- 交接信-新session.md
- 项目总纲-Multica工作流引擎.md
- Evidence/B1卡点清单.md
- Evidence/B2验收记录.md

(这四个文件已作为附件提供)
