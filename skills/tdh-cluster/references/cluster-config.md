# 集群配置说明

新版 `tdh-cluster` skill 不再依赖固定的 `*-conf` 或 `*-kerberos` 命名约定，而是通过扫描目录内容来识别集群。

识别要点：

- 配置目录至少应包含以下文件之一：
  - `core-site.xml`
  - `hdfs-site.xml`
  - `yarn-site.xml`
  - `hive-site.xml`
  - `hbase-site.xml`
  - `server.properties`
- Kerberos 目录至少应包含以下文件之一：
  - `krb5.conf`
  - `*.keytab`
  - `jaas.conf`

推荐做法：

- 将每个集群的 Hadoop / Quark / HBase 等配置放在同一个目录树下
- 将每个集群的 `krb5.conf` 与 `keytab` 放在另一个独立目录树下
- 尽量让配置目录名和 Kerberos 目录名有可读的关联，便于自动配对
- 仍然保留 `TDH-Client/conf` 与 `TDH-Client/kerberos` 软链作为“当前激活集群”的显式入口

如果某个集群在扫描结果中出现 `pairing_status=ambiguous`，说明系统无法安全判断它应该配哪套 Kerberos 目录，此时需要：

1. 调整目录命名，增强对应关系
2. 或者先手工切换 `conf` / `kerberos` 软链，再重新扫描
