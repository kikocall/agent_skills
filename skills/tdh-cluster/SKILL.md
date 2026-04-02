---
name: tdh-cluster
description: 操作和管理星环 TDH (Transwarp Data Hub) 集群。支持动态扫描集群配置、认证方式识别、keytab 选择、HDFS/YARN/Inceptor/Quark/Kafka/ZooKeeper 连接验证，以及测试结果本地落盘。当用户提到 TDH、星环、TDFS、Inceptor、Quark、Transwarp 集群运维时使用此技能。
---

# TDH 集群管理技能

这个 skill 面向 Linux Bash 环境，使用 TDH-Client 完成集群发现、认证判定、keytab 选择、Quark 连接验证和结果落盘。

## 适用范围

当任务涉及以下内容时使用这个 skill：

- 扫描 TDH-Client 下的集群配置和 Kerberos 目录
- 切换 `conf` / `kerberos` 软链到目标集群
- 判断 HDFS、YARN、HBase、Quark 的认证方式
- 为 Kerberos 集群选择正确的 keytab 和 principal
- 验证 HDFS、YARN、Hive/Quark、Kafka、ZooKeeper 连通性
- 将测试案例、命令输出、认证证据和总结写入本地目录

## 运行前提

### 操作系统与 Shell

- 运行环境必须是 Linux
- Shell 必须是 Bash
- 所有命令按 Linux 路径和 Linux 工具编写

### 必需输入

执行脚本前，至少要确认以下输入：

- `TDH_CLIENT_HOME`
  - 指向 TDH-Client 根目录，例如 `export TDH_CLIENT_HOME="$HOME/TDH-Client"`
- `cluster`
  - 指目标集群的 `cluster_id`
  - `cluster_id` 默认取 TDH-Client 根目录下对应配置目录的目录名

### 可选输入

- `TDH_EXPLICIT_KEYTAB`
  - 显式指定本次任务使用的 keytab
- `TDH_EXPLICIT_QUARK_SERVER`
  - 显式指定本次任务优先尝试的 Quark 地址，格式为 `host:port`
- `TDH_LDAP_USERNAME`
  - LDAP 认证用户名
- `TDH_LDAP_PASSWORD`
  - LDAP 认证密码

## 安全边界

除非用户明确要求，否则不要修改以下内容：

- `/etc/hosts`
- `/etc/krb5.conf`
- TDH-Client 自带的配置文件
- 非本次任务生成的文件

如果任务确实需要修改这些文件，必须先得到用户确认。

## Agent 执行约定

### 路径与命令

- 使用绝对路径或明确的环境变量路径
- 不要通过 `cd` 改变工作目录后再 `source init.sh`
- 应直接使用：

```bash
source "$TDH_CLIENT_HOME/init.sh" n n
```

### 新 shell 初始化方式

每次执行命令时，脚本会为当前任务生成临时 bootstrap 文件，并用下面两种方式之一启动新的交互 shell：

```bash
bash --rcfile "<bootstrap_file>" -i -c "<command>"
```

或：

```bash
bash -i -c "source '<bootstrap_file>'; <command>"
```

这样可以让每个新 shell 都自动拿到：

- `TDH_CLIENT_HOME`
- `KRB5_CONFIG`
- `KRB5CCNAME`
- `init.sh` 初始化后的环境
- 当前任务对应的认证状态

### Kerberos 票据缓存

每次任务使用独立的 `KRB5CCNAME`，格式类似：

```text
FILE:$HOME/tdh-cluster/runtime/<run_id>/krb5cc
```

同一任务内复用同一票据缓存，跨任务不共享。

## 标准执行链路

### 步骤 1：扫描集群并刷新索引

```bash
bash scripts/discover-clusters.sh
```

作用：

- 扫描 `TDH_CLIENT_HOME` 根目录下的配置目录候选
- 扫描 `TDH_CLIENT_HOME` 根目录下的 Kerberos 目录候选
- 识别当前激活集群
- 生成本地索引文件

索引文件位置：

```text
$HOME/.codex/tdh-cluster/cluster-index.json
```

配置目录候选规则：

- 包含 `core-site.xml`
- 或包含 `hdfs-site.xml`
- 或包含 `yarn-site.xml`
- 或包含 `hive-site.xml`
- 或包含 `hbase-site.xml`
- 或包含 `server.properties`

Kerberos 目录候选规则：

- 包含 `krb5.conf`
- 或包含 `*.keytab`
- 或包含 `jaas.conf`

输出中的每一行都会给出：

- `cluster_id`
- 是否为当前激活集群
- 当前识别到的认证方式
- 配对状态

### 步骤 2：切换到目标集群

```bash
bash scripts/switch-cluster.sh <cluster>
```

输入：

- `<cluster>`：目标 `cluster_id`

作用：

- 校验配置目录与 Kerberos 目录能否安全配对
- 更新 `TDH_CLIENT_HOME/conf`
- 更新 `TDH_CLIENT_HOME/kerberos`
- 输出当前集群摘要

如果 `pairing_status` 不是 `paired`，脚本会直接失败，不进行切换。

