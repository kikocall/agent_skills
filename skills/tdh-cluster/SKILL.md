---
name: tdh-cluster
description: 操作和管理星环 TDH (Transwarp Data Hub) 大数据集群。支持多集群切换、HDFS/TDFS 文件操作、YARN 任务管理、Inceptor SQL 查询、Kafka 消息队列、ZooKeeper 管理、Kerberos 认证。当用户提到 TDH、星环、TDFS、Inceptor、Quark、Transwarp 集群运维时使用此技能。
---

# TDH 集群管理技能

操作星环 TDH 大数据集群的通用指南，支持多集群切换。

## 核心设计原则

### 安全边界：禁止修改系统配置文件

**绝对禁止修改的文件**（除非用户明确要求）：
- `/etc/hosts`、`/etc/krb5.conf` 等系统配置文件
- TDH-Client 自带的配置文件（`conf/`、`kerberos/` 下的文件）
- 非本次任务生成或指定的任何文件

**如果任务确实需要修改上述文件，必须先询问用户确认。**

### 环境变量管理：使用 `.my_env.sh` + `bash -i -c`

**问题**：OpenCode的bash工具每次执行都是独立的非交互式shell，不会加载.bashrc，导致环境变量丢失。

**解决方案**：
1. 创建 `~/.my_env.sh` 存放所有 TDH 环境初始化命令
2. 在 `~/.bashrc` 末尾**仅添加一行**加载语句（先检查是否已存在）
3. 所有需要环境变量的命令使用 `bash -i -c "..."` 执行
4. 任务完成后清理 `.my_env.sh` 

```bash
# ✅ 正确：使用交互式shell
bash -i -c "beeline -u 'jdbc:hive2://xh13537:10000/default;principal=hive/xh13537@TDHXH' -e 'SHOW DATABASES;'"

# ❌ 错误：直接执行无法获取环境变量
beeline -u "jdbc:hive2://xh13537:10000/default;principal=hive/xh13537@TDHXH"
```

### 工作路径保护

**禁止在 source 命令中切换工作目录**。必须使用绝对路径：
```bash
# ✅ 正确：直接 source 绝对路径，不改变工作目录
source $HOME/TDH-Client/init.sh n n

# ❌ 错误：cd 会改变工作目录，影响后续操作
cd $HOME/TDH-Client && source init.sh n n
```

## TDH-Client 目录结构

```
TDH-Client/
├── conf -> {cluster}-conf/     # 软链接，指向当前集群配置
├── kerberos -> {cluster}-kerberos/  # 软链接，指向当前集群 Kerberos
├── hadoop/                     # HDFS/YARN 客户端工具
├── inceptor/                   # Beeline 客户端工具
├── kafka/                      # Kafka 客户端工具
├── zookeeper/                  # ZooKeeper 客户端工具
├── hyperbase/                  # HBase 客户端工具
├── impexp/                     # 批量文件加载卸载工具
├── sqoop/                      # 文件传输工具（可选）
├── flink-*/                    # Flink 客户端
├── spark-*/                    # Spark 客户端
├── init.sh                     # 环境初始化脚本
├── hosts                       # 集群 DNS 配置
├── {cluster}-conf/             # 集群配置
├── {cluster}-kerberos/         # 集群 Kerberos 配置
└── *.keytab                    # Kerberos 认证文件
```

**核心概念**：不同集群的区别在于 conf、kerberos、hosts，其他工具是通用的。切换集群只需修改软链接。

## 完整使用流程

### 阶段 1：环境检测与初始化

**步骤 1.1：检查必需环境**

```bash
# 检查 Java 版本（需要 1.8+）
java -version 2>&1 | head -1

# 检查 Kerberos 客户端
which kinit
```

**步骤 1.2：定位 TDH-Client**

```bash
# 常见位置检查
ls -la ~/TDH-Client 2>/dev/null || ls -la /opt/TDH-Client 2>/dev/null

# 如果找不到，询问用户
```

