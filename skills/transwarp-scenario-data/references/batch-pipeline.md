# 批处理流水线

默认主流程是“按批生成文件 -> 上传 HDFS -> 校验 -> 清理本地 -> 下一批”。

## 批次切分原则

- 单批大小要小于本地可用空间的安全阈值
- 单批文件数要控制在可管理范围
- 批次切分优先按分区、日期、机构、哈希范围或业务主键段
- 大维表优先一次性生成，小维表可直接内嵌或随批分发

## 目录与命名

建议包含：

- `scene_name`
- `table_name`
- `batch_id`
- `biz_date`
- `part_no`

示例：

```text
/data/staging/pd01/tbl_fact/biz_date=20260328/batch-0001/part-00001.parquet
```

## 每批标准动作

1. 规划本批范围
2. 生成本地文件
3. 记录本地文件、行数、大小
4. 上传到 HDFS
5. 校验 HDFS 文件存在且大小合理
6. 更新 manifest/checkpoint
7. 删除本地文件
8. 进入下一批

## manifest 建议字段

- `batch_id`
- `table_name`
- `status`
- `local_path`
- `hdfs_path`
- `row_count`
- `file_count`
- `bytes`
- `started_at`
- `finished_at`
- `retry_count`

## 失败处理

- 上传失败可重试
- HDFS 校验失败不删本地文件
- 清理前必须先更新 checkpoint
- 支持从最后一个成功批次继续跑
