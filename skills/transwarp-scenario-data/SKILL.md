---
name: transwarp-scenario-data
description: Design, plan, generate, and validate synthetic or mock data workflows for reproducing production-like Transwarp or StarRing customer scenarios on big-data test clusters, especially for banking, securities, finance, and government domains. Use when Codex needs to design or execute batch-scale scenario data generation, infer table models from partial inputs, plan HDFS-based loading, prepare external-table or ArgoDB/HoloDesk import workflows, or produce DDL/SQL/Python/Spark artifacts for offline or batch replay scenes.
---

# Transwarp Scenario Data

用这个 skill 处理星环或 StarRing 测试集群上的场景复现造数，重点面向银行、证券、泛金融、政务等客户场景。默认主模式是“大规模批量文件模式”，目标不是单机逐条写表，而是设计和产出可在单台应用节点上滚动执行的批处理造数流水线。

## 默认工作方式

按下面顺序推进，不要跳步：

1. 先按 [references/input-levels.md](references/input-levels.md) 判断输入等级。
2. 再按 [references/scale-modes.md](references/scale-modes.md) 判断规模模式。
3. 再按 [references/questionnaire.md](references/questionnaire.md) 做分组提问。
4. 如果已经拿到现场 SQL、DDL 或调度逻辑，优先读 [references/task-first-modeling.md](references/task-first-modeling.md)，先反推任务依赖表、字段、join 键和分区字段。
5. 再按 [references/runtime-guardrails.md](references/runtime-guardrails.md) 做运行时探查，明确磁盘、批次、small 模式上限和失败中止条件。
6. 再按 [references/capacity-planning.md](references/capacity-planning.md) 评估本地容量、单批大小、上传窗口和清理策略。
7. 再按 [references/file-format-rules.md](references/file-format-rules.md) 设计本地文件格式、编码、分隔符和分片规则。
8. 再按 [references/batch-pipeline.md](references/batch-pipeline.md) 设计批次、文件格式、checkpoint 和失败重试。
9. 再按 [references/hdfs-isolation.md](references/hdfs-isolation.md) 设计 HDFS 路径隔离、run_id 命名和冲突处理。
10. 再按 [references/external-table-decision.md](references/external-table-decision.md) 决定外表格式、目标表格式和装载路线。
11. 再按 [references/hdfs-load-patterns.md](references/hdfs-load-patterns.md) 组织 HDFS 路径、外表映射和内表装载。
12. 再按 [references/validation-first.md](references/validation-first.md) 先做 small 验证，再决定是否进入 full。
13. 如需领域补全，读 [references/domain-blueprints.md](references/domain-blueprints.md)。
14. 如需质量门禁，读 [references/quality-gates.md](references/quality-gates.md)。
15. 只有在用户提供样本且明确需要统计分布增强时，才读 [references/sdv-playbook.md](references/sdv-playbook.md)。

## 模式选择

优先使用下面四种模式，不要混淆：

- `小批验证模式`
  - 只用于验证字段映射、导入链路、SQL 可跑通、结果可读回。
  - 允许本地快速生成少量数据。
  - 必须设置上限，避免 small 模式仍然过大。
  - 不要把它当成默认量产方案。

- `批量文件模式`
  - 这是默认主模式。
  - 先按批次生成文件到本地，再上传到 HDFS，再通过外表或装载导入目标引擎。
  - 每批成功上传并校验后，删除本地文件，为下一批腾空间。

- `分布式生成模式`
  - 目标规模超过单节点生成和上传能力时使用。
  - 推荐 Spark、Flink、Treagen、TPC-DS 风格的并行生成。
  - 数据优先直接写 HDFS，再做外表映射或内表装载。

- `混合增强模式`
  - 结构、主外键、时间逻辑、分区逻辑靠规则生成。
  - 局部分布、长尾、热点、空值率等可用样本或统计信息增强。
  - SDV 不是默认主路径，只是增强工具。

## 硬规则

下面这些是默认硬规则，不是建议项：

- 对大数据集群场景，禁止默认输出“Python 逐条 insert”作为主方案。
- 没有先解析现场 SQL、DDL 或任务依赖前，不要先生成通用表模型或拍脑袋补全大量实体。
- 先做任务依赖分析，再做表模型和字段设计；先做运行时探查和批次设计，再做造数设计。
- 本地磁盘无法容纳全量数据时，必须采用“生成一批、上传一批、删一批”的滚动清理方式。
- 默认先做 small 验证，验证通过后才进入 full；small 模式必须有人为上限，不能直接按比例放大到仍然超重。
- 默认检查 HDFS 目标路径是否存在、是否为空、是否需要切换 run_id，避免不同任务相互污染。
- 默认从本地文件格式反推外表格式：
  - 现场已有外表建表语句时，优先复用现场语句
  - 现场明确给出 csvfile 等格式时，按现场格式处理
  - 本地默认写 txt 时，外表默认按 TEXTFILE 处理
