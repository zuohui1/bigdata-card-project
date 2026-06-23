#!/bin/bash
HIVE_HOME=/usr/local/hive
SQL_FILE=/home/zuohui/bigdata_card/scripts/create_card_dw.sql

# ======= 终极修复：注入本地模式最高容错、内存扩容与强力降维参数 =======
BASE_HIVE_CONF="
SET hive.exec.mode.local.auto=true;
-- 降低本地模式的自动切分阈值，防止单任务吞入过多数据导致 OOM
SET hive.exec.mode.local.auto.inputbytes.max=50000000;
SET hive.exec.dynamic.partition=true;
SET hive.exec.dynamic.partition.mode=nonstrict;
-- 强行调大 MapReduce 本地任务的内存映射
SET mapreduce.map.memory.mb=2048;
SET mapreduce.reduce.memory.mb=2048;
SET mapreduce.local.map.tasks.maximum=4;
-- 解决 Stage-4 类似后置统计任务崩溃：关闭 Hive 自动收集统计信息
SET hive.stats.autogather=false;
"

# 临时提升运行此脚本的 Hive 客户端本地 JVM 内存（关键：注入本地模式底层算力支持）
export HADOOP_CLIENT_OPTS="-Xmx2048m -XX:InitiatingHeapOccupancyPercent=60 $HADOOP_CLIENT_OPTS"

echo "===== 阶段1：建库建表 + ODS清洗写入DWD明细 ====="
$HIVE_HOME/bin/hive -e "$BASE_HIVE_CONF; source $SQL_FILE;"

echo -e "\n===== 阶段2：DWS日汇总（学生消费档次预计算） ====="
$HIVE_HOME/bin/hive -e "
$BASE_HIVE_CONF
USE card_dw;

-- 临时表计算全量学生消费等级
CREATE TEMPORARY TABLE tmp_stu_level AS
SELECT
    stu_id,
    CASE
        WHEN SUM(amount) < 100 THEN 1
        WHEN SUM(amount) < 500 THEN 2
        ELSE 3
    END AS consume_level
FROM dwd_card_consume_detail
GROUP BY stu_id;

-- 动态分区写入日汇总表
INSERT OVERWRITE TABLE dws_card_day_summary PARTITION(dt)
SELECT
    t1.stu_id,
    t1.consume_dt,
    SUM(t1.amount) AS total_consume,
    COUNT(*) AS consume_cnt,
    ROUND(AVG(t1.amount),2) AS avg_amount,
    t2.consume_level,
    t1.dt
FROM dwd_card_consume_detail t1
LEFT JOIN tmp_stu_level t2 ON t1.stu_id = t2.stu_id
GROUP BY t1.stu_id, t1.consume_dt, t2.consume_level, t1.dt;
"

echo -e "\n===== 阶段3：ADS月度宽表汇总 ====="
$HIVE_HOME/bin/hive -e "
$BASE_HIVE_CONF
USE card_dw;

CREATE TEMPORARY TABLE tmp_stu_level AS
SELECT
    stu_id,
    CASE
        WHEN SUM(amount) < 100 THEN 1
        WHEN SUM(amount) < 500 THEN 2
        ELSE 3
    END AS consume_level
FROM dwd_card_consume_detail
GROUP BY stu_id;

INSERT OVERWRITE TABLE ads_card_month_report
SELECT
    t1.stu_id,
    '2026-06' AS month,
    SUM(t1.amount) AS month_total,
    COUNT(*) AS month_order_cnt,
    ROUND(SUM(t1.amount)/30,2) AS day_avg_consume,
    SUM(CASE WHEN consume_place IN ('食堂一楼','食堂二楼') THEN amount ELSE 0 END) AS canteen_cost,
    SUM(CASE WHEN consume_place = '校园超市' THEN amount ELSE 0 END) AS shop_cost,
    SUM(CASE WHEN consume_place IN ('热水机','宿舍门禁') THEN amount ELSE 0 END) AS water_dorm_cost,
    t2.consume_level
FROM dwd_card_consume_detail t1
LEFT JOIN tmp_stu_level t2 ON t1.stu_id = t2.stu_id
GROUP BY t1.stu_id, t2.consume_level;
"

echo -e "\n===== 数据校验 ===="
echo "==== DWD明细分区 ===="
$HIVE_HOME/bin/hive -e "USE card_dw; SHOW PARTITIONS dwd_card_consume_detail;"

echo "==== ADS月度报表前10条 ===="
$HIVE_HOME/bin/hive -e "USE card_dw; SELECT * FROM ads_card_month_report LIMIT 10;"

echo "==== 各消费档次人数统计 ===="
$HIVE_HOME/bin/hive -e "USE card_dw; SELECT consume_level,COUNT(DISTINCT stu_id) student_num FROM ads_card_month_report GROUP BY consume_level;"
