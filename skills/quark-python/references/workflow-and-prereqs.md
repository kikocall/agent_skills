# Quark Python Workflow And Prerequisites

这个参考文档用于补充 `quark-python` skill 在“环境检查、配置扫描、结构化脚本组织、执行前确认”上的行为规范。

## 1. 环境检查顺序

### Windows

优先检查：

- `py -V`
- `python -V`
- `pip show quark-python`
- `pip show pandas`
- `pip show krbcontext`

Kerberos 场景额外关注：

- `winkerberos`
- 用户是否已经拿到票据，或是否具备 keytab

### Linux / macOS

优先检查：

- `python3 -V`
- `python -V`
- `pip show quark-python`
- `pip show pandas`
- `pip show krbcontext`

Kerberos 场景额外关注：

- 系统 Kerberos 相关库
- `kinit` 是否可用
- keytab 路径是否存在

## 2. 配置扫描策略

先在工作目录扫描以下模式：

- `*.yaml`, `*.yml`, `*.json`, `*.toml`, `*.ini`, `*.env`
- `config/**`
- `conf/**`
- `settings/**`

再按名称过滤：

- 包含 `quark`
- 包含 `cluster`
- 包含 `db`
- 包含 `database`
- 包含 `upke`
- 包含 `tdh`
- 包含 `conn`

如果发现候选文件，先读少量内容确认是否包含这些字段：

- `host`
- `port`
- `database`
- `user`
- `auth_mechanism`
- `kerberos_service_name`
- `principal`
- `keytab`

然后向用户确认是否采用该配置。

## 3. 任务复杂度判断

### 单文件即可

适合：

- 测试连通性
- 一次性查询
- 简单 demo

### 推荐拆分结构

适合：

- 多个 SQL 文件
- 大批量查询
- 定时报表
- 数据导出
- 需要多人协作维护

默认拆分为：

- `config/`
- `sql/`
- `scripts/`
- `output/`

## 4. 执行前确认模板

执行前至少向用户说明：

- 即将执行的脚本
- 读取的配置来源
- 目标集群
- 主要 SQL
- 输出位置
- 是否包含写入动作

示例：

```text
我已经准备好执行 `scripts/run_sql_file.py`。
它会读取 `config/quark.yaml`，连接 `172.18.x.x:10000` 的 Quark 集群，
执行 `sql/customer_profile.sql`，并把结果写到 `output/customer_profile.csv`。
本次执行会读取数据，不会写表。如果你确认，我再执行。
```

## 5. 生成代码时的默认风格

- 敏感信息用占位符
- 路径集中放在配置区
- SQL 不内嵌在大段 Python 逻辑里，除非任务非常简单
- 对结果输出格式要写清楚
