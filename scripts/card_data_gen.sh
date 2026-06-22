#!/bin/bash
# card_data_gen.sh 生成10000条一卡通模拟消费数据（分地点差异化金额，更贴合校园）
DATA_FILE=/home/zuohui/bigdata_card/data/card_consume_data.csv
# 清空旧文件
> $DATA_FILE
# 循环生成10000条数据
for i in {1..10000}
do
    # 学号范围 2301000 ~ 2301999，共1000名学生
    stu_id=$((2301000+$RANDOM%1000))
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
            r=$RANDOM
            amount=$(echo "scale=2; ($r % 14) + 9.00" | bc)
            ;;
        "校园超市")
            r=$RANDOM
            amount=$(echo "scale=2; ($r % 43) + 5.00" | bc)
            ;;
    esac

    cur_date=$(date +%Y-%m-%d)
    echo "$stu_id,$cur_date $hour:$min:00,$place,$amount" >> $DATA_FILE
done
echo "10000条一卡通数据生成完毕，文件路径：$DATA_FILE"
# 查看文件总行数
wc -l $DATA_FILE
