FROM ubuntu:20.04
ENV DEBIAN_FRONTEND=noninteractive
ENV TZ=Asia/Shanghai

# 替换阿里源，解决构建时域名解析失败
RUN sed -i 's/archive.ubuntu.com/mirrors.aliyun.com/g' /etc/apt/sources.list \
    && sed -i 's/security.ubuntu.com/mirrors.aliyun.com/g' /etc/apt/sources.list
RUN ln -snf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# 安装系统基础依赖工具
RUN apt update && apt install -y \
openssh-server openssh-client openssl \
python3 python3-pip vim net-tools wget tar sshpass

# 将docker/soft副本内所有离线包拷贝进镜像/usr/local
COPY soft/ /usr/local/
WORKDIR /usr/local

# 自动解压全部组件并重命名
# JDK8
RUN tar -zxvf OpenJDK8U-jdk_x64_linux*.tar.gz && rm -f OpenJDK8U-jdk_x64_linux*.tar.gz && mv jdk8u* jdk8
# Hadoop 3.3.5
RUN tar -zxvf hadoop-3.3.5.tar.gz && rm -f hadoop-3.3.5.tar.gz && mv hadoop-3.3.5 hadoop
# Zookeeper 3.8.1
RUN tar -zxvf apache-zookeeper-3.8.1*.tar.gz && rm -f apache-zookeeper-3.8.1*.tar.gz && mv apache-zookeeper-3.8.1-bin zookeeper
# Hive 3.1.3
RUN tar -zxvf apache-hive-3.1.3-bin.tar.gz && rm -f apache-hive-3.1.3-bin.tar.gz && mv apache-hive-3.1.3-bin hive
# HBase 2.4.18
#RUN tar -zxvf hbase-2.4.18-bin.tar.gz && rm -f hbase-2.4.18-bin.tar.gz && mv hbase-2.4.18-bin hbase
#RUN tar -zxvf hbase-2.6.6-bin.tar.gz && rm -f hbase-2.6.6-bin.tar.gz && mv hbase-2.6.6-bin hbase
RUN tar -zxvf hbase-2.6.6-bin.tar.gz && rm -f hbase-2.6.6-bin.tar.gz && mv hbase-2.6.6 hbase
# 全局配置所有大数据组件环境变量
ENV JAVA_HOME=/usr/local/jdk8
ENV HADOOP_HOME=/usr/local/hadoop
ENV ZOOKEEPER_HOME=/usr/local/zookeeper
ENV HIVE_HOME=/usr/local/hive
ENV HBASE_HOME=/usr/local/hbase
ENV PATH=$PATH:$JAVA_HOME/bin:$HADOOP_HOME/bin:$HADOOP_HOME/sbin:$ZOOKEEPER_HOME/bin:$HIVE_HOME/bin:$HBASE_HOME/bin

# 配置容器内SSH免密登录，单机集群通信
RUN mkdir -p /var/run/sshd && \
sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config && \
ssh-keygen -t rsa -P "" -f /root/.ssh/id_rsa && \
cat /root/.ssh/id_rsa.pub >> /root/.ssh/authorized_keys

# 创建和宿主机同名用户 zuohui，并授予大数据目录读写权限
RUN useradd -m zuohui && echo "zuohui:123456" | chpasswd && usermod -aG sudo zuohui
RUN chown -R zuohui:zuohui /usr/local/jdk8 /usr/local/hadoop /usr/local/zookeeper /usr/local/hive /usr/local/hbase

# 挂载宿主机完整业务项目目录，脚本/数据持久化
VOLUME /mnt/bigdata
# 切换业务普通用户
USER zuohui
WORKDIR /mnt/bigdata
# 容器后台常驻不退出
CMD ["tail","-f","/dev/null"]
