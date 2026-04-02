---
name: tdh-cluster
description: 操作和管理星环 TDH (Transwarp Data Hub) 集群。支持动态扫描集群配置、认证方式识别、keytab 选择、HDFS/YARN/Inceptor/Quark/Kafka/ZooKeeper 连接验证，以及测试结果本地落盘。当用户提到 TDH、星环、TDFS、Inceptor、Quark、Transwarp 集群运维时使用此技能。
---

# TDH 集群管理技能

这个 skill 面向 Linux Bash 环境，使用 TDH-Client 完成集群发现、认证判定、keytab 选择、Quark 连接验证和结果落盘。

## 适用范围

当任务涉及以下内容时使用这个 skill：

- 扦描 TDH-Client 下的集群配置和 Kerberos 目录
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

执行脚本䉍，至少要确认以下输入：

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

每朡执行命令时，脚本会为当前任务生成临时 bootstrap 文件，并用下面两种方式之一启动新的交互 shell：

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

每朡任务使用独立的 `KRB5CCNAME`，格式类似：

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
- 扦描 `TDH_CLIENT_HOME` 根目录下的 Kerberos 目录候选
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
- `KERBEROS_DIR0
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
  - 如需继续执行，再提供 `TDH_LDAP_USERNAME` 和 `TDH_LDAP_PASSWORD` 继续尝试

w��一记证输出只有以下囚种：

- �`KERBEROS`
- `