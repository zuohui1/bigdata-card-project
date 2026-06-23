#!/bin/bash
# Superset一键部署脚本 适配已有spark_venv，修复安装中断、SECRET_KEY安全报错
set -e
# 日志输出
LOG="./superset_install_$(date +%Y%m%d_%H%M).log"
exec > >(tee -a $LOG) 2>&1

echo "==================== 开始部署Apache Superset ===================="
echo "日志文件：$LOG"

# 1. 安装系统底层编译依赖（mysqlclient编译必备）
echo -e "\n【1/5】安装系统编译依赖"
sudo apt update -y
sudo apt install -y build-essential libssl-dev libffi-dev python3-dev python3-venv libsasl2-dev libldap2-dev libpq-dev pkg-config libmysqlclient-dev

# 2. 加载业务虚拟环境 spark_venv
echo -e "\n【2/5】激活spark_venv虚拟环境"
VENV="$HOME/spark_venv/bin/activate"
if [ ! -f $VENV ];then
    echo "错误：未找到spark_venv，请先创建该虚拟环境！"
    exit 1
fi
source $VENV
echo "当前Python路径：$(which python3)"

# 3. 清理旧缓存、卸载残缺包，避免上次Ctrl+C中断残留
echo -e "\n【3/5】清理损坏缓存与残缺旧包"
pip cache purge
pip uninstall -y apache-superset apache-superset-core mysqlclient happybase
pip install --upgrade pip setuptools wheel

# 4. 清华源无缓存完整重装（禁止中途Ctrl+C）
echo -e "\n【4/5】完整安装Superset依赖，请勿中途按Ctrl+C中断！预计10~20分钟"
pip install -i https://pypi.tuna.tsinghua.edu.cn/simple --no-cache-dir apache-superset mysqlclient happybase

# 5. 自动生成永久安全密钥配置文件，解决启动SECRET_KEY报错
echo -e "\n【5/5】初始化Superset配置与数据库"
SUP_CONF="$HOME/spark_venv/bin/superset_config.py"
RAND_KEY=$(openssl rand -base64 42)
cat > $SUP_CONF <<EOF
# 自动生成安全密钥
SECRET_KEY = "$RAND_KEY"
EOF
export FLASK_APP=superset
export SUPERSET_CONFIG_PATH=$SUP_CONF

# 初始化元数据库
superset db upgrade

# 创建管理员账号
superset fab create-admin \
    --username admin \
    --firstname Admin \
    --lastname User \
    --email admin@card.com \
    --password 123456

# 初始化权限
superset init

echo -e "\n==================== 部署全部完成 ===================="
echo "后台启动可视化命令："
echo "source ~/spark_venv/bin/activate && nohup superset run -h 0.0.0.0 -p 8088 --with-threads > superset_run.log 2>&1 &"
echo "访问地址：http://zh-pc:8088"
echo "登录账号：admin  密码：123456"
echo "MySQL业务库连接串：mysql+mysqldb://root:123456@127.0.0.1:3306/card_analysis"