**步骤 1.3：配置 .my_env.sh 并使用 bash -i -c**

检测环境后，创建 `~/.my_env.sh` 存放 TDH 环境初始化命令，并在 `.bashrc` 中添加单行加载：

```bash
# 创建 .my_env.sh（TDH 环境初始化配置）
cat > ~/.my_env.sh << 'EOF'
export TDH_CLIENT_HOME="$HOME/TDH-Client"
export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64
export KRB5_CONFIG=$TDH_CLIENT_HOME/kerberos/krb5.conf

if [ -f "$TDH_CLIENT_HOME/init.sh" ]; then
    source $TDH_CLIENT_HOME/init.sh n n > /dev/null 2>&1
fi
EOF

# 在 .bashrc 中添加加载语句（先检查是否已存在，避免重复）
if ! grep -q '\[ -f ~/.my_env.sh \] && source ~/.my_env.sh' ~/.bashrc 2>/dev/null; then
    echo '[ -f ~/.my_env.sh ] && source ~/.my_env.sh' >> ~/.bashrc
fi
```

**后续所有命令使用 `bash -i -c` 执行：**

```bash
# 示例：执行 beeline 查询
bash -i -c "beeline -u 'jdbc:hive2://xh13537:10000/default;principal=hive/xh13537@TDHXH' -e 'SHOW DATABASES;'"

# 示例：执行 hdfs 命令
bash -i -c "hdfs dfs -ls /"
```

### 阶段 2：Keytab 智能管理

**步骤 2.1：搜索 Keytab 文件**

按以下顺序搜索：
1. 当前工作目录
2. TDH-Client 目录
3. 用户指定目录

```bash
# 搜索 keytab 文件
KEYTAB_PATHS=(
    "./quark.keytab"
    "$TDH_CLIENT_HOME/quark.keytab"
    "$HOME/quark.keytab"
)

KEYTAB_FILE=""
for path in "${KEYTAB_PATHS[@]}"; do
    if [ -f "$path" ]; then
        KEYTAB_FILE="$path"
        break
    done
done

# 如果找不到，尝试在常见位置查找
if [ -z "$KEYTAB_FILE" ]; then
    KEYTAB_FILE=$(find ~ -name "*.keytab" -type f 2>/dev/null | head -1)
fi

# 如果仍找不到，询问用户
if [ -z "$KEYTAB_FILE" ]; then
    echo "未找到 keytab 文件，请提供路径"
    # 等待用户输入
fi
```

**步骤 2.2：识别 Keytab 中的用户**

```bash
# 列出 keytab 中的 principal
klist -k $KEYTAB_FILE

# 输出示例：
# hive/xh13537@TDHXH
# hdfs/xh13537@TDHXH
# yarn/xh13537@TDHXH
```

**用户优先级**（根据测试需求选择）：
- `hive` - Quark/Inceptor 超级管理员（数据库操作）
- `hdfs` - TDFS/HDFS 超级管理员（文件系统操作）
- `yarn` - YARN 超级管理员（资源调度）

**默认选择**：如果没有特殊要求，优先使用 `hive` 用户

**步骤 2.3：执行认证并添加到 .my_env.sh**

```bash
# 执行认证
kinit -kt $KEYTAB_FILE hive/xh13537@TDHXH

# 验证认证
klist

# 将认证命令追加到 .my_env.sh（而非 .bashrc）
cat >> ~/.my_env.sh << EOF

# Kerberos 认证
if [ -f "$KEYTAB_FILE" ]; then
    kinit -kt $KEYTAB_FILE hive/xh13537@TDHXH 2>/dev/null
fi
EOF
```

**权限检查**：如果认证失败，检查权限并提示修复

```bash
# 检查 keytab 权限
PERM=$(stat -c %a "$KEYTAB_FILE")
if [ "$PERM" != "600" ]; then
    echo "警告：keytab 权限不安全（当前 $PERM），建议修复"
    echo "执行：chmod 600 $KEYTAB_FILE"
fi
```

### 阶段 3：Quark-Server 连接

