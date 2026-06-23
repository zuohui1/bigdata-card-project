#!/bin/bash
# Spark3.5.8 清华镜像一键安装脚本（页面存在版本，适配Hadoop3+HBase2.6.6）
echo "===== 开始高速安装Spark 3.5.8（清华镜像） ====="
cd /usr/local

# 1. 清华镜像有效下载地址（页面可见spark-3.5.8文件夹）
sudo wget https://mirrors.tuna.tsinghua.edu.cn/apache/spark/spark-3.5.8/spark-3.5.8-bin-hadoop3.tgz

# 2. 解压 + 软链接统一路径/usr/local/spark
sudo tar -zxvf spark-3.5.8-bin-hadoop3.tgz
sudo rm -rf spark
sudo ln -s spark-3.5.8-bin-hadoop3 spark

# 3. 赋权解决jars目录写入权限不足
sudo chown -R zuohui:zuohui /usr/local/spark*

# 4. 脚本内固定SPARK_HOME，规避子shell变量失效
SPARK_HOME=/usr/local/spark

# 5. 写入全局环境变量
echo "# Spark 3.5.8 清华镜像环境变量" >> ~/.bashrc
echo "export SPARK_HOME=/usr/local/spark" >> ~/.bashrc
echo "export PATH=\$PATH:\$SPARK_HOME/bin:\$SPARK_HOME/sbin" >> ~/.bashrc

# 6. 进入jars下载MySQL驱动
cd $SPARK_HOME/jars
wget https://repo1.maven.org/maven2/mysql/mysql-connector-java/8.0.30/mysql-connector-java-8.0.30.jar

# 7. 拷贝HBase依赖包到Spark jars
cp /usr/local/hbase/lib/hbase-client-2.6.6.jar $SPARK_HOME/jars/
cp /usr/local/hbase/lib/hbase-server-2.6.6.jar $SPARK_HOME/jars/
cp /usr/local/hbase/lib/hbase-common-2.6.6.jar $SPARK_HOME/jars/
cp /usr/local/hbase/lib/hbase-protocol-2.6.6.jar $SPARK_HOME/jars/

# 8. 刷新当前终端环境
source ~/.bashrc

echo "===== Spark3.5.8安装完成！验证命令：spark-submit --version ====="
