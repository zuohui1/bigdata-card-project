#!/bin/bash
# Hive3.1.3 一键部署 适配JDK8 + Hadoop3.3.5 + MySQL8 root/123456
DATE_SUFFIX=$(date +%Y%m%d_%H%M%S)
HIVE_TAR=/home/zuohui/soft/apache-hive-3.1.3-bin.tar.gz
HIVE_HOME=/usr/local/hive
MYSQL_USER=root
MYSQL_PWD=123456
MYSQL_DB=hive_metadata

mkdir -p /home/zuohui/soft

# 无压缩包自动国内镜像下载，双源容错
if [ ! -f "$HIVE_TAR" ];then
    echo "======================"
    echo "未检测到Hive3.1.3安装包，优先阿里云高速镜像下载"
    echo "======================"
    wget -c https://mirrors.aliyun.com/apache/hive/hive-3.1.3/apache-hive-3.1.3-bin.tar.gz -O "$HIVE_TAR"
    # 阿里云失败切换华为云
    if [ $? -ne 0 ];then
        echo "阿里云源连接失败，切换华为云镜像重试..."
        wget -c https://repo.huaweicloud.com/apache/hive/hive-3.1.3/apache-hive-3.1.3-bin.tar.gz -O "$HIVE_TAR"
    fi
    # 两次都失败则退出提示手动下载
    if [ $? -ne 0 ];then
        echo "两个国内镜像下载均失败，请浏览器复制链接手动下载，上传到 /home/zuohui/soft/"
        echo "下载链接：https://mirrors.aliyun.com/apache/hive/hive-3.1.3/apache-hive-3.1.3-bin.tar.gz"
        exit 1
    fi
fi

# 清理旧残留目录
sudo rm -rf "$HIVE_HOME" /usr/local/apache-hive-3.1.3-bin

# 解压、改名、赋权
echo "正在解压Hive..."
sudo tar -zxvf "$HIVE_TAR" -C /usr/local/
sudo mv /usr/local/apache-hive-3.1.3-bin "$HIVE_HOME"
sudo chown -R zuohui:zuohui "$HIVE_HOME"

# 写入全局环境变量（仅追加一次，无重复）
sudo cp /etc/profile /etc/profile.bak_${DATE_SUFFIX}
echo "# Hive3.1.3 ENV" | sudo tee -a /etc/profile
echo "export HIVE_HOME=$HIVE_HOME" | sudo tee -a /etc/profile
echo "export PATH=\$PATH:\$HIVE_HOME/bin" | sudo tee -a /etc/profile
source /etc/profile

# 拷贝MySQL驱动包到hive/lib（复用你soft里已有的驱动）
DRIVER_SRC=/home/zuohui/soft/mysql-connector-java-*.jar
cp $DRIVER_SRC $HIVE_HOME/lib/

# 生成hive-site.xml 元库核心配置
cp $HIVE_HOME/conf/hive-default.xml.template $HIVE_HOME/conf/hive-site.xml.bak_${DATE_SUFFIX}
cat > $HIVE_HOME/conf/hive-site.xml <<EOF
<?xml version="1.0" encoding="UTF-8" standalone="no"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>
<configuration>
    <!-- MySQL元数据库连接 -->
    <property>
        <name>javax.jdo.option.ConnectionURL</name>
        <value>jdbc:mysql://localhost:3306/${MYSQL_DB}?createDatabaseIfNotExist=true&amp;useSSL=false&amp;serverTimezone=UTC</value>
    </property>
    <property>
        <name>javax.jdo.option.ConnectionDriverName</name>
        <value>com.mysql.cj.jdbc.Driver</value>
    </property>
    <property>
        <name>javax.jdo.option.ConnectionUserName</name>
        <value>${MYSQL_USER}</value>
    </property>
    <property>
        <name>javax.jdo.option.ConnectionPassword</name>
        <value>${MYSQL_PWD}</value>
    </property>
    <!-- HDFS仓库路径 -->
    <property>
        <name>hive.metastore.warehouse.dir</name>
        <value>/hive/warehouse</value>
    </property>
    <!-- 关闭元库版本校验 -->
    <property>
        <name>hive.metastore.schema.verification</name>
        <value>false</value>
    </property>
</configuration>
EOF

# 消除SLF4J日志冲突警告
rm -f $HIVE_HOME/lib/log4j-slf4j-impl-*.jar

# 自动创建MySQL元数据库
echo "正在创建MySQL元数据库 ${MYSQL_DB}..."
mysql -u${MYSQL_USER} -p${MYSQL_PWD} -e "CREATE DATABASE IF NOT EXISTS ${MYSQL_DB} DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"

# 初始化Hive元数据表
echo "开始初始化Hive元库..."
schematool -dbType mysql -initSchema

# 部署完成提示
echo "======================================"
echo "✅ Hive3.1.3 一键部署全部完成"
echo "1. 进入Hive客户端命令：hive"
echo "2. 查看数据库：show databases;"
echo "3. 前置要求：Hadoop集群已正常启动(jps查看进程)"
echo "======================================"
echo "HIVE_HOME=$HIVE_HOME"
hive --version
