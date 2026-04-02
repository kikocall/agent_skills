# 集群配置模板

这个模板用于整理某个集群的基本信息，方便排查目录扫描、认证判断和连接验证问题。

## 1. 基础信息

```text
集群标识:
配置目录:
Kerberos 目录:
Manager 地址:
```

## 2. 认证信息

```text
Kerberos Realm:
基础 Hadoop 认证方式:
HBase 认证方式:
Quark 认证方式:
```

## 3. 关键配置检查点

### Hadoop

```xml
<property>
  <name>hadoop.security.authentication</name>
  <value>kerberos|simple</value>
</property>
```

### HBase / Hyperbase

```xml
<property>
  <name>hbase.security.authentication</name>
  <value>kerberos|simple</value>
</property>
```

### Quark / Inceptor / ArgoDB

```xml
<property>
  <name>hive.server2.authentication</name>
  <value>KERBEROS|LDAP|NONE</value>
</property>
```

## 4. keytab 信息

```text
候选 keytab:
选中的 keytab:
选中的 principal:
选择原因:
```

## 5. 常用验证命令

```bash
bash scripts/discover-clusters.sh
bash scripts/check-auth.sh <cluster>
bash scripts/resolve-keytab.sh <cluster> hive
bash scripts/run-with-env.sh <cluster> -- "hdfs dfs -ls /"
bash scripts/connect.sh <cluster> all
```
