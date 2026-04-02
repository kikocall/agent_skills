---
name: quark-python
description: Generate, review, structure, and safely execute Python code that connects to StarRing/TDH Quark (ArgoDB/Inceptor/Quark) using the internal `quark_python` driver. Use when Codex needs to build or troubleshoot Quark connection code, verify Python/runtime prerequisites across operating systems, discover existing cluster config files in the current workspace, separate Python runner scripts from SQL files for large or complex tasks, or pause for explicit user confirmation before executing generated scripts.
---

# Quark Python

围绕 Quark 的 Python 任务，先做前置条件检查和配置发现，再生成代码；任务复杂时采用规范化目录结构，把 Python 执行脚本和 SQL 文件分离；在真正执行前，先向用户展示脚本内容和本次执行概要，再等待确认。

## Quick Start

1. 先确认当前任务是：
   - 连接验证
   - 单次查询
   - 导入/导出
   - 批量查询
   - 多进程或复杂任务
2. 先做环境检查：
   - 当前是否存在 Python 解释器
   - 必要依赖是否已安装
   - 操作系统相关前置包是否满足
   - `quark_python` wheel 是否可从 skill 自带资源安装
3. 扫描工作目录中的配置文件，优先复用已有集群配置。
4. 信息不足时先提问，不直接瞎写。
5. 生成脚本后，执行前必须先征得用户确认。

## Environment First

在生成或执行任何 Quark Python 脚本前，先检查运行环境。

### 必查项

- 是否存在可用 Python：
  - Windows 优先检查 `py` 或 `python`
  - Linux/macOS 优先检查 `python3` 或 `python`
- 当前 Python 版本是否可用
- 是否已安装 `quark_python` 或对应 wheel
- 是否已安装常用依赖：
  - `pandas`
  - `thrift`
  - `thrift_sasl`
  - `six`
  - `bitarray`
  - `pykerberos`（Kerberos 场景）

### 认证相关依赖

- Kerberos 场景：
  - Linux/macOS：检查系统 Kerberos 相关包是否可用
  - Windows：优先注意 `winkerberos`
  - 如需 keytab 自动认证，检查 `krbcontext`
- LDAP 场景：
  - 通常重点是用户名/密码和网络可达性，不额外假设系统包

### 行为规则

- 如果环境未满足，先告诉用户缺什么，再继续生成代码或安装命令。
- 不要假设所有系统都一样；按当前操作系统给建议。
- 如果用户只是要示例代码，可以先输出代码，但要明确标记尚未验证的前置条件。
- 优先说明 skill 自带的 wheel 路径，并给出基于该路径的安装命令。
- 如果检测到当前 Python 环境尚未安装 `quark_python`，优先使用 `references/wheel-check-template.md` 中的标准提示模板与用户沟通。

如果需要更具体的驱动参数和安装事实，读取：

- `references/driver-notes.md`
- `references/installing-driver.md`
- `references/tutorial-notes.md`
- `references/workflow-and-prereqs.md`

## Config Discovery First

在向用户追问 `host`、`port`、认证方式之前，先扫描当前工作目录和常见子目录中是否已存在可复用的配置文件。

优先扫描这些名字或模式：

- `*.yaml`
- `*.yml`
- `*.json`
- `*.toml`
- `*.ini`
- `*.env`
- `config/*.yaml`
- `config/*.yml`
- `conf/*.yaml`
- `conf/*.yml`
- `settings/*.yaml`
- `settings/*.yml`
- 文件名包含：
  - `quark`
  - `cluster`
  - `db`
  - `database`
  - `upke`
  - `tdh`
  - `connection`

### 扫描后行为

- 如果发现 1 个明显相关配置文件：
  - 告诉用户发现了该文件
  - 简要说明可能包含的连接信息
  - 询问是否使用它
- 如果发现多个候选文件：
  - 列出候选项
  - 让用户确认使用哪一个
- 如果没发现：
  - 再向用户提问 `host`、`port`、认证方式等信息

不要在未经确认的情况下擅自采用某个配置文件作为最终连接来源。

## Missing Information First

如果用户没有给足可执行所需的信息，先提问。

优先只问当前任务真正缺失的信息，不要一口气问无关参数。

常见缺失项：

- Quark `host`
- `port`
- `database` 或 schema
- 认证方式
- 用户名/密码
- 是否已 `kinit`
- `keytab`
- `principal`
- `kerberos_service_name`
- 输入文件、目标表、字段映射  

## Choose The Connection Pattern

- 无认证或测试环境：使用 `assets/nosasl-connect.py`
- LDAP：使用 `assets/ldap-connect.py`
- Kerberos 手动 `kinit`：使用 `assets/kerberos-manual.py`
- Kerberos + keytab + 多进程：使用 `assets/kerberos-keytab-multiprocess.py`
- 批量/复杂查询：参考 `assets/project-layout-template.txt` 和 `assets/run_sql_file_template.py`

## Core Rules

- 使用 `from quark.dbapi import connect`
- 尽量显式声明 `auth_mechanism`
- 查询结果若需要表格处理，再转换为 `pandas.DataFrame`
- 始终关闭 `cursor` 和 `conn`
- 教程与驱动签名不一致时，以已安装驱动事实为准并明确提示用户

## Recommended Workflow

### 1. 先检查环境

按当前操作系统检查：

- Python 是否可用
- skill 自带 wheel 或依赖是否存在
- Kerberos/LDAP 相关依赖是否满足

如果要执行脚本，这一步不能跳过。

### 1.1 驱动检测与安装提示

按这个顺序处理：

1. 检查当前 Python 命令是否可用
2. 检查是否已能导入 `quark` 或已安装 `quark_python`
3. 检查 skill 自带 wheel 是否存在：
   - `assets/quark_python-0.0.1-py2.py3-none-any.whl`
