-- 关闭动态分区严格模式
SET hive.exec.dynamic.partition=true;
SET hive.exec.dynamic.partition.mode=nonstrict;
SET hive.exec.mode.local.auto=true;

-- 1. 创建数仓总库
CREATE DATABASE IF NOT EXISTS card_dw;
USE card_dw;

-- ===================== ODS层 原始数据外表 =====================
DROP TABLE IF EXISTS ods_card_consume;
CREATE EXTERNAL TABLE ods_card_consume (
    stu_id STRING COMMENT '学生学号',
    consume_time STRING COMMENT '消费完整时间 yyyy-MM-dd HH:mm:ss',
    consume_place STRING COMMENT '消费地点',
    amount DECIMAL(5,2) COMMENT '消费金额(元)'
)
PARTITIONED BY (dt STRING COMMENT '消费日期，分区字段 yyyy-MM-dd')
ROW FORMAT DELIMITED
FIELDS TERMINATED BY ','
STORED AS TEXTFILE
LOCATION '/card/raw_data'
TBLPROPERTIES ("skip.header.line.count"="0", "comment"="一卡通原始采集数据ODS层");

-- 自动刷新HDFS分区元数据
MSCK REPAIR TABLE ods_card_consume;

-- ===================== DWD层 明细层 =====================
DROP TABLE IF EXISTS dwd_card_consume_detail;
CREATE TABLE dwd_card_consume_detail (
    stu_id STRING COMMENT '学生学号',
    consume_dt STRING COMMENT '消费日期 yyyy-MM-dd',
    consume_hour INT COMMENT '消费小时 0-23',
    consume_place STRING COMMENT '消费地点',
    amount DECIMAL(5,2) COMMENT '消费金额',
    consume_time_full STRING COMMENT '原始完整时间'
)
PARTITIONED BY (dt STRING)
STORED AS ORC
TBLPROPERTIES ("comment"="一卡通清洗后明细流水DWD层");

-- 修复后插入语句：原生hour函数兼容 7:1:00 短时间格式
INSERT OVERWRITE TABLE dwd_card_consume_detail PARTITION(dt)
SELECT
    stu_id,
    dt AS consume_dt,
    hour(consume_time) AS consume_hour,
    consume_place,
    amount,
    consume_time,
    dt
FROM ods_card_consume
WHERE amount > 0; -- 过滤负金额脏数据

-- ===================== DWS层 日汇总层 =====================
DROP TABLE IF EXISTS dws_card_day_summary;
CREATE TABLE dws_card_day_summary (
    stu_id STRING COMMENT '学生学号',
    consume_dt STRING COMMENT '消费日期',
    total_consume DECIMAL(8,2) COMMENT '当日总消费金额',
    consume_cnt BIGINT COMMENT '当日消费笔数',
    avg_amount DECIMAL(5,2) COMMENT '单笔平均消费',
    consume_level TINYINT COMMENT '消费档次 1节俭 2普通 3富裕'
)
PARTITIONED BY (dt STRING)
STORED AS ORC
TBLPROPERTIES ("comment"="学生每日消费汇总指标DWS层");

-- ===================== ADS层 月度报表层 =====================
DROP TABLE IF EXISTS ads_card_month_report;
CREATE TABLE ads_card_month_report (
    stu_id STRING COMMENT '学生学号',
    month STRING COMMENT '统计月份 yyyy-MM',
    month_total DECIMAL(8,2) COMMENT '月度总消费',
    month_order_cnt BIGINT COMMENT '月度总笔数',
    day_avg_consume DECIMAL(6,2) COMMENT '日均消费',
    canteen_cost DECIMAL(7,2) COMMENT '食堂总花费',
    shop_cost DECIMAL(7,2) COMMENT '超市总花费',
    water_dorm_cost DECIMAL(7,2) COMMENT '热水/门禁小额花费',
    consume_level TINYINT COMMENT '消费档次 1节俭 2普通 3富裕'
)
STORED AS ORC
TBLPROPERTIES ("comment"="学生月度消费报表ADS层");
