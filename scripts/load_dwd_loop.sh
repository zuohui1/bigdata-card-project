#!/bin/bash
HDFS_BIN=/usr/local/hadoop/bin/hdfs
for day in {01..30}
do
    dt="2026-06-$day"
    echo "==================== 开始处理 $dt ===================="
    hive -e "
    SET mapreduce.framework.name=yarn;
    SET hive.exec.dynamic.partition=true;
    SET hive.exec.dynamic.partition.mode=nonstrict;
    USE card_dw;
    INSERT OVERWRITE TABLE dwd_card_consume_detail PARTITION(dt='$dt')
    SELECT
        stu_id,
        '$dt' AS consume_dt,
        split(consume_time, ' ')[1] AS consume_hour,
        consume_place,
        amount,
        consume_time AS consume_time_full
    FROM ods_card_consume
    WHERE dt='$dt'
      AND amount > 0
      AND LENGTH(stu_id) = 7;
    "
    echo "分区 $dt 加载完成"
    echo ""
done
echo "==== 全部30天DWD加载完成 ===="
hive -e "USE card_dw; SHOW PARTITIONS dwd_card_consume_detail;"
