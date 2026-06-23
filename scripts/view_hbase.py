#!/usr/bin/env python3
import happybase

connection = happybase.Connection('127.0.0.1', port=9090)
table = connection.table('card_detail')

print("=== HBase card_detail 表数据 ===\n")
print(f"{'RowKey':<35} {'字段':<20} {'值':<30}")
print("-" * 85)

count = 0
for key, data in table.scan(limit=10):
    rowkey = key.decode('utf-8')
    for col, value in sorted(data.items()):
        col_name = col.decode('utf-8')
        try:
            # 尝试UTF-8解码
            val = value.decode('utf-8')
        except:
            # 如果解码失败，显示原始十六进制
            val = value.hex()
        
        if count == 0 or col_name.endswith(':stu_id'):
            print(f"{rowkey:<35} {col_name:<20} {val:<30}")
        else:
            print(f"{'':<35} {col_name:<20} {val:<30}")
    count += 1
    if count > 0:
        print("-" * 85)

print(f"\n总共显示 {count} 条记录")
connection.close()
