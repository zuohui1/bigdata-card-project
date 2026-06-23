#!/bin/bash
# =================================================================
# 脚本名称: cluster_backup.sh
# 汇报功能: 自动化备份 MySQL 业务库与 HDFS 原始增量数据
# =================================================================

# 基础路径配置
BACKUP_DIR="/home/zuohui/bigdata_card/backup/mysql"
LOG_FILE="/home/zuohui/bigdata_card/logs/cluster_backup.log"
DATE_STR=$(date '+%Y%m%d')

mkdir -p $BACKUP_DIR
mkdir -p $(dirname $LOG_FILE)

echo "=== 备份任务开始: $(date '+%Y-%m-%d %H:%M:%S') ===" >> $LOG_FILE

# 1. 备份 MySQL card_analysis 库
echo "[1/2] 正在备份 MySQL 数据库..." | tee -a $LOG_FILE
MYSQL_USER="root"
MYSQL_PASS="123456"
MYSQL_DB="card_analysis"
SQL_FILE="${BACKUP_DIR}/${MYSQL_DB}_backup_${DATE_STR}.sql"

# 执行备份
mysqldump -u${MYSQL_USER} -p${MYSQL_PASS} ${MYSQL_DB} > ${SQL_FILE} 2>>$LOG_FILE

if [ $? -eq 0 ]; then
    # 压缩备份文件节省空间
    tar -czf ${SQL_FILE}.tar.gz -C ${BACKUP_DIR} $(basename ${SQL_FILE}) --remove-files
    echo "SUCCESS: MySQL 备份成功，文件名为: ${SQL_FILE}.tar.gz" | tee -a $LOG_FILE
else
    echo "ERROR: MySQL 备份失败，请检查上方或系统错误日志！" | tee -a $LOG_FILE
fi

# 2. 备份 HDFS 上的消费数据
echo "[2/2] 正在备份 HDFS 原始数据集..." | tee -a $LOG_FILE
HDFS_SRC="/card_data/raw/card_consume/card_consume_data.csv"
HDFS_BAK_DIR="/card_data/backup/${DATE_STR}"

# 创建 HDFS 备份目录并复制
/usr/local/hadoop/bin/hdfs dfs -mkdir -p ${HDFS_BAK_DIR} 2>>$LOG_FILE
/usr/local/hadoop/bin/hdfs dfs -cp -f ${HDFS_SRC} ${HDFS_BAK_DIR}/ 2>>$LOG_FILE

if [ $? -eq 0 ]; then
    echo "SUCCESS: HDFS 数据备份成功，备份至: ${HDFS_BAK_DIR}" | tee -a $LOG_FILE
else
    echo "ERROR: HDFS 数据备份失败！" | tee -a $LOG_FILE
fi

# 3. 自动清理机制：保留最近 7 天的本地 MySQL 备份，防止磁盘撑爆
find ${BACKUP_DIR} -name "${MYSQL_DB}_backup_*.sql.tar.gz" -mtime +7 -exec rm -f {} \;
echo "过期备份清理完毕（仅保留7天内备份文件）" | tee -a $LOG_FILE
echo "=== 备份任务结束: $(date '+%Y-%m-%d %H:%M:%S') ===" >> $LOG_FILE
