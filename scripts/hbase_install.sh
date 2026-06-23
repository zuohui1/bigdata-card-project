#!/bin/bash
# hbase_install.sh HBase单机一键部署，依赖ZK+Hadoop，配置自动备份
DATE_SUFFIX=$(date +%Y%m%d_%H%M%S)
# 适配2.6.6版本安装包
HBASE_TAR=/home/zuohui/soft/hbase-2.6.6-bin.tar.gz
HBASE_HOME=/usr/local/hbase
ZK_HOME=/usr/local/zookeeper

# 1. 解压安装
sudo tar -zxvf $HBASE_TAR -C /usr/local/
sudo mv /usr/local/hbase-2.6.6 $HBASE_HOME
sudo chown -R zuohui:zuohui $HBASE_HOME

# 2. 备份原始配置文件
cp $HBASE_HOME/conf/hbase-site.xml $HBASE_HOME/conf/hbase-site.xml.bak_$DATE_SUFFIX
cp $HBASE_HOME/conf/hbase-env.sh $HBASE_HOME/conf/hbase-env.sh.bak_$DATE_SUFFIX

# 3. 配置hbase-env.sh JAVA_HOME、关闭内置ZK
# 修复：精准匹配注释JAVA_HOME整行替换，避免路径拼接错乱
sed -i 's|^# export JAVA_HOME=.*|export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64|' $HBASE_HOME/conf/hbase-env.sh
sed -i 's/# export HBASE_MANAGES_ZK=true/export HBASE_MANAGES_ZK=false/' $HBASE_HOME/conf/hbase-env.sh

# 4. 写入hbase-site.xml 对接外部ZK与HDFS
cat > $HBASE_HOME/conf/hbase-site.xml << EOF
<?xml version="1.0"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
<configuration>
    <property>
        <name>hbase.cluster.distributed</name>
        <value>true</value>
    </property>
    <property>
        <name>hbase.zookeeper.quorum</name>
        <value>127.0.0.1</value>
    </property>
    <property>
        <name>hbase.zookeeper.property.dataDir</name>
        <value>$ZK_HOME/data</value>
    </property>
    <property>
        <name>hbase.rootdir</name>
        <value>hdfs://127.0.0.1:9000/hbase</value>
    </property>
</configuration>
EOF

# 5. 单机regionserver配置
echo "127.0.0.1" > $HBASE_HOME/conf/regionservers

# 6.HDFS创建HBase根目录
hdfs dfs -mkdir -p /hbase

# 7.全局环境变量备份与写入（/etc/profile 登录shell）
sudo cp /etc/profile /etc/profile.bak_$DATE_SUFFIX
echo "export HBASE_HOME=$HBASE_HOME" | sudo tee -a /etc/profile
echo "export PATH=\$PATH:\$HBASE_HOME/bin" | sudo tee -a /etc/profile

# 新增：写入用户bashrc，图形终端/ssh子终端永久生效
cp ~/.bashrc ~/.bashrc.bak_$DATE_SUFFIX
echo "export HBASE_HOME=$HBASE_HOME" >> ~/.bashrc
echo "export PATH=\$PATH:\$HBASE_HOME/bin" >> ~/.bashrc

# 当场加载两套环境变量，当前终端立即生效
source /etc/profile
source ~/.bashrc

echo "====HBase 2.6.6部署完成，使用cluster_control.sh启停集群===="
