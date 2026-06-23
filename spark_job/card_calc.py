from pyspark.sql import SparkSession
from pyspark.sql.functions import sum, count, avg, when, current_date, col

# 初始化Spark：加入 Hive 支持，以便直接读取 Hive 中的数仓表
spark = SparkSession.builder \
    .appName("CardConsumeTask") \
    .config("spark.sql.warehouse.dir", "hdfs://zh-pc:9000/user/hive/warehouse") \
    .enableHiveSupport() \
    .getOrCreate()

# ==================== 1. 读取并处理 HDFS 原始数据 ====================
print("===== 正在处理 HDFS 原始消费数据... =====")
raw_df = spark.read \
    .option("header", "false") \
    .option("inferSchema", "true") \
    .csv("hdfs://zh-pc:9000/card_data/raw/card_consume/card_consume_data.csv")

# 列重命名
raw_df = raw_df.withColumnsRenamed({
    "_c0": "stu_id",
    "_c1": "consume_time",
    "_c2": "place",
    "_c3": "amount"
})

# 1.1 先进行按学生分组聚合，算出总消费额 (total_consume)
agg_base_df = raw_df.groupBy("stu_id").agg(
    sum("amount").alias("total_consume"),
    count("*").alias("consume_count"),
    avg("amount").alias("avg_consume")
)

# 1.2 基于聚合后的总消费额判断消费等级，贴合 39.89~236.30 元的真实分布
agg_df = agg_base_df.withColumn(
    "consume_level",
    when(col("total_consume") < 100, 1)      # 低消费
    .when(col("total_consume") < 170, 2)     # 中消费
    .otherwise(3)                            # 高消费
).withColumn(
    "stat_date", 
    current_date()
)

# ==================== 2. 统一配置 MySQL 写入参数 ====================
mysql_url = "jdbc:mysql://127.0.0.1:3306/card_analysis?useSSL=false&serverTimezone=Asia/Shanghai&allowPublicKeyRetrieval=true"
mysql_prop = {"user":"root","password":"123456","driver":"com.mysql.cj.jdbc.Driver"}

# 写入原有聚合表（此时已包含完美分层的消费等级）
agg_df.write.mode("overwrite").jdbc(url=mysql_url, table="student_consume_level", properties=mysql_prop)
print("【1】MySQL 聚合指标表 [student_consume_level] 写入完成")

# 写入原始消费明细表（原数据）
raw_df.write.mode("overwrite").jdbc(url=mysql_url, table="ods_raw_consume_data", properties=mysql_prop)
print("【2】MySQL 原始明细表 [ods_raw_consume_data] 写入完成")


# ==================== 3. 读取 Hive 数仓表并写入 MySQL ====================
print("===== 正在从 Hive 数仓同步各层表至 MySQL... =====")
try:
    # 同步 DWD 明细层
    dwd_df = spark.sql("SELECT * FROM card_dw.dwd_card_consume_detail")
    dwd_df.write.mode("overwrite").jdbc(url=mysql_url, table="dwd_card_consume_detail", properties=mysql_prop)
    print("【3】MySQL DWD明细层 [dwd_card_consume_detail] 同步完成")

    # 同步 DWS 日汇总层
    dws_df = spark.sql("SELECT * FROM card_dw.dws_card_day_summary")
    dws_df.write.mode("overwrite").jdbc(url=mysql_url, table="dws_card_day_summary", properties=mysql_prop)
    print("【4】MySQL DWS日汇总层 [dws_card_day_summary] 同步完成")

    # 同步 ADS 月度报表层
    ads_df = spark.sql("SELECT * FROM card_dw.ads_card_month_report")
    ads_df.write.mode("overwrite").jdbc(url=mysql_url, table="ads_card_month_report", properties=mysql_prop)
    print("【5】MySQL ADS月报表层 [ads_card_month_report] 同步完成")

except Exception as e:
    print(f"❌ 读取 Hive 表失败，请确保 hive-site.xml 已放入 Spark 的 conf 目录。错误信息: {e}")


# ==================== 4. HBase 写入逻辑（带自动建表与容错处理） ====================
def write_to_hbase(partition):
    try:
        import happybase
        # 1. 建立连接
        connection = happybase.Connection('127.0.0.1', port=9090)
        connection.open()
        
        table_name = 'student_card_profile'
        
        # 2. 【核心修改】在分布式 Executor 节点中自动检测并幂等创建 HBase 表
        existing_tables = connection.tables()
        if table_name.encode() not in existing_tables and table_name.strip().encode() not in existing_tables:
            print(f"ℹ️ 检测到 HBase 中不存在表 [{table_name}]，正在自动创建...")
            # 创建表并定义列族 'info'
            connection.create_table(
                table_name,
                {'info': dict()}
            )
            print(f"🎉 HBase 表 [{table_name}] 自动创建并初始化成功！")

        # 3. 获取表对象并进行批量写入
        table = connection.table(table_name)
        with table.batch(batch_size=100) as b:
            for row in partition:
                # 构造 rowkey: 学号
                row_key = str(row['stu_id']).encode()
                b.put(row_key, {
                    b'info:total_consume': str(row['total_consume']).encode(),
                    b'info:consume_count': str(row['consume_count']).encode(),
                    b'info:avg_consume': str(row['avg_consume']).encode(),
                    b'info:consume_level': str(row['consume_level']).encode()
                })
        connection.close()
    except Exception as e:
        print(f"⚠️ HBase 自动建表或写入失败: {e}")

# 触发 HBase 写入
print("===== 正在尝试写入 HBase... =====")
agg_df.rdd.foreachPartition(write_to_hbase)
print("【6】HBase 异步特征轮廓全量写入尝试结束")

# 关闭 Spark 会话
spark.stop()
print("===== 所有数据同步任务全部结束！ =====")
