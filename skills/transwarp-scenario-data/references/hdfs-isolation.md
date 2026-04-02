# HDFS 路径隔离

大数据场景下，HDFS 路径隔离是硬规则，不是可选优化。

## 每次任务都要检查

- 根路径是否存在
- 根路径下是否已有旧文件
- 本次运行是否应该复用旧目录
- 如果不能复用，是否需要新的 run_id 或时间戳目录

## 推荐路径结构

```text
/scene-repro/cup/c_full/<scene_name>/run_dt=YYYYMMDD/run_id=<id>/<table_name>/...
```

## 默认策略

- 如果路径不存在：创建
- 如果路径存在但为空：可用
- 如果路径存在且非空：默认报错或切新 run_id
- 不要静默覆盖已有目录

## small 与 full

- small 和 full 必须隔离路径
- 不要让 small 的 staging 路径和 full 共用
- run_dt 相同也要区分 mode 或 run_id
