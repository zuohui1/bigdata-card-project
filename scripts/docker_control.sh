#!/bin/bash
# 一卡通大数据容器平台启停运维脚本
DOCKER_WORK=/home/zuohui/bigdata_card/docker

case $1 in
# 构建镜像+后台启动平台
start)
cd ${DOCKER_WORK}
echo "开始构建大数据平台镜像..."
docker-compose build
echo "启动card-big-env容器平台..."
docker-compose up -d
echo "平台启动完成，查看状态：./docker_control.sh status"
;;
# 停止并销毁容器
stop)
cd ${DOCKER_WORK}
docker-compose down
echo "容器平台已销毁"
;;
# 重启完整平台
restart)
${0} stop
${0} start
;;
# 实时查看容器运行日志
log)
docker logs -f card-big-env
;;
# 进入容器内部操作大数据任务
exec)
docker exec -it card-big-env bash
;;
# 查看容器挂载、运行状态
status)
echo "===== 容器运行状态 ====="
docker ps -a --filter "name=card-big-env"
echo -e "\n===== 目录挂载信息 ====="
docker inspect --format='{{json .Mounts}}' card-big-env | python3 -m json.tool
;;
# 本地项目备份（平台数据兜底）
backup)
cd /home/zuohui/bigdata_card
tar -zcvf ./backup/bigdata_platform_back_$(date +%Y%m%d_%H%M).tar.gz .
echo "项目全量备份已存入backup目录"
ls ./backup
;;
*)
echo "使用命令："
echo "  ./docker_control.sh start    构建并启动大数据容器平台"
echo "  ./docker_control.sh stop     停止销毁平台容器"
echo "  ./docker_control.sh restart  重启平台"
echo "  ./docker_control.sh exec     进入容器内部执行任务"
echo "  ./docker_control.sh status   查看容器挂载与运行状态"
echo "  ./docker_control.sh log      实时查看容器日志"
echo "  ./docker_control.sh backup   本地全项目备份"
;;
esac
