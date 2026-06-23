#!/bin/bash
# hadoop_install.sh Hadoop3.3.5一键部署（手动上传包，无自动下载），配置自动备份
DATE_SUFFIX=$(date +%Y%m%d_%H%M%S)
# 修改1：版本3.3.5，匹配你下载的压缩包
HADOOP_TAR=/home/zuohui/soft/hadoop-3.3.5.tar.gz
HADOOP_HOME=/usr/local/hadoop

# 创建软件存放目录
mkdir -p /home/zuohui/soft

# ========== 删除整个自动下载判断代码块 ==========

# 清理旧目录、解压安装
sudo rm -rf $HADOOP_HOME
sudo tar -zxvf $HADOOP_TAR -C /usr/local/
# 修改2：解压后文件夹为 hadoop-3.3.5
sudo mv /usr/local/hadoop-3.3.5 $HADOOP_HOME
# 赋予当前用户完整读写权限
sudo chown -R zuohui:zuohui $HADOOP_HOME

# 写入全局环境变量
sudo cp /etc/profile /etc/profile.bak_${DATE_SUFFIX}
echo "export HADOOP_HOME=$HADOOP_HOME" | sudo tee -a /etc/profile
echo "export PATH=\$PATH:\$HADOOP_HOME/bin:\$HADOOP_HOME/sbin" | sudo tee -a /etc/profile
source /etc/profile

# 1. core-site.xml 配置
cp $HADOOP_HOME/etc/hadoop/core-site.xml $HADOOP_HOME/etc/hadoop/core-site.xml.bak_${DATE_SUFFIX}
cat > $HADOOP_HOME/etc/hadoop/core-site.xml <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<configuration>
    <property>
        <name>fs.defaultFS</name>
        <value>hdfs://localhost:9000</value>
    </property>
    <property>
        <name>hadoop.tmp.dir</name>
        <value>$HADOOP_HOME/tmp</value>
    </property>
</configuration>
EOF

# 2. hdfs-site.xml 副本数1（单机）
cp $HADOOP_HOME/etc/hadoop/hdfs-site.xml $HADOOP_HOME/etc/hadoop/hdfs-site.xml.bak_${DATE_SUFFIX}
cat > $HADOOP_HOME/etc/hadoop/hdfs-site.xml <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<configuration>
    <property>
        <name>dfs.replication</name>
        <value>1</value>
    </property>
</configuration>
EOF

# 3. mapred-site.xml 启用YARN
cp $HADOOP_HOME/etc/hadoop/mapred-site.xml.template $HADOOP_HOME/etc/hadoop/mapred-site.xml.bak_${DATE_SUFFIX}
cp $HADOOP_HOME/etc/hadoop/mapred-site.xml.template $HADOOP_HOME/etc/hadoop/mapred-site.xml
sed -i '/<configuration>/a <property><name>mapreduce.framework.name</name><value>yarn</value></property>' $HADOOP_HOME/etc/hadoop/mapred-site.xml

# 4. yarn-site.xml 配置shuffle
cp $HADOOP_HOME/etc/hadoop/yarn-site.xml $HADOOP_HOME/etc/hadoop/yarn-site.xml.bak_${DATE_SUFFIX}
cat > $HADOOP_HOME/etc/hadoop/yarn-site.xml <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<configuration>
    <property>
        <name>yarn.nodemanager.aux-services</name>
        <value>mapreduce_shuffle</value>
    </property>
</configuration>
EOF

# 5. hadoop-env.sh 注入JAVA_HOME
sed -i "s|#export JAVA_HOME=|export JAVA_HOME=\$JAVA_HOME|" $HADOOP_HOME/etc/hadoop/hadoop-env.sh

# 6. 本机免密SSH（启动集群必备）
ssh-keygen -t rsa -P "" -f ~/.ssh/id_rsa
cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys

echo "======================================"
echo "Hadoop3.3.5部署完成，所有配置已自动备份"
echo "首次使用仅执行1次格式化：hdfs namenode -format"
echo "启动集群命令：start-dfs.sh && start-yarn.sh"
echo "======================================"
