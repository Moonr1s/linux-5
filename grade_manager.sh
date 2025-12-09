#!/bin/bash

# ================= 配置区域 =================
# 源数据文件 (必须与脚本在同一目录)
SOURCE_FILE="data.csv"
# 工作文件 (脚本实际操作的文件)
DATA_FILE="grades.csv"

# 定义所有课程名称（对应CSV第3列及之后的数据）
# 根据您提供的 data.csv 表头顺序整理
COURSES=(
    "e1" "e2" "e3" 
    "高等数学1-1" "高等数学1-2" "线性代数" "大学物理4-1" "信息技术导论" 
    "高级语言程序设计" "高级语言程序设计实验" "面向对象程序设计" "计算机组成原理" 
    "离散数学" "汇编语言程序设计" "汇编语言程序设计实验" "程序设计训练" 
    "计算机组成原理课程设计" "数字系统与逻辑设计" "数字系统与逻辑设计实验" 
    "JAVA语言程序设计" "计算机专业认知" "思想道德修养与法律基础" 
    "中国近现代史纲要" "马克思主义基本原理概论" 
    "毛泽东思想和中国特色社会主义理论体系概论（1）" "贵州省情" "体育1" 
    "大学生职业生涯规划" "军事理论及军事训练" "大学生心理健康"
)
# 课程总数
COURSE_COUNT=${#COURSES[@]}
# 成绩起始列号 (CSV中第1列是学号, 第2列是姓名, 成绩从第3列开始)
START_COL=3

# ================= 初始化 =================

# 检查并导入数据
if [ ! -f "$DATA_FILE" ]; then
    if [ -f "$SOURCE_FILE" ]; then
        echo "正在从 '$SOURCE_FILE' 导入数据..."
        cp "$SOURCE_FILE" "$DATA_FILE"
        echo "✅ 数据导入成功！"
    else
        echo "❌ 未找到 '$SOURCE_FILE'。正在创建空数据文件..."
        # 创建表头
        header="学号,姓名"
        for course in "${COURSES[@]}"; do header="$header,$course"; done
        echo "$header" > "$DATA_FILE"
    fi
fi

# ================= 核心函数 =================

# 1. 计算逻辑 (嵌入的 AWK 脚本)
# 用于将中文/特殊格式成绩转换为分数进行计算
AWK_CALC_SCRIPT='
function to_score(str) {
    # 去除首尾空格
    gsub(/^[ \t]+|[ \t]+$/, "", str);
    
    # 如果是纯数字或以数字开头 (如 85.5 或 54/65)
    if (str ~ /^[0-9.]/) {
        return str + 0; # 强制转换为数字
    }
    # 处理文字等级
    if (str ~ /^优秀|^优/) return 95;
    if (str ~ /^良好|^良/) return 85;
    if (str ~ /^中等|^中/) return 75;
    if (str ~ /^及格|^及/) return 65;
    if (str ~ /^不及格/) return 0;
    
    return 0; # 空值或其他情况记为0
}

function calc_row(start_col, count) {
    sum = 0;
    valid_n = 0;
    for(i=0; i<count; i++) {
        val = $(start_col + i);
        if (val != "") { # 只计算非空成绩
            sum += to_score(val);
            valid_n++;
        }
    }
    avg = (valid_n > 0) ? sum / valid_n : 0;
    return sum "," avg;
}
'

# 2. 检查学号是否存在
check_id() {
    grep -q "^$1," "$DATA_FILE"
}

# 3. 添加记录
add_record() {
    echo "--- 添加新学生 ---"
    read -p "请输入学号: " id
    if check_id "$id"; then echo "❌ 学号已存在！"; return; fi
    read -p "请输入姓名: " name
    
    # 构建一行数据，初始成绩留空
    record="$id,$name"
    for ((i=0; i<COURSE_COUNT; i++)); do record="$record,"; done
    
    echo "$record" >> "$DATA_FILE"
    echo "✅ 学生 $name (学号 $id) 已添加。请使用[修改]功能录入成绩。"
}

# 4. 删除记录
delete_record() {
    read -p "请输入要删除的学号: " id
    if ! check_id "$id"; then echo "❌ 学号不存在！"; return; fi
    
    # 暂存非匹配行
    grep -v "^$id," "$DATA_FILE" > "${DATA_FILE}.tmp" && mv "${DATA_FILE}.tmp" "$DATA_FILE"
    echo "✅ 删除成功。"
}

# 5. 修改成绩 (支持搜索课程名)
modify_record() {
    read -p "请输入学号: " id
    if ! check_id "$id"; then echo "❌ 学号不存在！"; return; fi
    
    echo "--- 课程列表 (部分) ---"
    echo "输入 '高数' 可匹配 '高等数学'，输入 'e1' 匹配 'e1'"
    read -p "请输入要修改的课程关键词: " key
    
    # 搜索课程对应的列号
    target_col=-1
    target_name=""
    for ((i=0; i<COURSE_COUNT; i++)); do
        if [[ "${COURSES[$i]}" == *"$key"* ]]; then
            target_col=$((START_COL + i))
            target_name="${COURSES[$i]}"
            break
        fi
    done
    
    if [ $target_col -eq -1 ]; then echo "❌ 未找到匹配的课程！"; return; fi
    
    read -p "请输入 [$target_name] 的新成绩: " score
    
    # 使用 awk 更新指定列
    awk -v id="$id" -v col="$target_col" -v val="$score" '
    BEGIN {FS=","; OFS=","}
    $1 == id { $col = val }
    { print $0 }
    ' "$DATA_FILE" > "${DATA_FILE}.tmp" && mv "${DATA_FILE}.tmp" "$DATA_FILE"
    
    echo "✅ 修改成功！"
}

# 6. 查询显示 (含总分平均分)
query_record() {
    read -p "请输入学号 (输入 'all' 显示所有): " q_id
    
    # 打印表头
    printf "%-12s %-10s %-8s %-8s\n" "学号" "姓名" "总分" "平均分"
    echo "----------------------------------------"
    
    # 处理数据
    awk -v q="$q_id" -v start="$START_COL" -v count="$COURSE_COUNT" "
    $AWK_CALC_SCRIPT
    BEGIN {FS=\",\"; OFS=\",\"}
    NR > 1 {
        if (q == \"all\" || \$1 == q) {
            res = calc_row(start, count);
            split(res, arr, \",\");
            printf \"%-12s %-10s %-8.1f %-8.2f\n\", \$1, \$2, arr[1], arr[2];
        }
    }
    " "$DATA_FILE"
}

# 7. 排序显示
sort_records() {
    echo "1) 按总分降序"
    echo "2) 按特定课程降序"
    read -p "选择: " opt
    
    if [ "$opt" == "1" ]; then
        echo "📊 正在按 总分 排序..."
        # 计算总分并添加为第一列，排序后去除
        awk -v start="$START_COL" -v count="$COURSE_COUNT" "
        $AWK_CALC_SCRIPT
        BEGIN {FS=\",\"; OFS=\",\"}
        NR > 1 {
            res = calc_row(start, count);
            split(res, arr, \",\");
            print arr[1], \$0; # 在行首加总分
        }
        " "$DATA_FILE" | sort -nr -k1 | cut -d' ' -f2- | head -n 20 | \
        awk -F, '{printf "%-12s %-10s (详细成绩略)\n", $1, $2}'
        
    elif [ "$opt" == "2" ]; then
        read -p "输入课程名关键词: " key
        # 找列号
        col_idx=-1
        for ((i=0; i<COURSE_COUNT; i++)); do
            if [[ "${COURSES[$i]}" == *"$key"* ]]; then
                col_idx=$((START_COL + i))
                break
            fi
        done
        
        if [ $col_idx -eq -1 ]; then echo "❌ 课程未找到"; return; fi
        
        echo "📊 正在按此课程成绩排序..."
        # 简单的文本/数字混合排序
        awk -F, -v c="$col_idx" 'NR>1 {print $0}' "$DATA_FILE" | \
        sort -t, -k"${col_idx}" -Vr | \
        awk -F, -v c="$col_idx" '{printf "%-12s %-10s 成绩: %s\n", $1, $2, $c}' | head -n 20
    fi
}

# ================= 主菜单 =================

while true; do
    echo
    echo "=== 🎓 全课程成绩管理系统 ==="
    echo "1. 添加学生"
    echo "2. 删除学生"
    echo "3. 修改成绩 (支持所有30门课)"
    echo "4. 查询成绩 (自动计算总分/平均分)"
    echo "5. 排序排行榜"
    echo "6. 退出"
    read -p "请选择: " choice
    
    case "$choice" in
        1) add_record ;;
        2) delete_record ;;
        3) modify_record ;;
        4) query_record ;;
        5) sort_records ;;
        6) exit 0 ;;
        *) echo "无效输入" ;;
    esac
done