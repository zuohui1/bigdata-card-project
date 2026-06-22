#!/bin/bash
# card_data_gen.sh 生成15000条6月月度一卡通消费数据（500名学生，分地点差异化金额）
DATA_FILE=/home/zuohui/bigdata_card/data/card_consume_data.csv
# 清空旧文件
> $DATA_FILE
# 循环生成15000条消费流水
for i in {1..15000}
do
    # 学号范围 2301000 ~ 2301499，共500名学生
    stu_id=$((2301000+$RANDOM%500))
    # 消费时段 6点 ~ 21点
    hour=$((6 + RANDOM%16))
    min=$((RANDOM%60))
    # 消费地点数组
    place_arr=("食堂一楼" "食堂二楼" "校园超市" "热水机" "宿舍门禁")
    place=${place_arr[$RANDOM%5]}

    # 根据地点生成对应合理金额
    case $place in
        "热水机"|"宿舍门禁")
            # 小额：0.50 ~ 3.00元
            r=$RANDOM
            amount=$(echo "scale=2; ($r % 26) * 0.1 + 0.50" | bc)
            ;;
        "食堂一楼"|"食堂二楼")
            # 正餐：
            r=$RANDOM
            amount=$(echo "scale=2; ($r % 14) + 8.00" | bc)
            ;;
        "校园超市")
            # 购物：
            r=$RANDOM
            amount=$(echo "scale=2; ($r % 43) + 5.00" | bc)
            ;;
    esac

    # 随机6月1~30日，日期自动补零规范格式
    day=$((1 + RANDOM%30))
    if [ $day -lt 10 ];then
        day="0$day"
    fi
    cur_date="2026-06-$day"

    echo "$stu_id,$cur_date $hour:$min:00,$place,$amount" >> $DATA_FILE
done
echo "15000条6月月度一卡通消费数据生成完毕，文件路径：$DATA_FILE"
# 查看文件总行数
wc -l $DATA_FILE
