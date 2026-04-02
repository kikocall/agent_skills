# TDH 集群配置模板

## 使用说明

本文档是 TDH 集群配置的通用模板。实际使用时，需要根据具体集群信息填写。

## 集群信息（需填写）

| 项目 | 值 |
|------|-----|
| 集群名称 | {集群名称} |
| Kerberos Realm | {REALM} |
| Manager 地址 | {URL} |

## 节点信息（需填写）

| 主机名 | IP 地址 | 角色 |
|--------|---------|------|
| {host1} | {ip1} | NameNode, DataNode, ... |
| {host2} | {ip2} | DataNode, ... |
| {host3} | {ip3} | DataNode, ... |

## 如何获取集群配置

### 从配置文件读取

```bash
# 查看 HDFS NameNode 地址
grep -A5 "dfs.nameservices" ~/TDH-Client/conf/tdfs*/hdfs-site.xml

# 查看 YARN ResourceManager 地址
grep -A5 "yarn.resourcemanager.ha.rm-ids" ~/TDH-Client/conf/yarn*/yarn-site.xml

# 查看 ZooKeeper 地址
grep "ha.zookeeper.quorum" ~/TDH-Client/conf/tdfs*/hdfs-site.xml

# 查看 HiveServer2 地址
grep "hive.server2.thrift.bind.host" ~/TDH-Client/conf/quark*/hive-site.xml

# 查看 Kafka Broker 地址
grep "bootstrap.servers" ~/TDH-Client/conf/eventstore*/server.properties

# 查看 Kerberos Realm
grep "default_realm" ~/TDH-Client/kerberos/krb5.conf

# 查看 KDC 地址
grep -A5 "\[realms\]" ~/TDH-Client/kerberos/krb5.conf
```

### 从 Manager Web UI 获取

1. 登录 Manager: https://{manager_ip}:8180
2. 用户名/密码: admin/{密码}
3. 仪表盘 → 集群 → 各服务详情

## HDFS 配置模板

```xml
<!-- core-site.xml -->
<property>
    <name>fs.defaultFS</name>
    <value>hdfs://{nameservice}</value>
</property>
<property>
    <name>hadoop.security.authentication</name>
    <value>{kerberos|simple}</value>
</property>
```

```xml
<!-- hdfs-site.xml -->
<property>
    <name>dfs.nameservices</name>
    <value>{nameservice}</value>
</property>
<property>
    <name>dfs.ha.namenodes.{nameservice}</name>
    <value>nn0,nn1,nn2</value>
</property>
<property>
    <name>dfs.namenode.rpc-address.{nameservice}.nn0</name>
    <value>{host1}:8020</value>
</property>
<!-- nn1, nn2 同理 -->
```

## YARN 配置模板

```xml
<!-- yarn-site.xml -->
<property>
    <name>yarn.resourcemanager.ha.enabled</name>
    <value>true</value>
</property>
<property>
    <name>yarn.resourcemanager.ha.rm-ids</name>
    <value>rm1,rm2</value>
</property>
<property>
    <name>yarn.resourcemanager.hostname.rm1</name>
    <value>{host1}</value>
</property>
<property>
    <name>yarn.resourcemanager.hostname.rm2</name>
    <value>{host2}</value>
</property>
```

## Kerberos 配置模板

```ini
[libdefaults]
default_realm = {REALM}
dns_lookup_realm = false
dns_lookup_kdc = false
ticket_lifetime = 24h
renew_lifetime = 7d
forwardable = true

[realms]
{REALM} = {
kdc = {kdc_host1}:{port}
kdc = {kdc_host2}:{port}
}

[domain_realm]
.{domain} = {REALM}
```

## Inceptor/Quark 配置

```bash
# 连接字符串模板
beeline -u "jdbc:hive2://{hiveserver2_host}:10000/{database};principal=hive/_HOST@{REALM}"
```

## Kafka 配置

```bash
# Broker 地址模板
{broker_host}:{port}

# 连接命令模板
kafka-topics.sh --list --bootstrap-server {broker_host}:{port}
```

## ZooKeeper 配置

```bash
# 连接命令模板
zookeeper-client -server {zk_host1}:{port},{zk_host2}:{port},{zk_host3}:{port}
```

## 环境变量

运行 `source init.sh n n` 后设置的主要环境变量：

```bash
HADOOP_HOME=~/TDH-Client/hadoop/hadoop
HADOOP_CONF_DIR=~/TDH-Client/conf/hadoop
HIVE_HOME=~/TDH-Client/inceptor
HIVE_CONF_DIR=~/TDH-Client/conf/inceptor
KAFKA_HOME=~/TDH-Client/kafka
ZOOKEEPER_HOME=~/TDH-Client/zookeeper
ZOOKEEPER_CONF=~/TDH-Client/conf/zookeeper
KRB5_CONFIG=~/TDH-Client/kerberos/krb5.conf
```

## 快速诊断命令

```bash
# 检查当前集群配置
ls -l ~/TDH-Client/conf ~/TDH-Client/kerberos

# 检查认证方式
grep -A1 "hadoop.security.authentication" ~/TDH-Client/conf/tdfs*/core-site.xml

# 检查 Kerberos 票据
klist

# 检查 HDFS 连接
hdfs dfs -ls /

# 检查 YARN 连接
yarn node -list