**步骤 3.1：获取 Quark 服务地址**

从配置文件中提取 Quark 服务信息：

```bash
# 查找所有 quark 配置
grep -r "transwarp.docker.inceptor" $TDH_CLIENT_HOME/conf/*/hive-site.xml 2>/dev/null

# 输出示例：
# conf/quark1/hive-site.xml:    <value>xh13537:10000</value>
# conf/quark2/hive-site.xml:    <value>xh13538:10000</value>
```

**步骤 3.2：按顺序尝试连接**

```bash
# 定义所有 Quark 服务
QUARK_SERVERS=(
    "xh13537:10000"
    "xh13538:10000"
    "xh13539:10000"
)

# 逐个尝试连接
CONNECTED=false
for server in "${QUARK_SERVERS[@]}"; do
    HOST=$(echo $server | cut -d: -f1)
    PORT=$(echo $server | cut -d: -f2)
    
    # 检查端口是否开放
    if timeout 2 bash -c "cat < /dev/null > /dev/tcp/$HOST/$PORT" 2>/dev/null; then
        echo "端口 $server 开放，尝试连接..."
        
        # 尝试执行简单查询
        if bash -i -c "beeline -u 'jdbc:hive2://$server/default;principal=hive/$HOST@TDHXH' -e 'SELECT 1;' 2>/dev/null"; then
            QUARK_SERVER=$server
            CONNECTED=true
            echo "成功连接到 $server"
            break
        fi
    fi
done

if [ "$CONNECTED" = false ]; then
    echo "无法连接到任何 Quark 服务"
    exit 1
fi
```

**步骤 3.3：Beeline 连接格式**

```bash
# JDBC URL 格式
# jdbc:hive2://<server_ip/hostname>:<port>/<database_name>;principal=hive/<Quark服务主机名>@TDHXH

# 示例连接串
beeline -u "jdbc:hive2://xh13537:10000/default;principal=hive/xh13537@TDHXH"

# 参数说明：
# - server_ip/hostname: Quark 服务的 IP 或主机名
# - port: 服务端口，默认 10000
# - database_name: 要连接的数据库
# - principal: hive/<Quark服务所属设备的主机名>@TDHXH
```

**端口发现**：如果默认 10000 端口不通，从配置获取

```bash
# 从 hive-site.xml 获取准确端口
grep -A1 "transwarp.docker.inceptor" $TDH_CLIENT_HOME/conf/quark*/hive-site.xml | grep value | head -1
```

### 阶段 4：测试结果输出

**所有测试操作必须同时输出到终端和本地文件**

```bash
# 创建输出目录
OUTPUT_DIR="$HOME/tdh-test-results/$(date +%Y%m%d_%H%M%S)"
mkdir -p $OUTPUT_DIR

# 测试结果同时输出到终端和文件
bash -i -c "beeline -u 'jdbc:hive2://$QUARK_SERVER/default;principal=hive/$HOST@TDHXH' -e 'SHOW DATABASES;'" 2>&1 | tee $OUTPUT_DIR/databases.txt

# SQL 脚本执行
bash -i -c "beeline -u 'jdbc:hive2://$QUARK_SERVER/default;principal=hive/$HOST@TDHXH' -f test.sql" 2>&1 | tee $OUTPUT_DIR/test_result.txt
```

**输出目录结构**：
```
~/tdh-test-results/
└── 20260330_163000/
    ├── databases.txt          # 数据库列表
    ├── tables.txt             # 表列表
    ├── test_result.sql        # 测试 SQL 脚本
    ├── test_result.txt        # 测试输出结果
    └── summary.md             # 测试总结报告
```

### 阶段 5：任务完成清理

**任务完成后，清理 .my_env.sh 和 .bashrc 中的加载语句**

```bash
# 删除 .my_env.sh 文件
rm -f ~/.my_env.sh

# 从 .bashrc 中移除加载语句（精确匹配单行）
sed -i '/\[ -f ~\/.my_env.sh \] \&\& source ~\/.my_env.sh/d' ~/.bashrc

# 销毁 Kerberos 票据
kdestroy 2>/dev/null

echo "清理完成"
```

