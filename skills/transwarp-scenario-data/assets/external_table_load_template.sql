-- 先按现场 DDL 风格替换字段、分区和分布定义。

create external table if not exists ext_${table_name} (
  ${column_definitions}
)
stored as ${file_format}
location '${hdfs_location}';

insert overwrite table ${target_table}
select
  ${select_list}
from ext_${table_name};
