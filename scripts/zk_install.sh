#!/bin/bash
# zk_install.sh Zookeeper一键部署，自动下载+权限修复+配置自动备份
DATE_SUFFIX=$(date +%Y%m%d_%H%M%S)
ZK_TAR=/home/zuohui/soft/apache-zookeeper-3.8.1-bin.tar.gz
ZK_HOME=/usr/local/zookeeper

# 1. 自动创建软件存放目录soft
mkdir -p /home/zuohui/soft

# 2. 判断压缩包是否存在，不存在则从Apache官方下载
if [ ! -f $ZK_TAR ];then
    echo "======================================"
    echo "本地未检测到Zookeeper压缩包，开始Apache官方下载"
    echo "======================================"
    wget https://archive.apache.org/dist/zookeeper/zookeeper-3.8.1/apache-zookeeper-3.8.1-bin.tar.gz -O $ZK_TAR
    # 校验文件大小，小于10M判定为下载失败
    FILE_SIZE=$(du -m $ZK_TAR | awk '{print $1}')
    if [ $FILE_SIZE -lt 10 ];then
        echo "下载失败，文件损坏，删除无效文件退出脚本"
        rm -f $ZK_TAR
        exit 1
    fi
    echo "压缩包下载完成，路径：$ZK_TAR"
fi

# 3. 清理旧目录，解压安装
sudo rm -rf $ZK_HOME
sudo tar -zxvf $ZK_TAR -C /usr/local/
sudo mv /usr/local/apache-zookeeper-3.8.1-bin $ZK_HOME

# ========== 修复点：解压后第一时间修改目录归属 ==========
sudo chown -R zuohui:zuohui $ZK_HOME

# 4. 备份、生成配置文件（去掉sudo）
cp $ZK_HOME/conf/zoo_sample.cfg $ZK_HOME/conf/zoo.cfg.bak_${DATE_SUFFIX}
cp $ZK_HOME/conf/zoo_sample.cfg $ZK_HOME/conf/zoo.cfg
sed -i "s|dataDir=/tmp/zookeeper|dataDir=$ZK_HOME/data|" $ZK_HOME/conf/zoo.cfg

# 5. 创建数据、日志目录（去掉sudo）
mkdir -p $ZK_HOME/data
mkdir -p $ZK_HOME/logs

# 6. 配置全局环境变量
sudo cp /etc/profile /etc/profile.bak_${DATE_SUFFIX}
echo "export ZK_HOME=$ZK_HOME" | sudo tee -a /etc/profile
echo "export PATH=\$PATH:\$ZK_HOME/bin" | sudo tee -a /etc/profile
source /etc/profile

# 7. 启动Zookeeper
zkServer.sh start

echo "======================================"
echo "Zookeeper 3.8.1 部署脚本执行完毕"
echo "配置备份文件后缀：$DATE_SUFFIX"
echo "======================================"
echo "执行 zkServer.sh status 查看运行状态"