### 步骤 3：检查运行环境

```bash
bash scripts/check-env.sh
bash scripts/check-env.sh <cluster>
```

作用：

- 输出 `TDH_CLIENT_HOME`
- 检查 `java` 是否可用
- 检查 `kinit` 是否可用
- 输出索引文件路径
- 输出当前激活集群
- 当传入 `<cluster>` 时，补充输出该集群的配对状态和认证方式

说明：

- `check-env.sh` 只做检查与输出，不会安装任何软件包

### 步骤 4：识别认证方式

```bash
bash scripts/check-auth.sh <cluster>
```

输入：

- `<cluster>`：目标 `cluster_id`

输出字段：

- `CLUSTER_ID`
- `CONF_DIR`
- `KERBEROS_DIR`
- `PAIRING_STATUS`
- `REALM`
- `HADOOP_AUTH`
- `HBASE_AUTH`
- `QUARK_AUTH`
- `QUARK_CANDIDATES`
- `EFFECTIVE_AUTH`

认证判定顺序分为两层。

#### 4.1 总体判定

优先检查以下配置：

```bash
grep -Rin "kerberos\|hadoop.security.authentication\|hbase.security.authentication" "$TDH_CLIENT_HOME/conf"
```

如果出现：

```xml
<property>
  <name>hadoop.security.authentication</name>
  <value>kerberos</value>
</property>
```

则 Hadoop 基础服务按 Kerberos 处理。

如果值为 `simple` 或该项缺失，则默认 Hadoop 基础服务不是 Kerberos。

#### 4.2 服务判定

- HDFS / YARN
  - 查看 `core-site.xml` 的 `hadoop.security.authentication`
- HBase / Hyperbase
  - 查看 `hbase-site.xml` 的 `hbase.security.authentication`
- Inceptor / ArgoDB / Quark
  - 查看 `quark*/hive-site.xml` 的 `hive.server2.authentication`

Quark 的判定逻辑：

- `hive.server2.authentication=kerberos`
  - 按 Kerberos 处理
- Hadoop 基础服务已是 Kerberos，且 Quark 未显式否定
  - 先按 Kerberos 处理
- 未判定为 Kerberos
  - 先按无认证处理
- 无认证失败
  - 标记为 `LDAP_POSSIBLE`
  - 如需继续执行，再提供 `TDH_LDAP_USERNAME` 和 `TDH_LDAP_PASSWORD`

统一认证输出只有以下四种：

- `KERBEROS`
- `SIMPLE_OR_NONE`
- `LDAP_POSSIBLE`
- `UNKNOWN`

### 步骤 5：选择 keytab

```bash
bash scripts/resolve-keytab.sh <cluster> [service] [explicit_keytab]
```

输入：

- `<cluster>`：目标 `cluster_id`
- `[service]`：可选，默认 `hive`
- `[explicit_keytab]`：可选，显式指定 keytab 路径

候选顺序：

1. 用户显式指定的 keytab
2. 当前集群已配对的 Kerberos 目录中的 keytab
3. `TDH_CLIENT_HOME` 根目录直属的 `*.keytab`
4. 当前工作目录下的 `*.keytab`

选择规则：

- 对每个候选执行 `klist -k`
- 只保留 Realm 与当前集群一致的 principal
- 优先级如下：
  - 通用或 SQL：`hive > hdfs > yarn`
  - HDFS：`hdfs > hive > yarn`
  - YARN：`yarn > hive > hdfs`
- 同一优先级命中多个 principal 时直接失败
- 非 Kerberos 集群会输出“当前集群不需要 keytab”

### 步骤 6：定位 Quark-Server

Hive / Quark 连接前，必须先从当前集群配置中提取 Quark 候选，不能假设固定地址。

优先级：

1. `hive-site.xml` 中的 `transwarp.docker.inceptor`
2. `hive.server2.thrift.bind.host` + `hive.server2.thrift.port`
3. 只有 host 没有 port 时，补端口 `10000`

典型排查命令：

```bash
grep -R "transwarp.docker.inceptor" "$TDH_CLIENT_HOME/conf"/*/hive-site.xml 2>/dev/null
grep -R "hive.server2.thrift.bind.host\|hive.server2.thrift.port" "$TDH_CLIENT_HOME/conf"/*/hive-site.xml 2>/dev/null
```

脚本会按候选顺序做两层验证：

1. 端口探测

```bash
timeout 2 bash -c "cat < /dev/null > /dev/tcp/<host>/<port>"
```

2. `beeline` 探活

```bash
beeline -u "<jdbc_url>" -e "SELECT 1;"
```

第一个验证成功的候选会成为本次任务的：

- `SELECTED_QUARK_SERVER`
- `SELECTED_QUARK_PORT`
- `SELECTED_JDBC_URL`

### 步骤 7：在新 shell 中执行命令

```bash
bash scripts/run-with-env.sh <cluster> -- "<command>"
```

输入：

- `<cluster>`：目标 `cluster_id`
- `<command>`：要执行的完整 Linux Bash 命令

作用：

