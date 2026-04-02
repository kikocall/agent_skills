# agent_skills

这个仓库用于备份当前 Codex 全局 `skills` 目录中的内容，并为每个 skill 提供一份简明索引，方便快速判断“它是做什么的”和“什么时候该用它”。

来源目录：

- `C:\Users\Administrator\.codex\skills`

仓库范围：

- 包含 `skills/` 下的普通 skills
- 包含 `skills/.system/` 下的系统 skills
- 不包含 `C:\Users\Administrator\.codex\superpowers\skills`

当前 skills 总数：`14`

## 目录说明

- `skills/.system/`：Codex 自带的系统级 skills
- `skills/docx` 到 `skills/xlsx`：文档处理、开发辅助、数据与集群相关 skills

## Skills 一览

### 系统 Skills

| Skill | 功能 | 使用范围 |
| --- | --- | --- |
| `imagegen` | 生成或编辑位图图像资源。 | 适用于照片、插画、贴图、精灵图、mockup、透明背景图等图像生成与编辑；不适合 SVG、HTML/CSS、Canvas 这类代码原生图形。 |
| `openai-docs` | 查询和使用 OpenAI 官方文档。 | 适用于 OpenAI 产品/API 用法、模型选择、升级到 GPT-5.4、提示词升级、需要官方来源和引用的场景。 |
| `plugin-creator` | 创建 Codex 插件脚手架。 | 适用于新建本地插件、生成 `.codex-plugin/plugin.json`、补齐插件目录结构，以及维护 `.agents/plugins/marketplace.json`。 |
| `skill-creator` | 创建或改造 skill 本身。 | 适用于设计新 skill、更新已有 skill、补全 skill 的说明、资源与结构约定。 |
| `skill-installer` | 安装外部或精选 skills。 | 适用于列出可安装 skills、从精选列表安装、或从 GitHub 仓库路径安装 skill。 |

### 文档与办公文件 Skills

| Skill | 功能 | 使用范围 |
| --- | --- | --- |
| `docx` | 处理 Word 文档。 | 适用于创建、读取、编辑、重排 `.docx`，以及报告、备忘录、信函、模板、批注、修订、图片替换等 Word 相关任务。 |
| `pdf` | 处理 PDF 的生成、提取和版面检查。 | 适用于需要关注页面渲染和版式的 PDF 阅读、生成、审阅与提取场景。 |
| `pptx` | 处理 PowerPoint 演示文稿。 | 适用于任何涉及 `.pptx` 的任务，包括制作幻灯片、读取内容、修改版式、拆分/合并、模板、备注和批注。 |
| `xlsx` | 处理电子表格文件。 | 适用于 `.xlsx`、`.xlsm`、`.csv`、`.tsv` 的读取、清洗、修复、生成、格式化、公式计算和结构整理。 |

### 开发与平台辅助 Skills

| Skill | 功能 | 使用范围 |
| --- | --- | --- |
| `find-skills` | 帮用户寻找合适的 skills。 | 适用于“有没有某种 skill”“怎么做某类能力扩展”“帮我找一个能做 X 的 skill”这类需求。 |
| `mcp-builder` | 构建高质量 MCP 服务。 | 适用于开发 MCP Server、设计工具接口、接入外部 API/服务，以及 Python FastMCP 或 Node/TypeScript MCP SDK 场景。 |

### 数据与集群 Skills

| Skill | 功能 | 使用范围 |
| --- | --- | --- |
| `quark-python` | 编写和安全执行连接 Quark 的 Python 代码。 | 适用于 StarRing/TDH Quark、ArgoDB、Inceptor、Quark 连接脚本编写、运行前环境检查、配置发现和 SQL/Python 分离执行。 |
| `tdh-cluster` | 操作和管理 TDH/Transwarp 集群。 | 适用于多集群切换、HDFS/TDFS 文件操作、YARN 任务管理、Inceptor SQL、Kafka、ZooKeeper、Kerberos 认证以及 TDH 运维场景。 |
| `transwarp-scenario-data` | 设计和生成 Transwarp 场景数据。 | 适用于构造模拟生产场景的数据流程，尤其是银行、证券、金融、政务等领域的批量数据生成、导入、校验和回放。 |

## 使用建议

- 如果任务核心是“某种文件格式”，优先按文件类型选 skill，例如 `docx`、`pdf`、`pptx`、`xlsx`。
- 如果任务核心是“开发平台或扩展能力”，优先看 `find-skills`、`mcp-builder`、`plugin-creator`、`skill-creator`、`skill-installer`。
- 如果任务核心是“大数据平台、集群或场景数据”，优先看 `quark-python`、`tdh-cluster`、`transwarp-scenario-data`。

## 维护说明

- 本 README 只做索引和适用范围说明，不替代各目录中的 `SKILL.md`。
- 具体触发条件、工作流、脚本和资源文件请直接查看对应 skill 目录。
