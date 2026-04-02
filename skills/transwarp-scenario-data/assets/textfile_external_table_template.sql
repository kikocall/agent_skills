-- 默认用于本地 txt 写盘后，在 HDFS 上创建 TEXTFILE 外表。

create external table if not exists ${database}.${table_name}_txt_ext (
  ${column_definitions}
)
partitioned by (${partition_definitions})
row format delimited
fields terminated by '${field_delimiter}'
lines terminated by '\n'
stored as textfile
location '${hdfs_location}'
;
