#!/bin/bash
# hbase_create_table.sh 创建一卡通原始消费明细表 card_detail
echo "================开始创建HBase一卡通明细表=================="
# 创建表，列族info
echo "create 'card_detail','info'" | hbase shell
echo "================建表完成=================="
echo "字段说明：info:stu_id 学生ID、info:consume_time 消费时间、info:place 消费场所、info:amount 消费金额、info:type 消费类型"
# 查询表列表校验
echo "list" | hbase shell
