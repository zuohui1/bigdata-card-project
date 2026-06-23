#!/bin/bash
# card_data_gen.sh 分层一卡通消费数据，分为富裕/普通/节俭三类学生，拉开消费差距
DATA_FILE=/home/zuohui/bigdata_card/data/card_consume_data.csv
# 清空旧文件
> $DATA_FILE

# 学生分层规则
# 学号2301000~2301099 富裕学生 100人
# 学号2301100~2301399 普通学生 300人
# 学号2301400~2301499 节俭学生 100人

# 循环生成15000条消费流水
for i in {1..15000}
do
    # 随机学号 2301000 ~ 2301499
    stu_id=$((2301000+$RANDOM%500))
    # 判断学生消费档次
    if [ $stu_id -le 2301099 ];then
        level="rich"
    elif [ $stu_id -le 2301399 ];then
        level="normal"
    else
        level="poor"
    fi

    # 消费时段 6点 ~ 21点
    hour=$((6 + RANDOM%16))
    min=$((RANDOM%60))
    # 消费地点数组
    place_arr=("食堂一楼" "食堂二楼" "校园超市" "热水机" "宿舍门禁")
    place=${place_arr[$RANDOM%5]}

    # 根据地点+学生档次生成差异化金额
    case $place in
        "热水机"|"宿舍门禁")
            # 小额设备统一 0.5~3元，所有人无差别
            r=$RANDOM
            amount=$(echo "scale=2; ($r % 26) * 0.1 + 0.50" | bc)
            ;;
        "食堂一楼"|"食堂二楼")
            r=$RANDOM
            base=$(echo "$r % 25 + 8" | bc)
            case $level in
                "rich")
                    # 富裕上浮50% 8~32 → 12~48
                    amount=$(echo "scale=2; $base * 1.5" | bc)
                    ;;
                "normal")
                    # 普通原生区间 8~32
                    amount=$(echo "scale=2; $base" | bc)
                    ;;
                "poor")
                    # 节俭下浮40% 最低不低于5元
                    temp=$(echo "scale=2; $base * 0.6" | bc)
                    if (( $(echo "$temp < 5" | bc -l) ));then
                        temp=5.00
                    fi
                    amount=$temp
                    ;;
            esac
            ;;
        "校园超市")
            r=$RANDOM
            base=$(echo "$r % 64 + 5" | bc)
            case $level in
                "rich")
                    # 富裕上浮80% 5~68 → 9~122
                    amount=$(echo "scale=2; $base * 1.8" | bc)
                    ;;
                "normal")
                    # 普通原生区间 5~68
                    amount=$(echo "scale=2; $base" | bc)
                    ;;
                "poor")
                    # 节俭下浮50%，最低2元
                    temp=$(echo "scale=2; $base * 0.5" | bc)
                    if (( $(echo "$temp < 2" | bc -l) ));then
                        temp=2.00
                    fi
                    amount=$temp
                    ;;
            esac
            ;;
    esac

    # ========== 核心修复：格式化金额，强制补前导0 ==========
    amount_fix=$(printf "%.2f" $amount)

    # 随机6月1~30日，日期自动补零规范格式
    day=$((1 + RANDOM%30))
    if [ $day -lt 10 ];then
        day="0$day"
    fi
    cur_date="2026-06-$day"

    # 写入CSV：管道iconv强制输出UTF-8，规避locale缺失警告
    echo "$stu_id,$cur_date $hour:$min:00,$place,$amount_fix" | iconv -c -t UTF-8 >> $DATA_FILE
done

echo "15000条分层一卡通消费数据生成完毕，文件路径：$DATA_FILE"
echo "学生分层：富裕100人 / 普通300人 / 节俭100人"
# 查看文件总行数
wc -l $DATA_FILE
