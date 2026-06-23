#!/bin/bash
# =================================================================
# 脚本名称: cluster_check.sh
# 汇报功能: 大数据一卡通系统集群一键巡检脚本
# =================================================================

LOG_FILE="/home/zuohui/bigdata_card/logs/cluster_check.log"
mkdir -p $(dirname $LOG_FILE)

echo "=================================================================" >> $LOG_FILE
echo "巡检开始时间: $(date '+%Y-%m-%d %H:%M:%S')" >> $LOG_FILE
echo "=================================================================" >> $LOG_FILE

# 定义高亮颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # 无颜色

log_and_print() {
    local status=$1
    local msg=$2
    if [ "$status" = "OK" ]; then
        echo -e "[${GREEN}SUCCESS${NC}] $msg"
        echo "[SUCCESS] $msg" >> $LOG_FILE
    else
        echo -e "[${RED}ERROR${NC}] $msg"
        echo "[ERROR] $msg" >> $LOG_FILE
    fi
}

echo "===== 开始执行集群健康状态巡检 ====="

# 1. 检查服务器磁盘与内存空间
echo "--- 1. 系统资源检查 ---"
disk_usage=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')
if [ $disk_usage -gt 85 ]; then
    log_and_print "ERR" "根分区磁盘使用率过高: ${disk_usage}% (阈值 85%)"
else
    log_and_print "OK" "根分区磁盘空间正常: ${disk_usage}%"
fi

mem_free=$(free -m | awk '/Mem:/ {print $4}')
if [ $mem_free -lt 500 ]; then
    log_and_print "ERR" "系统可用内存极低: ${mem_free} MB (低于 500MB)"
else
    log_and_print "OK" "系统内存充足，当前可用: ${mem_free} MB"
fi

# 2. 检查 Java (JPS) 核心进程
echo "--- 2. 大数据核心组件进程检查 ---"
jps_output=$(jps)

components=("NameNode" "DataNode" "NodeManager" "ResourceManager" "RunJar" "HMaster" "ThriftServer")
for comp in "${components[@]}"; do
    if echo "$jps_output" | grep -q "$comp"; then
        log_and_print "OK" "进程检查: $comp 正在运行"
    else
        # RunJar 通常代表 Hive MetaStore 或 HiveServer2
        if [ "$comp" = "RunJar" ]; then
            log_and_print "ERR" "进程检查: Hive 核心服务 (RunJar) 未启动！"
        else
            log_and_print "ERR" "进程检查: $comp 进程已挂掉！"
        fi
    fi
done

# 3. 检查基础数据库与服务端口
echo "--- 3. 服务网络端口检查 ---"
check_port() {
    local port=$1
    local name=$2
    if nc -z 127.0.0.1 $port &>/dev/null; then
        log_and_print "OK" "$name 服务端口 ($port) 监听正常"
    else
        log_and_print "ERR" "$name 服务端口 ($port) 无法连接！"
    fi
}

check_port 3306 "MySQL 关系型数据库"
check_port 9000 "HDFS RPC通信接口"
check_port 9090 "HBase Thrift 接口"

echo "巡检结束。详细日志已保存至: $LOG_FILE"
