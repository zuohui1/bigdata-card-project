#!/bin/bash
# 一卡通Spark同步与归档任务流程控制
SPARK_HOME=/usr/local/spark
MYSQL_JAR=${SPARK_HOME}/jars/mysql-connector-java-8.0.30.jar
VENV_PYTHON=/home/zuohui/spark_venv/bin/python

# 【核心修改】定义两个阶段的任务脚本路径
ARCHIVE_SCRIPT=/home/zuohui/bigdata_card/spark_job/card_detail_archive.py
CALC_SCRIPT=/home/zuohui/bigdata_card/spark_job/card_calc.py

# 校验前置文件和环境是否存在
if [ ! -f "${MYSQL_JAR}" ];then
    echo "错误：MySQL驱动jar不存在 ${MYSQL_JAR}"
    exit 1
fi
if [ ! -f "${ARCHIVE_SCRIPT}" ];then
    echo "错误：HBase归档任务脚本不存在 ${ARCHIVE_SCRIPT}"
    exit 1
fi
if [ ! -f "${CALC_SCRIPT}" ];then
    echo "错误：Spark计算任务脚本不存在 ${CALC_SCRIPT}"
    exit 1
fi
if [ ! -f "${VENV_PYTHON}" ];then
    echo "错误：虚拟环境Python不存在 ${VENV_PYTHON}"
    exit 1
fi

# 统一指定Python解释器
export PYSPARK_PYTHON=${VENV_PYTHON}
export PYSPARK_DRIVER_PYTHON=${VENV_PYTHON}

echo "========================================================================"
echo "🚀 环节一：开始执行 HBase 海量消费明细历史数据冷归档存储任务..."
echo "========================================================================"
# 归档任务不需要写MySQL，所以不需要带--jars
${SPARK_HOME}/bin/spark-submit --master local[*] ${ARCHIVE_SCRIPT}

# 判断归档结果，如果失败则熔断，不执行后续计算，保护下游数据
if [ $? -ne 0 ]; then
    echo "❌ 错误：HBase 明细数据归档失败，已熔断后续任务，请排查问题。"
    exit 1
fi

echo "========================================================================"
echo "🚀 环节二：开始执行 Spark 离线多维指标计算 & MySQL 聚合指标入库..."
echo "========================================================================"
# 计算与同步任务，需要带上MySQL驱动包
${SPARK_HOME}/bin/spark-submit --master local[*] --jars ${MYSQL_JAR} ${CALC_SCRIPT}

# 判断最终执行结果
if [ $? -eq 0 ];then
    echo "===== 🎉 所有任务执行成功，HBase明细已归档，MySQL指标已落盘！ ====="
else
    echo "===== ❌ 错误：Spark核心计算指标同步任务执行失败，请查看上方日志 ====="
    exit 1
fi
