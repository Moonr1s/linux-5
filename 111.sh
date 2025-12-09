#!/bin/bash

# 数据文件：使用CSV格式存储 学号,姓名,数学,语文,英语
DATA_FILE="grades.csv"

# 初始化数据文件
if [ ! -f "$DATA_FILE" ]; then
    echo "学号,姓名,数学,语文,英语" > "$DATA_FILE"
    echo "数据文件 '$DATA_FILE' 已创建。"
fi

# --- 辅助函数 ---

# 计算总分和平均分 (输入: 成绩1, 成绩2, 成绩3)
calculate_scores() {
    local math=$1
    local chinese=$2
    local english=$3
    # 确保成绩是数字，否则视为0进行计算
    if ! [[ "$math" =~ ^[0-9]+$ ]]; then math=0; fi
    if ! [[ "$chinese" =~ ^[0-9]+$ ]]; then chinese=0; fi
    if ! [[ "$english" =~ ^[0-9]+$ ]]; then english=0; fi

    local total=$((math + chinese + english))
    # 使用 awk 进行浮点运算并保留两位小数
    local average=$(awk "BEGIN {printf \"%.2f\", $total / 3}")
    echo "$total,$average"
}

# 检查学号是否存在 (输入: 学号)
check_student_id() {
    # -q 抑制输出，只返回状态码
    grep -q "^$1," "$DATA_FILE"
    return $? # 0: 存在, 1: 不存在
}

# --- 主功能模块 ---

