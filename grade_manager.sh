#!/bin/bash

# ================= 配置区域 =================
SOURCE_FILE="data.csv"
DATA_FILE="grades.csv"

# 课程列表（根据您的 data.csv 定义）
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
COURSE_COUNT=${#COURSES[@]}
START_COL=3

# ================= 初始化 =================
if [ ! -f "$DATA_FILE" ]; then
    if [ -f "$SOURCE_FILE" ]; then
        cp "$SOURCE_FILE" "$DATA_FILE"
    else
        header="学号,姓名"
        for course in "${COURSES[@]}"; do header="$header,$course"; done
        echo "$header" > "$DATA_FILE"
    fi
fi

# ================= 核心函数 (AWK) =================
# 用于成绩转换和计算的 AWK 脚本
AWK_CALC_SCRIPT='
function to_score(str) {
    gsub(/^[ \t]+|[ \t]+$/, "", str);
    if (str ~ /^[0-9.]/) return str + 0;
    if (str ~ /^优秀|^优/) return 95;
    if (str ~ /^良好|^良/) return 85;
    if (str ~ /^中等|^中/) return 75;
    if (str ~ /^及格|^及/) return 65;
    if (str ~ /^不及格/) return 0;
    return 0;
}
function calc_row(start_col, count) {
    sum = 0; valid_n = 0;
    for(i=0; i<count; i++) {
        val = $(start_col + i);
        if (val != "") { sum += to_score(val); valid_n++; }
    }
    avg = (valid_n > 0) ? sum / valid_n : 0;
    return sum "," avg;
}
'

# ================= 功能模块 =================

check_id() { grep -q "^$1," "$DATA_FILE"; }

add_record() {
    echo "--- 添加新学生 ---"
    read -p "请输入学号: " id
    if check_id "$id"; then echo "❌ 学号已存在！"; return; fi
    read -p "请输入姓名: " name
    record="$id,$name"; for ((i=0; i<COURSE_COUNT; i++)); do record="$record,"; done
    echo "$record" >> "$DATA_FILE"
    echo "✅ 添加成功。"
}

delete_record() {
    read -p "请输入要删除的学号: " id
    if ! check_id "$id"; then echo "❌ 学号不存在！"; return; fi
    grep -v "^$id," "$DATA_FILE" > "${DATA_FILE}.tmp" && mv "${DATA_FILE}.tmp" "$DATA_FILE"
    echo "✅ 删除成功。"
}

modify_record() {
    read -p "请输入学号: " id
    if ! check_id "$id"; then echo "❌ 学号不存在！"; return; fi
    read -p "请输入课程关键词 (如 高数): " key
    target_col=-1
    for ((i=0; i<COURSE_COUNT; i++)); do
        if [[ "${COURSES[$i]}" == *"$key"* ]]; then
            target_col=$((START_COL + i)); target_name="${COURSES[$i]}"; break
        fi
    done
    if [ $target_col -eq -1 ]; then echo "❌ 未找到课程"; return; fi
    read -p "请输入 [$target_name] 的新成绩: " score
    awk -v id="$id" -v col="$target_col" -v val="$score" 'BEGIN {FS=","; OFS=","} $1 == id { $col = val } { print $0 }' "$DATA_FILE" > "${DATA_FILE}.tmp" && mv "${DATA_FILE}.tmp" "$DATA_FILE"
    echo "✅ 修改成功。"
}

query_record() {
    read -p "请输入学号 (输入 'all' 显示所有): " q_id
    printf "%-12s %-10s %-8s %-8s\n" "学号" "姓名" "总分" "平均分"
    echo "----------------------------------------"
    awk -v q="$q_id" -v start="$START_COL" -v count="$COURSE_COUNT" "
    $AWK_CALC_SCRIPT
    BEGIN {FS=\",\"; OFS=\",\"}
    NR > 1 {
        if (q == \"all\" || \$1 == q) {
            res = calc_row(start, count); split(res, arr, \",\");
            printf \"%-12s %-10s %-8.1f %-8.2f\n\", \$1, \$2, arr[1], arr[2];
        }
    }
    " "$DATA_FILE"
}

sort_records() {
    echo "1) 按总分降序 (显示所有学生)"
    echo "2) 按特定课程降序 (显示所有学生)"
    read -p "选择: " opt
    
    if [ "$opt" == "1" ]; then
        echo "📊 正在按 [总分] 排序显示所有学生..."
        printf "%-12s %-10s %-8s %-8s\n" "学号" "姓名" "总分" "平均分"
        echo "----------------------------------------"
        # 1.计算总分 2.排序 3.格式化输出 (去除了 head 限制)
        awk -v start="$START_COL" -v count="$COURSE_COUNT" "
        $AWK_CALC_SCRIPT
        BEGIN {FS=\",\"; OFS=\",\"}
        NR > 1 {
            res = calc_row(start, count); split(res, arr, \",\");
            print arr[1] \",\" arr[2] \",\" \$0; 
        }
        " "$DATA_FILE" | sort -t, -k1nr | \
        awk -F, '{printf "%-12s %-10s %-8.1f %-8.2f\n", $3, $4, $1, $2}'
        
    elif [ "$opt" == "2" ]; then
        read -p "输入课程关键词: " key
        col_idx=-1
        for ((i=0; i<COURSE_COUNT; i++)); do
            if [[ "${COURSES[$i]}" == *"$key"* ]]; then
                col_idx=$((START_COL + i)); break
            fi
        done
        if [ $col_idx -eq -1 ]; then echo "❌ 课程未找到"; return; fi
        
        echo "📊 正在按 [${COURSES[$((col_idx-START_COL)) ]}] 排序显示所有学生..."
        printf "%-12s %-10s %-8s\n" "学号" "姓名" "成绩"
        echo "----------------------------------------"
        # 排序并输出所有行
        awk -F, 'NR>1 {print $0}' "$DATA_FILE" | \
        sort -t, -k"${col_idx}" -Vr | \
        awk -F, -v c="$col_idx" '{printf "%-12s %-10s %s\n", $1, $2, $c}'
    fi
}

# ================= 主菜单 =================
while true; do
    echo
    echo "=== 🎓 成绩管理系统 (显示全部排名版) ==="
    echo "1. 添加学生  2. 删除学生  3. 修改成绩"
    echo "4. 查询成绩  5. 排序排行榜  6. 退出"
    read -p "请选择: " choice
    case "$choice" in
        1) add_record ;; 2) delete_record ;; 3) modify_record ;;
        4) query_record ;; 5) sort_records ;; 6) exit 0 ;;
        *) echo "无效输入" ;;
    esac
done