## init.sh 错误处理说明

### 关于 "找不到 sqoop/dstools 目录" 的报错

这是**正常现象**，不是错误。说明该集群未安装或未使用这些组件。

```bash
# 这些报错可以安全忽略
ERROR, can't find sqoop dir: /home/yxl/TDH-Client/sqoop
ERROR, can't find dstools dir: /home/yxl/TDH-Client/dstools
```

**处理原则**：
- 如果后续操作成功，忽略这些报错
- 如果后续操作失败，将这些报错作为诊断信息之一

### init.sh 参数说明

```bash
source init.sh n n
# 第一个 n: 不修改 /etc/hosts（跳过需要 sudo 的操作）
# 第二个 n: 不安装 Kerberos 客户端（跳过需要 sudo 的操作）
```

## 服务端口参考

| 服务 | 默认端口 | 说明 |
|------|----------|------|
| HDFS NameNode RPC | 8020 | 文件系统访问 |
| HDFS NameNode HTTP | 50070 | Web 管理界面 |
| YARN ResourceManager | 8032 | 资源调度 |
| YARN Web UI | 8088 | Web 管理界面 |
| HiveServer2 (Quark) | 10000 | SQL 查询服务 |
| ZooKeeper | 2181 | 协调服务 |
| Kafka | 9092 | 消息队列 |
| Kerberos KDC | 1088 | 认证服务 |
| LDAP | 10389 | 目录服务 |

## 常用命令速查

### HDFS 操作

```bash
bash -i -c "hdfs dfs -ls /path"
bash -i -c "hdfs dfs -put local /hdfs"
bash -i -c "hdfs dfs -get /hdfs local"
bash -i -c "hdfs dfs -mkdir /path"
bash -i -c "hdfs dfs -rm /path/file"
bash -i -c "hdfs dfs -cat /path/file"
bash -i -c "hdfs dfs -du -s -h /path"
bash -i -c "hdfs dfsadmin -report"
```

### YARN 操作

```bash
bash -i -c "yarn application -list"
bash -i -c "yarn application -status <id>"
bash -i -c "yarn application -kill <id>"
bash -i -c "yarn node -list"
```

### Hive/Inceptor 操作

```bash
# 连接 HiveServer2
bash -i -c "beeline -u 'jdbc:hive2://host:10000/db;principal=hive/host@TDHXH'"

# 执行 SQL 文件
bash -i -c "beeline -u 'jdbc:hive2://...' -f script.sql"

# 执行单条 SQL
bash -i -c "beeline -u 'jdbc:hive2://...' -e 'SHOW DATABASES;'"
```

### Kafka 操作

```bash
bash -i -c "kafka-topics.sh --list --bootstrap-server host:9092"
bash -i -c "kafka-topics.sh --create --topic my-topic --bootstrap-server host:9092 --partitions 3 --replication-factor 2"
```

### ZooKeeper 操作

```bash
bash -i -c "zookeeper-client -server host:2181"
```

## 完整示例：TDH 集群测试流程