## 1. 添加成绩信息
add_record() {
    echo "--- 添加学生成绩 ---"
    read -p "请输入学号: " id
    if check_student_id "$id"; then
        echo "❌ 错误: 学号 $id 已存在！"
        return
    fi
    read -p "请输入姓名: " name
    read -p "请输入数学成绩: " math
    read -p "请输入语文成绩: " chinese
    read -p "请输入英语成绩: " english

    # 检查成绩是否为有效的非负整数
    if ! [[ "$math" =~ ^[0-9]+$ && "$chinese" =~ ^[0-9]+$ && "$english" =~ ^[0-9]+$ ]]; then
        echo "❌ 错误: 成绩必须是有效的非负整数！"
        return
    fi

    # 写入数据
    echo "$id,$name,$math,$chinese,$english" >> "$DATA_FILE"
    echo "✅ 记录已成功添加。"
}
\n
## 2. 删除成绩信息
delete_record() {
    echo "--- 删除学生成绩 ---"
    read -p "请输入要删除的学生的学号: " id
    if ! check_student_id "$id"; then
        echo "❌ 错误: 学号 $id 不存在！"
        return
    fi

    # 使用 grep -v 删除匹配行 (即保留不匹配的行)
    grep -v "^$id," "$DATA_FILE" > "$DATA_FILE.tmp"
    mv "$DATA_FILE.tmp" "$DATA_FILE"
    echo "✅ 学号 $id 的记录已删除。"
}
\n
## 3. 修改成绩信息
modify_record() {
    echo "--- 修改学生成绩 ---"
    read -p "请输入要修改的学生的学号: " id
    if ! check_student_id "$id"; then
        echo "❌ 错误: 学号 $id 不存在！"
        return
    fi

    # 查找当前信息
    current_info=$(grep "^$id," "$DATA_FILE")
    # 使用 IFS 读取旧值
    IFS=',' read -r old_id old_name old_math old_chinese old_english <<< "$current_info"
    echo "当前信息: 姓名=$old_name, 数学=$old_math, 语文=$old_chinese, 英语=$old_english"

    read -p "请输入新数学成绩 (留空则不修改): " new_math
    read -p "请输入新语文成绩 (留空则不修改): " new_chinese
    read -p "请输入新英语成绩 (留空则不修改): " new_english

    # 使用旧值或新输入的值 (参数扩展 ${param:-default})
    new_math=${new_math:-$old_math}
    new_chinese=${new_chinese:-$old_chinese}
    new_english=${new_english:-$old_english}

    # 检查新值是否为数字
    if ! [[ "$new_math" =~ ^[0-9]+$ && "$new_chinese" =~ ^[0-9]+$ && "$new_english" =~ ^[0-9]+$ ]]; then
        echo "❌ 错误: 成绩必须是有效的非负整数！"
        return
    fi

    # 构造新记录
    new_record="$id,$old_name,$new_math,$new_chinese,$new_english"

    # 使用 sed 进行替换整行 (c 命令)
    sed -i "/^$id,/c\\$new_record" "$DATA_FILE"
    echo "✅ 学号 $id 的记录已修改。"
}
\n
## 4. 查询/显示成绩 (含总分/平均分)
query_record() {
    echo "--- 查询学生信息 ---"
    read -p "请输入要查询的学生的学号 (或输入 'all' 显示所有): " query
    echo

    # 打印表头
    printf "%-10s %-10s %-8s %-8s %-8s %-8s %-8s\n" "学号" "姓名" "数学" "语文" "英语" "总分" "平均分"
    echo "------------------------------------------------------------------"

    # 根据查询条件过滤数据
    if [ "$query" = "all" ]; then
        data=$(tail -n +2 "$DATA_FILE") # 跳过表头
    elif check_student_id "$query"; then
        data=$(grep "^$query," "$DATA_FILE")
    else
        echo "❌ 未找到学号 $query 的记录。"
        return
    fi

    # 遍历并计算总分和平均分
    while IFS=',' read -r id name math chinese english; do
        if [[ -n "$id" ]]; then # 确保不是空行
            results=$(calculate_scores "$math" "$chinese" "$english")
            total=$(echo "$results" | cut -d',' -f1)
            average=$(echo "$results" | cut -d',' -f2)

            printf "%-10s %-10s %-8s %-8s %-8s %-8s %-8s\n" "$id" "$name" "$math" "$chinese" "$english" "$total" "$average"
        fi
    done <<< "$data"
}
\n
## 5. 排序显示
sort_records() {
    echo "--- 排序显示成绩 ---"
    echo "请选择排序方式:"
    echo "1) 按 数学 成绩降序"
    echo "2) 按 语文 成绩降序"
    echo "3) 按 英语 成绩降序"
    echo "4) 按 总分 降序"
    read -p "请输入选项 (1-4): " choice

    # 打印表头
    printf "\n%-10s %-10s %-8s %-8s %-8s %-8s %-8s\n" "学号" "姓名" "数学" "语文" "英语" "总分" "平均分"
    echo "------------------------------------------------------------------"

    # 准备排序数据 (将总分和平均分添加到每行开头)
    # temp_data 格式: 总分,平均分,学号,姓名,数学,语文,英语
    temp_data=$(tail -n +2 "$DATA_FILE" | while IFS=',' read -r id name math chinese english; do
        results=$(calculate_scores "$math" "$chinese" "$english")
        total=$(echo "$results" | cut -d',' -f1)
        average=$(echo "$results" | cut -d',' -f2)
        echo "$total,$average,$id,$name,$math,$chinese,$english"
    done)

    # 排序
    case "$choice" in
        1) # 按数学 (第5列) 降序
            sorted_data=$(echo "$temp_data" | sort -t',' -k5nr)
            ;;
        2) # 按语文 (第6列) 降序
            sorted_data=$(echo "$temp_data" | sort -t',' -k6nr)
            ;;
        3) # 按英语 (第7列) 降序
            sorted_data=$(echo "$temp_data" | sort -t',' -k7nr)
            ;;
        4) # 按总分 (第1列) 降序
            sorted_data=$(echo "$temp_data" | sort -t',' -k1nr)
            ;;
        *)
            echo "❌ 无效选项！"
            return
            ;;
    esac

    # 格式化输出排序后的数据
    echo "$sorted_data" | while IFS=',' read -r total average id name math chinese english; do
        printf "%-10s %-10s %-8s %-8s %-8s %-8s %-8s\n" "$id" "$name" "$math" "$chinese" "$english" "$total" "$average"
    done
}


# --- 主菜单和循环 ---

main_menu() {
    while true; do
        echo
        echo "====================================="
        echo "  🎓 简易学生成绩管理系统 (Bash) 🎓"
        echo "====================================="
        echo "1) ➕ 添加成绩信息"
        echo "2) ➖ 删除成绩信息"
        echo "3) ✏️ 修改成绩信息"
        echo "4) 🔍 查询/显示所有成绩 (含总分/平均分)"
        echo "5) 📊 按成绩/总分排序显示"
        echo "6) ❌ 退出系统"
        echo "-------------------------------------"
        read -p "请输入您的选择 (1-6): " choice

        case "$choice" in
            1) add_record ;;
            2) delete_record ;;
            3) modify_record ;;
            4) query_record ;;
            5) sort_records ;;
            6)
                echo "感谢使用，系统退出。"
                exit 0
                ;;
            *)
                echo "无效的选择，请重新输入！"
                ;;
        esac
    done
}

# 运行主菜单
main_menu