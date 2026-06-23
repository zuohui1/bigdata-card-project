from pyspark.sql import SparkSession
from pyspark.sql.functions import col, concat_ws, unix_timestamp

# 1. 初始化 Spark 会话
spark = SparkSession.builder \
    .appName("CardDetailArchiveTask") \
    .getOrCreate()

print("===== [HBase归档] 开始读取 HDFS 消费明细数据... =====")

# 2. 读取 HDFS 原始无表头明细 CSV
raw_df = spark.read \
    .option("header", "false") \
    .option("inferSchema", "true") \
    .csv("hdfs://zh-pc:9000/card_data/raw/card_consume/card_consume_data.csv")

# 3. 规范化列名
detail_df = raw_df.withColumnsRenamed({
    "_c0": "stu_id",
    "_c1": "consume_time",
    "_c2": "place",
    "_c3": "amount"
})

# 4. 【核心亮点】构造唯一的 RowKey: 学号 + 下划线 + 时间戳字符串
# 使用 unix_timestamp 将时间转为数字戳，防止字符串中带空格或特殊字符导致 RowKey 异常
archive_df = detail_df.withColumn(
    "rowkey", 
    concat_ws("_", col("stu_id"), unix_timestamp(col("consume_time")))
)

# 5. 分布式写入 HBase 明细表（不做任何 groupBy 聚合）
def write_detail_to_hbase(partition):
    try:
        import happybase
        # 建立连接
        connection = happybase.Connection('127.0.0.1', port=9090)
        connection.open()
        
        table_name = 'canteen_consume_detail'
        
        # 自动幂等建表：检查明细归档表是否存在
        existing_tables = connection.tables()
        if table_name.encode() not in existing_tables and table_name.strip().encode() not in existing_tables:
            print(f"ℹ️ 检测到 HBase 中不存在明细归档表 [{table_name}]，正在自动创建...")
            connection.create_table(
                table_name,
                {'cf': dict()} # 使用标准明细列族 'cf' (Column Family)
            )
            print(f"🎉 明细归档表 [{table_name}] 创建成功！")

        table = connection.table(table_name)
        
        # 批量写入每条消费流水明细
        with table.batch(batch_size=500) as b:
            for row in partition:
                row_key = str(row['rowkey']).encode()
                b.put(row_key, {
                    b'cf:stu_id': str(row['stu_id']).encode(),
                    b'cf:consume_time': str(row['consume_time']).encode(),
                    b'cf:place': str(row['place']).encode(),
                    b'cf:amount': str(row['amount']).encode()
                })
        connection.close()
    except Exception as e:
        print(f"❌ HBase 明细归档写入失败: {e}")

print("===== [HBase归档] 正在批量写入 HBase 明细归档表... =====")
archive_df.rdd.foreachPartition(write_detail_to_hbase)
print("【✔】HBase 海量明细历史数据冷归档入库完成！")

# 关闭 Spark 会话
spark.stop()