```bash
# 1. 环境检测
java -version && which kinit && ls ~/TDH-Client

# 2. 配置 .my_env.sh（TDH 环境初始化）
cat > ~/.my_env.sh << 'EOF'
export TDH_CLIENT_HOME="$HOME/TDH-Client"
export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64
export KRB5_CONFIG=$TDH_CLIENT_HOME/kerberos/krb5.conf
source $TDH_CLIENT_HOME/init.sh n n > /dev/null 2>&1
kinit -kt $TDH_CLIENT_HOME/quark.keytab hive/xh13537@TDHXH 2>/dev/null
EOF

# 在 .bashrc 添加单行加载（先检查是否已存在）
if ! grep -q '\[ -f ~/.my_env.sh \] && source ~/.my_env.sh' ~/.bashrc 2>/dev/null; then
    echo '[ -f ~/.my_env.sh ] && source ~/.my_env.sh' >> ~/.bashrc
fi

# 3. 测试连接
bash -i -c "hdfs dfs -ls /"
bash -i -c "beeline -u 'jdbc:hive2://xh13537:10000/default;principal=hive/xh13537@TDHXH' -e 'SHOW DATABASES;'"

# 4. 执行测试（结果保存到本地）
OUTPUT_DIR=~/tdh-test-$(date +%Y%m%d)
mkdir -p $OUTPUT_DIR
bash -i -c "beeline -u 'jdbc:hive2://xh13537:10000/default;principal=hive/xh13537@TDHXH' -f test.sql" | tee $OUTPUT_DIR/result.txt

# 5. 清理
rm -f ~/.my_env.sh
sed -i '/\[ -f ~\/.my_env.sh \] \&\& source ~\/.my_env.sh/d' ~/.bashrc
kdestroy
```

## 故障排查

### 问题：beeline 连接被拒绝

```bash
# 检查端口是否开放
timeout 2 bash -c "cat < /dev/null > /dev/tcp/xh13537/10000" && echo "端口开放" || echo "端口关闭"

# 检查配置中的正确端口
grep -A1 "transwarp.docker.inceptor" ~/TDH-Client/conf/*/hive-site.xml
```

### 问题：Kerberos 认证失败

```bash
# 检查票据
klist

# 重新认证
kinit -kt ~/TDH-Client/quark.keytab hive/xh13537@TDHXH

# 检查 krb5.conf 配置
cat ~/TDH-Client/kerberos/krb5.conf | grep -A5 "TDHXH"
```

### 问题：环境变量丢失

```bash
# 确认使用了 bash -i -c
bash -i -c "echo \$JAVA_HOME"

# 检查 .bashrc 配置
grep TDH ~/.bashrc
```

## 详细参考

### 本 Skill 内部资源

- **集群配置模板**: 参见 [references/cluster-config-template.md](references/cluster-config-template.md)
- **环境检查脚本**: 参见 [scripts/check-env.sh](scripts/check-env.sh)
- **集群切换脚本**: 参见 [scripts/switch-cluster.sh](scripts/switch-cluster.sh)
- **通用连接脚本**: 参见 [scripts/connect.sh](scripts/connect.sh)

### 星环官方文档（语法与操作参考）

当编写 SQL、使用客户端工具或查询 API 语法时，参考以下官方文档：

| 用途 | 文档链接 |
|------|---------|
| **文档中心（总入口）** | https://www.transwarp.cn/doc |
| **TDH 平台总览** | https://transwarp.cn/doc/tdh/9.4 |
| **Inceptor SQL 语法**（Hive 兼容 SQL） | https://transwarp.cn/doc/inceptor/9.4 |
| **Hyperbase 操作**（HBase 兼容） | https://transwarp.cn/doc/hyperbase/9.3 |
| **Scope 全文检索** | https://transwarp.cn/doc/scope/3.0 |
| **StellarDB 图查询** | https://transwarp.cn/doc/stellardb/5.1 |
| **ArgoDB 分析型数据库** | https://transwarp.cn/doc/argodb/6.0 |
| **Slipstream 流计算** | 文档中心内查找 Slipstream |

### 技术支持

| 资源 | 链接 | 说明 |
|------|------|------|
| **Knowledge Base** | https://kb.transwarp.cn | 技术文章、故障排查、最佳实践 |
| **开发者社区** | https://community.transwarp.cn | 问答、社区版资源、驱动下载 |

**使用建议**：
- 编写 Inceptor SQL → 查 Inceptor 文档的 "SQL 参考" 或 "开发者指南"
- HDFS/TDFS 文件操作 → 优先参考开源HDFS用法，后查 TDH 文档的 "TDFS" 章节
- YARN 任务管理 → 优先参考开源YARN用法，查 TDH 文档的 "综合运维" 章节
- 遇到报错 → 先查 Knowledge Base 搜索错误关键词
