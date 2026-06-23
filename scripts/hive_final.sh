#!/bin/bash
HIVE_HOME=/usr/local/hive

echo "===== 清空所有表并重新构建 ====="

$HIVE_HOME/bin/hive << 'EOF'
SET hive.exec.dynamic.partition=true;
SET hive.exec.dynamic.partition.mode=nonstrict;
SET hive.exec.max.dynamic.partitions=1000;
SET hive.exec.max.dynamic.partitions.pernode=500;

-- 彻底删除所有表
DROP DATABASE IF EXISTS card_dw CASCADE;
CREATE DATABASE card_dw;
USE card_dw;

-- ===== 1. ODS层 =====
CREATE EXTERNAL TABLE ods_card_consume (
    stu_id STRING,
    consume_time STRING,
    consume_place STRING,
    amount DECIMAL(5,2)
)
PARTITIONED BY (dt STRING)
ROW FORMAT DELIMITED
FIELDS TERMINATED BY ','
STORED AS TEXTFILE
LOCATION '/card/raw_data';

MSCK REPAIR TABLE ods_card_consume;

-- 验证ODS
SELECT '✅ ODS分区数' AS status, COUNT(DISTINCT dt) AS cnt FROM ods_card_consume;

-- ===== 2. DWD层 =====
CREATE TABLE dwd_card_consume_detail (
    stu_id STRING,
    consume_dt STRING,
    consume_hour INT,
    consume_place STRING,
    amount DECIMAL(5,2),
    consume_time_full STRING
)
PARTITIONED BY (dt STRING)
STORED AS ORC;

INSERT OVERWRITE TABLE dwd_card_consume_detail PARTITION(dt)
SELECT
    stu_id,
    substr(consume_time, 1, 10) AS consume_dt,
    CAST(substr(consume_time, 12, 2) AS INT) AS consume_hour,
    consume_place,
    amount,
    consume_time AS consume_time_full,
    substr(consume_time, 1, 10) AS dt
FROM ods_card_consume
WHERE amount > 0 
  AND length(stu_id) = 7
  AND consume_time IS NOT NULL;

-- 验证DWD
SELECT '✅ DWD分区数' AS status, COUNT(DISTINCT dt) AS cnt FROM dwd_card_consume_detail;
SELECT '✅ DWD总行数' AS status, COUNT(*) AS cnt FROM dwd_card_consume_detail;

-- ===== 3. DWS层 =====
CREATE TABLE dws_card_day_summary (
    stu_id STRING,
    consume_dt STRING,
    total_consume DECIMAL(8,2),
    consume_cnt INT,
    avg_amount DECIMAL(5,2),
    consume_level TINYINT
)
PARTITIONED BY (dt STRING)
STORED AS ORC;

INSERT OVERWRITE TABLE dws_card_day_summary PARTITION(dt)
SELECT
    stu_id,
    consume_dt,
    SUM(amount) AS total_consume,
    COUNT(*) AS consume_cnt,
    ROUND(AVG(amount), 2) AS avg_amount,
    CASE 
        WHEN SUM(amount) < 100 THEN 1
        WHEN SUM(amount) < 500 THEN 2
        ELSE 3
    END AS consume_level,
    dt
FROM dwd_card_consume_detail
GROUP BY stu_id, consume_dt, dt;

-- 验证DWS
SELECT '✅ DWS分区数' AS status, COUNT(DISTINCT dt) AS cnt FROM dws_card_day_summary;
SELECT '✅ DWS总行数' AS status, COUNT(*) AS cnt FROM dws_card_day_summary;

-- ===== 4. ADS层 =====
CREATE TABLE ads_card_month_report (
    stu_id STRING,
    month STRING,
    month_total DECIMAL(8,2),
    month_order_cnt INT,
    day_avg_consume DECIMAL(6,2),
    canteen_cost DECIMAL(7,2),
    shop_cost DECIMAL(7,2),
    water_dorm_cost DECIMAL(7,2),
    consume_level TINYINT
)
STORED AS ORC;

INSERT OVERWRITE TABLE ads_card_month_report
SELECT
    stu_id,
    '2026-06' AS month,
    SUM(amount) AS month_total,
    COUNT(*) AS month_order_cnt,
    ROUND(SUM(amount) / 30, 2) AS day_avg_consume,
    SUM(CASE WHEN consume_place IN ('食堂一楼', '食堂二楼') THEN amount ELSE 0 END) AS canteen_cost,
    SUM(CASE WHEN consume_place = '校园超市' THEN amount ELSE 0 END) AS shop_cost,
    SUM(CASE WHEN consume_place IN ('热水机', '宿舍门禁') THEN amount ELSE 0 END) AS water_dorm_cost,
    CASE 
        WHEN SUM(amount) < 100 THEN 1
        WHEN SUM(amount) < 500 THEN 2
        ELSE 3
    END AS consume_level
FROM dwd_card_consume_detail
GROUP BY stu_id;

-- 验证ADS
SELECT '✅ ADS总行数' AS status, COUNT(*) AS cnt FROM ads_card_month_report;

-- ===== 最终展示 =====
SELECT '========================================' AS info;
SELECT '         🎉 数仓四层构建完成！' AS info;
SELECT '========================================' AS info;

SELECT 'ODS (原始数据)' AS layer, COUNT(*) AS row_count FROM ods_card_consume
UNION ALL
SELECT 'DWD (清洗明细)', COUNT(*) FROM dwd_card_consume_detail
UNION ALL
SELECT 'DWS (日汇总)', COUNT(*) FROM dws_card_day_summary
UNION ALL
SELECT 'ADS (月报表)', COUNT(*) FROM ads_card_month_report;

SELECT '========================================' AS info;
SELECT '         📊 ADS月报表 TOP 10' AS info;
SELECT '========================================' AS info;

SELECT 
    stu_id,
    month_total AS 月消费总额,
    month_order_cnt AS 消费笔数,
    day_avg_consume AS 日均消费,
    canteen_cost AS 食堂消费,
    shop_cost AS 超市消费,
    CASE consume_level 
        WHEN 1 THEN '节俭型'
        WHEN 2 THEN '普通型'
        WHEN 3 THEN '富裕型'
    END AS 消费类型
FROM ads_card_month_report 
ORDER BY month_total DESC 
LIMIT 10;
EOF

echo ""
echo "==================== ✅ 全部完成 ===================="
