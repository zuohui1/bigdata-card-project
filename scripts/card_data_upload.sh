#!/bin/bash
# card_data_upload.sh 一卡通数据按日期分区上传HDFS
HDFS_HOME=/usr/local/hadoop
CUR_DATE=$(date +%Y-%m-%d)
HDFS_PATH=/card/raw_data/$CUR_DATE
LOCAL_DATA_PATH=/home/zuohui/bigdata_card/data/card_consume_data.csv
# 创建HDFS分区目录
$HDFS_HOME/bin/hdfs dfs -mkdir -p $HDFS_PATH
# 上传本地CSV文件
$HDFS_HOME/bin/hdfs dfs -put $LOCAL_DATA_PATH $HDFS_PATH
# 校验上传文件
echo "HDFS分区目录文件列表："
$HDFS_HOME/bin/hdfs dfs -ls $HDFS_PATH
echo "当日一卡通数据已按天分区上传HDFS完成"
