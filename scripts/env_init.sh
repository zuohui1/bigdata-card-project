#!/bin/bash
# env_init.sh 系统初始化脚本 zuohui用户，修改配置自动备份
DATE_SUFFIX=$(date +%Y%m%d_%H%M%S)
# 1.关闭防火墙
sudo ufw disable
# 2.文件句柄优化，先备份limits.conf
sudo cp /etc/security/limits.conf /etc/security/limits.conf.bak_${DATE_SUFFIX}
echo "* soft nofile 65535" | sudo tee -a /etc/security/limits.conf
echo "* hard nofile 65535" | sudo tee -a /etc/security/limits.conf
# 3.时区同步
sudo timedatectl set-timezone Asia/Shanghai
# 4.SSH免密配置，备份ssh配置
cp ~/.ssh/config ~/.ssh/config.bak_${DATE_SUFFIX}
ssh-keygen -t rsa -N "" -f ~/.ssh/id_rsa
cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
# 5.项目目录权限
sudo chown -R zuohui:zuohui /home/zuohui/bigdata_card
echo "=====系统初始化完成，所有修改配置已自动备份===="
echo "备份文件后缀：$DATE_SUFFIX"
