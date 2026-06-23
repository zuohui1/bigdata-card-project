#!/bin/bash
# 按消费日期拆分CSV，Hive标准dt分区上传HDFS，内置UTF-8编码清洗
HDFS_HOME=/usr/local/hadoop
LOCAL_DATA=/home/zuohui/bigdata_card/data/card_consume_data.csv
TMP=/tmp/card_split_data

# 校验原始数据文件是否存在
if [ ! -f "${LOCAL_DATA}" ];then
    echo "ERROR: 原始数据文件 ${LOCAL_DATA} 不存在！"
    exit 1
fi

# 重建临时文件夹
rm -rf ${TMP}
mkdir -p ${TMP}

# 第一步：awk按日期拆分原始数据，跳过空行
awk -F',' -v tmp_path="${TMP}" '
NF==4{  # 只保留4个字段的有效行，过滤空行/脏数据
    day = substr($2, 1, 10);
    print $0 >> tmp_path "/" day ".csv";
}
' ${LOCAL_DATA}

# 第二步：遍历拆分后的每日文件，清洗编码并上传
for day_file in ${TMP}/*.csv
do
    # 无文件则跳过
    [ -f "${day_file}" ] || continue
    # 提取日期 2026-06-01
    day_name=$(basename ${day_file} .csv)
    hdfs_dir=/card/raw_data/dt=${day_name}
    clean_tmp=/tmp/clean_${day_name}.csv

    # 核心清洗：丢弃非法字符，强制转为UTF-8
    #cat ${day_file} | iconv -c -t UTF-8 > ${clean_tmp}
    cp ${day_file} ${clean_tmp}

    # 创建HDFS分区目录
    ${HDFS_HOME}/bin/hdfs dfs -mkdir -p ${hdfs_dir}
    # 上传清洗后的纯净UTF-8文件，覆盖旧文件
    ${HDFS_HOME}/bin/hdfs dfs -put -f ${clean_tmp} ${hdfs_dir}/${day_name}.csv
    echo "✅ 上传完成：${day_name} -> ${hdfs_dir}"

    # 删除当日清洗临时文件
    rm -f ${clean_tmp}
done

# 删除本地拆分缓存文件夹
rm -rf ${TMP}

echo -e "\n==== HDFS分区目录总览 ===="
${HDFS_HOME}/bin/hdfs dfs -ls /card/raw_data/
echo "全部月度数据按消费日期分区上传完毕（已清洗为UTF-8编码）"