- 生成当前任务专属的 bootstrap 文件
- 设置 `TDH_CLIENT_HOME`
- 设置 `KRB5_CONFIG`
- 设置独立的 `KRB5CCNAME`
- `source "$TDH_CLIENT_HOME/init.sh" n n`
- Kerberos 集群下检查或执行 `kinit -kt`
- 在新的交互 shell 中执行 `<command>`

示例：

```bash
bash scripts/run-with-env.sh alpha-prod-config -- "hdfs dfs -ls /"
```

### 步骤 8：执行服务验证并落盘

```bash
bash scripts/connect.sh <cluster> <service|all>
```

输入：

- `<cluster>`：目标 `cluster_id`
- `<service|all>`：`hdfs`、`yarn`、`hive`、`kafka`、`zookeeper` 或 `all`

作用：

- 自动完成认证判定
- 自动选择 keytab
- 自动发现并验证 Quark
- 按服务执行验证命令
- 把所有证据写入本地结果目录

结果目录：

```text
~/tdh-test-results/<timestamp>-<cluster_id>/
```

固定输出：

- `cases.md`
- `cluster-context.txt`
- `auth-detection.txt`
- `commands.log`
- `results/`
- `summary.md`

其中 `results/` 至少包含：

- `quark-discovery.stdout.log`
- `quark-discovery.stderr.log`
- `<service>.stdout.log`
- `<service>.stderr.log`

## JDBC URL 规则

Hive / Quark 连接使用 `jdbc:hive2://<host>:<port>/<database>`。

Kerberos 场景：

- 优先使用配置中的 `hive.server2.authentication.kerberos.principal`
- 配置缺失时，回退为 `hive/<host>@<REALM>`

无认证场景：

- 先使用不带 principal 的 JDBC URL

LDAP 场景：

- 使用无认证尝试失败后，再结合 `TDH_LDAP_USERNAME` 与 `TDH_LDAP_PASSWORD` 继续尝试

## SQL 语法报错处理

当 Hive / Quark SQL 执行失败时，排查顺序固定为：

1. ArgoDB 官方文档
2. Inceptor 官方文档
3. Hive 官方文档或 Hive 社区资料
4. 定向网络检索

`summary.md` 中必须记录：

- 原始 SQL
- 原始报错
- 查阅来源
- 最终采用的语法依据
- 修正后的 SQL 或下一步建议

不要只写“疑似 Hive 语法问题”这种模糊结论。

## 统一资源附录

当编写 SQL、使用客户端工具或查询 API 语法时，优先参考以下资源：

| 用途 | 文档链接 |
|------|---------|
| 文档中心（总入口） | https://www.transwarp.cn/doc |
| TDH 平台总览 | https://transwarp.cn/doc/tdh/9.4 |
| Inceptor SQL 语法（Hive 兼容 SQL） | https://transwarp.cn/doc/inceptor/9.4 |
| Hyperbase 操作（HBase 兼容） | https://transwarp.cn/doc/hyperbase/9.3 |
| Scope 全文检索 | https://transwarp.cn/doc/scope/3.0 |
| StellarDB 图查询 | https://transwarp.cn/doc/stellardb/5.1 |
| ArgoDB 分析型数据库 | https://transwarp.cn/doc/argodb/6.0 |
| Slipstream 流计算 | 在文档中心内查找 Slipstream |

技术支持入口：

| 资源 | 链接 | 说明 |
|------|------|------|
| Knowledge Base | https://kb.transwarp.cn | 技术文章、故障排查、最佳实践 |
| 开发者社区 | https://community.transwarp.cn | 问答、社区版资源、驱动下载 |

## 脚本职责

- `scripts/discover-clusters.sh`
  - 扫描集群并刷新索引
- `scripts/switch-cluster.sh`
  - 切换 `conf` / `kerberos` 软链并输出当前集群摘要
- `scripts/check-env.sh`
  - 检查运行环境和索引状态
- `scripts/check-auth.sh`
  - 输出总体认证判定和服务认证判定
- `scripts/resolve-keytab.sh`
  - 解析当前集群应使用的 keytab 与 principal
- `scripts/run-with-env.sh`
  - 生成 bootstrap、设置独立票据缓存，并在新 shell 中执行命令
- `scripts/connect.sh`
  - 执行服务验证并统一落盘
- `scripts/setup-env.sh`
  - 输出推荐的执行入口和命令格式

## 常用输入示例

```bash
export TDH_CLIENT_HOME="$HOME/TDH-Client"
bash scripts/discover-clusters.sh
bash scripts/check-auth.sh alpha-prod-config
bash scripts/resolve-keytab.sh alpha-prod-config hive
bash scripts/run-with-env.sh alpha-prod-config -- "hdfs dfs -ls /"
bash scripts/connect.sh alpha-prod-config all
```

## 内部资源

- 配置模板：[references/cluster-config-template.md](references/cluster-config-template.md)
- 配置说明：[references/cluster-config.md](references/cluster-config.md)
- 测试脚本：[tests/test_tdh_cluster.sh](tests/test_tdh_cluster.sh)