4. 如果 wheel 存在但驱动未安装：
   - 用标准模板告诉用户“检测结果 + 安装命令 + 是否继续”
5. 如果 wheel 不存在：
   - 明确告诉用户 skill 内未发现驱动包，需要用户提供 wheel 或改用其他来源

不要在未确认前自动执行安装命令。

### 2. 先扫描配置

优先在当前工作目录扫描已有配置文件，而不是立刻问用户一长串参数。

### 3. 再补问缺失参数

只有在配置文件不足或用户不采用现有配置时，才继续提问。

### 4. 选任务结构

- 简单单次查询：
  - 单脚本即可
- 批量、复杂、可复用查询：
  - Python 连接脚本与 SQL 文件分离
  - 配置与代码分离
  - 输出目录清晰

### 5. 生成代码

代码要符合任务规模，不要把所有内容都堆进一个文件。

### 6. 执行前确认

如果下一步要真正执行脚本，先向用户确认，不要直接跑。

## Structured Project Layout

对于大批量或复杂查询任务，默认使用结构化布局。优先参考：

- `assets/project-layout-template.txt`
- `assets/run_sql_file_template.py`
- `assets/cluster-config.template.yaml`

推荐结构：

```text
project/
  config/
    quark.yaml
  sql/
    query_01.sql
    query_02.sql
  scripts/
    run_sql_file.py
    export_results.py
  output/
```

### 使用规则

- Python 负责：
  - 读取配置
  - 建立连接
  - 读取 SQL 文件
  - 执行 SQL
  - 写出结果
- SQL 文件只放 SQL，不要混入 Python 逻辑
- 配置文件单独维护连接参数和运行参数

如果用户明确只是一次性 demo，可以不强制拆分；但对于批量查询、复杂查询、长期维护脚本，默认采用分离结构。

## Question Flow Templates

### A. 连接类任务

如果工作目录没有可复用配置，问：

- `host` 是多少？
- `port` 是多少？
- 认证方式是什么：`NOSASL`、`LDAP` 还是 `GSSAPI/Kerberos`？

然后只继续问该认证方式需要的字段。

LDAP 继续问：

- 用户名是什么？
- 密码是什么？

Kerberos 继续问：

- 是否已经手动执行过 `kinit`？
- `kerberos_service_name` 是什么？如果不确定，是否按 `hive`？
- 如果需要自动认证：`keytab` 路径是什么？
- `principal` 是什么？

### B. CSV 导入类任务

如果用户说“把 CSV 导入 UPKE/Quark”，在扫描配置之后，再补问：

- CSV 文件路径是什么？
- 目标库和目标表是什么？
- 目标表是否已经存在？
- CSV 分隔符和编码是什么？
- 是否有表头？
- 字段映射是否一一对应？

### C. 调试类任务

如果用户给出错误但缺少上下文，只问：

- 当前认证方式是什么？
- 是否已经 `kinit`？
- 用的是哪段连接代码？
- 完整报错是什么？
- 当前系统是 Windows、Linux 还是 macOS？

## Execution Confirmation

当代码已经生成，且下一步是“执行脚本”“连接数据库”“跑 SQL”“导入数据”时，必须先给用户一个简短确认说明，再等待回复。

确认说明至少包含：

- 本次将执行哪个脚本或命令
- 会读取哪个配置文件
- 会连接哪个目标集群
- 会执行哪些 SQL 文件或主要 SQL
- 预期输出到哪里
- 是否会写入表、落地文件或覆盖结果

确认示例风格：

- “我已经生成好脚本，准备执行 `scripts/run_sql_file.py`。它会读取 `config/quark.yaml`，连接 `UPKE` 集群，执行 `sql/customer_profile.sql`，并把结果写到 `output/customer_profile.csv`。如果你确认，我再执行。”

未获得用户确认前，不要实际执行。

## Standard Prompt Templates

在“检测到未安装驱动但 skill 自带 wheel 存在”时，优先采用 `references/wheel-check-template.md` 里的标准表达。

## Output Style

- 默认输出可运行代码或结构化项目骨架
- 用占位符表示敏感信息
- 如果环境未验证通过，要明确指出“代码已生成，但执行前仍需补齐前置条件”
- 如果需要安装驱动，优先给出从 skill 自带 wheel 安装的命令
- 如果准备执行，先给执行摘要，再等待用户确认

## Conversational Behavior

- 主动做环境和配置发现
- 优先复用现有工作目录里的配置文件
- 缺少关键信息时分组提问，不要散乱追问
- 对复杂任务主动建议“脚本与 SQL 分离”
- 在真正执行前必须停下来确认

## Resources

- `references/tutorial-notes.md`：来自内部 DOCX 教程的摘要
- `references/driver-notes.md`：`quark_python` wheel 提取出的驱动事实
- `references/installing-driver.md`：从 skill 自带 wheel 安装驱动的说明
- `references/wheel-check-template.md`：检测到未安装驱动时的标准提示模板
- `references/workflow-and-prereqs.md`：环境检查、配置扫描和执行确认流程
- `assets/nosasl-connect.py`：无认证示例
- `assets/ldap-connect.py`：LDAP 示例
- `assets/kerberos-manual.py`：手动 `kinit` 示例
- `assets/kerberos-keytab-multiprocess.py`：keytab + 多进程示例
- `assets/quark_python-0.0.1-py2.py3-none-any.whl`：随 skill 一起迁移的驱动安装包
- `assets/project-layout-template.txt`：复杂任务的推荐目录结构
- `assets/run_sql_file_template.py`：读取配置和 SQL 文件执行查询的模板
- `assets/cluster-config.template.yaml`：集群配置模板