- 目标表格式优先级必须是：
  - 现场目标 DDL
  - 任务 SQL 依赖
  - 谨慎推断的 holodesk/orc/rcfile 等格式
- 语法优先级必须是：
  - 星环官方文档
  - 用户现场已有 DDL/SQL
  - Hive 兼容推断
- 目标是 ArgoDB 或 HoloDesk 时，优先设计“外表映射 HDFS -> 装载内表”的路径。
- 只有用户明确接受时，才可以输出仅适用于联调的小样本本地直写方案。

## 固定输出结构

处理这类请求时，优先按下面结构组织输出：

1. `已知信息`
2. `缺失信息`
3. `输入等级与规模判定`
4. `任务依赖与最小必要表集`
5. `推荐造数与导入路线`
6. `批次与容量策略`
7. `可执行产物`
8. `校验与风险`

如果信息不足以直接生成最终产物：

- 先明确哪些是事实，哪些是假设。
- 只给“假设版方案”，不要伪装成已确认方案。
- 明确列出从假设版升级到正式执行版还缺哪些信息。

## 任务优先建模

先按任务 SQL 反推最小必要表集，而不是直接按行业主题域铺全量模型。优先保住：

- select 字段是否都能落到来源表或目标表
- join 字段是否都存在且类型兼容
- filter 字段和 partition 字段是否完整
- 目标表字段与任务 SQL 输出是否对齐

优先使用 [assets/sql_dependency_checklist.md](assets/sql_dependency_checklist.md) 检查：

- 任务依赖表
- 关键字段
- join 键
- filter 条件
- 分区字段
- 聚合字段
- 目标表列顺序

## 领域建模

正式生成前，优先构造最小可复现场景，而不是一上来追求大而全。参考 [references/domain-blueprints.md](references/domain-blueprints.md) 补全典型实体。

先保住：

- 主外键关系
- 时间先后顺序
- 金额与状态边界
- 分区和热点分布
- 批处理窗口
- 汇总层与事实层的可对账性

## 大规模批处理资产

优先复用下面这些模板，而不是每次从头写：

- [assets/batch_generation_controller.py](assets/batch_generation_controller.py)
- [assets/file_batch_generator.py](assets/file_batch_generator.py)
- [assets/runtime_probe_template.py](assets/runtime_probe_template.py)
- [assets/hdfs_path_guard_template.sh](assets/hdfs_path_guard_template.sh)
- [assets/hdfs_upload_template.sh](assets/hdfs_upload_template.sh)
- [assets/textfile_external_table_template.sql](assets/textfile_external_table_template.sql)
- [assets/external_table_load_template.sql](assets/external_table_load_template.sql)
- [assets/validation_pipeline_template.py](assets/validation_pipeline_template.py)
- [assets/batch_manifest.template.json](assets/batch_manifest.template.json)
- [assets/task_execution_manifest.template.json](assets/task_execution_manifest.template.json)
- [assets/sql_dependency_checklist.md](assets/sql_dependency_checklist.md)

仅当用户提供样本且明确要走 SDV 增强时，再补充使用：

- [assets/single-table-sdv-template.py](assets/single-table-sdv-template.py)
- [assets/multi-table-sdv-template.py](assets/multi-table-sdv-template.py)
- [assets/transwarp-data-config-template.yaml](assets/transwarp-data-config-template.yaml)

## 默认产物要求

除非用户明确缩小范围，否则尽量提供：

- 场景摘要与范围边界
- 任务依赖分析
- 表模型或 DDL 草案
- 批量造数方案
- HDFS 落地目录设计
- 外表与装载 SQL 模板
- 小批验证方案
- 校验 SQL 或校验脚本
- manifest/checkpoint 设计
- 可替换参数清单
- 假设与残留风险

## 什么时候联动其他 skill

- 需要真实连接集群、执行 Python 驱动、调用 Quark 类连接时，联动 `quark-python`。
- 需要创建或重构这个 skill 自身时，联动 `skill-creator`。
- 需要继续迭代这个 skill 的结构和资源时，联动 `writing-skills`。
