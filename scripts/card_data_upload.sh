#!/bin/bash
# 按消费日期拆分CSV，Hive标准dt分区上传HDFS
HDFS_HOME=/usr/local/hadoop
LOCAL_DATA=/home/zuohui/bigdata_card/data/card_consume_data.csv
TMP=/tmp/card_split_data

# 重建临时文件夹
rm -rf ${TMP}
mkdir -p ${TMP}

# awk用-v接收shell临时目录变量，拆分每日文件
awk -F',' -v tmp_path="${TMP}" '
{
    day = substr($2, 1, 10);
    print $0 >> tmp_path "/" day ".csv";
}
' ${LOCAL_DATA}

# 遍历拆分后的每日文件上传
for day_file in ${TMP}/*.csv
do
    # 提取日期 2026-06-01
    day_name=$(basename ${day_file} .csv)
    hdfs_dir=/card/raw_data/dt=${day_name}
    # 创建HDFS分区目录
    ${HDFS_HOME}/bin/hdfs dfs -mkdir -p ${hdfs_dir}
    # 强制上传覆盖
    ${HDFS_HOME}/bin/hdfs dfs -put -f ${day_file} ${hdfs_dir}/
    echo "✅ 上传完成：${day_name} -> ${hdfs_dir}"
done

# 删除本地临时拆分文件
rm -rf ${TMP}

echo -e "\n==== HDFS分区目录总览 ===="
${HDFS_HOME}/bin/hdfs dfs -ls /card/raw_data/
echo "全部月度数据按消费日期分区上传完毕"
