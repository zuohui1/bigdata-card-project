#!/bin/bash
# cluster_control.sh 修复ZK时序+HMaster闪退+进程关不干净
ZK_HOME="/usr/local/zookeeper"
HBASE_HOME="/usr/local/hbase"
HIVE_HOME="/usr/local/hive"
LOG_DIR="/home/zuohui/bigdata_card/logs"

mkdir -p "$LOG_DIR"

# 全局强制清理集群Java进程
kill_all_cluster_java() {
    pkill -f "hive --service metastore" 2>/dev/null
    sleep 1
    ps -ef | grep RunJar | grep -v grep | awk '{print $2}' | xargs kill -9 2>/dev/null
    ps -ef | grep -E "HMaster|HRegionServer" | grep -v grep | awk '{print $2}' | xargs kill -9 2>/dev/null
    sleep 2
}

# 等待ZK 2181端口完全监听
wait_zk_ready() {
    echo "等待Zookeeper 2181端口就绪..."
    while ! ss -lntp | grep ":2181" > /dev/null; do
        sleep 1
    done
    echo "Zookeeper 连接就绪！"
}

case "$1" in
start)
    echo "===== 前置：清理所有集群残留进程 ====="
    kill_all_cluster_java

    echo "===== 1. 启动 Zookeeper ====="
    "$ZK_HOME/bin/zkServer.sh" start
    # 循环等待ZK端口，确保连接可用
    wait_zk_ready

    echo "===== 2. 启动 HBase ====="
    "$HBASE_HOME/bin/start-hbase.sh"
    sleep 4

    echo "===== 3. 后台启动 Hive Metastore ====="
    nohup "$HIVE_HOME/bin/hive" --service metastore > "$LOG_DIR/hive_meta.log" 2>&1 &
    META_PID=$!
    echo "Metastore 进程PID: ${META_PID}"
    sleep 8

    echo -e "\n===== 集群启动完成，当前JPS进程 ====="
    jps
    ;;

stop)
    echo "===== 1. 优雅关闭 Hive Metastore ====="
    pkill -f "hive --service metastore" 2>/dev/null
    sleep 2

    echo "===== 2. 优雅关闭 HBase ====="
    "$HBASE_HOME/bin/stop-hbase.sh"
    sleep 3
    # 兜底强杀残留HBase进程
    kill_all_cluster_java

    echo "===== 3. 关闭 Zookeeper ====="
    "$ZK_HOME/bin/zkServer.sh" stop
    sleep 1

    echo -e "\n===== 集群全部停止，当前JPS进程 ====="
    jps
    ;;

status)
    echo "===== JPS全部进程 ====="
    jps
    echo -e "\n===== Hive Metastore进程校验 ====="
    ps -ef | grep -v grep | grep "hive --service metastore"
    echo -e "\n===== Metastore 9083端口监听 ====="
    ss -lntp | grep 9083
    ;;

restart)
    echo "===== 执行集群完整重启 ====="
    bash "$0" stop
    sleep 4
    bash "$0" start
    ;;

*)
    echo "参数错误！可用命令："
    echo "bash cluster_control.sh start    启动集群"
    echo "bash cluster_control.sh stop     停止集群"
    echo "bash cluster_control.sh status   查看状态"
    echo "bash cluster_control.sh restart  重启集群"
    exit 1
    ;;
esac
