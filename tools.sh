#!/bin/bash

# 服务器初始化脚本（适用于 Debian/Ubuntu 系统）
# 提供菜单选择功能，支持自定义用户名

# 注意：不在脚本开头使用 set -e，因为我们希望某个模块失败时不影响其他模块

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULES_DIR="$SCRIPT_DIR/modules"

# 检查是否以 root 权限运行
if [ "$EUID" -ne 0 ]; then 
    echo "请以 root 权限运行此脚本: sudo $0"
    exit 1
fi

# 检查 modules 目录是否存在
if [ ! -d "$MODULES_DIR" ]; then
    echo "错误: 找不到 modules 目录: $MODULES_DIR"
    exit 1
fi

# 执行模块函数
run_module() {
    local module_name="$1"
    local module_file="$MODULES_DIR/$module_name.sh"
    
    if [ ! -f "$module_file" ]; then
        echo "错误: 找不到模块文件: $module_file"
        return 1
    fi
    
    # 确保模块脚本可执行
    chmod +x "$module_file"
    
    # 读取用户名（如果文件存在），并传递给模块
    local user_file="$SCRIPT_DIR/.target_user"
    local target_user=""
    if [ -f "$user_file" ]; then
        target_user=$(cat "$user_file" | head -1)
    fi
    
    # 执行模块脚本（传递环境变量 TARGET_USER）
    if ! TARGET_USER="$target_user" bash "$module_file"; then
        return 1
    fi
    
    # 如果执行的是 create_user 模块，更新 TARGET_USER（从文件读取）
    if [ "$module_name" = "create_user" ] && [ -f "$user_file" ]; then
        TARGET_USER=$(cat "$user_file" | head -1)
    fi
    
    return 0
}

# 读取用户名
read_target_user() {
    local user_file="$SCRIPT_DIR/.target_user"
    if [ -f "$user_file" ]; then
        cat "$user_file" | head -1
    else
        echo "four"  # 默认用户名
    fi
}

# 显示菜单
show_menu() {
    clear
    echo "=========================================="
    echo "服务器初始化工具"
    echo "=========================================="
    echo ""
    TARGET_USER=$(read_target_user)
    echo "目标用户: $TARGET_USER (将在创建用户时设置或修改)"
    echo ""
    echo "请选择要执行的功能（可以多选，用空格分隔，例如: 1 2 3）:"
    echo ""
    echo "  [1] 创建用户并添加到 sudo 组"
    echo "  [2] 安装构建相关软件 (build-essential, git, curl, vim 等)"
    echo "  [3] 安装 cpupower 工具"
    echo "  [4] 设置 CPU 模式为 performance"
    echo "  [5] 安装 Redis (从官方仓库)"
    echo "  [6] 配置 SSH (仅允许密钥登录)"
    echo "  [7] 配置防火墙 (UFW)"
    echo "  [8] 安装 Golang"
    echo "  [9] 安装 Rust"
    echo "  [10] 安装 Node.js (使用 nvm)"
    echo "  [11] 安装 fail2ban (入侵防护)"
    echo "  [12] 配置系统内核参数优化 (BSC节点优化)"
    echo ""
    echo "  [A] 全部执行（按依赖顺序）"
    echo "  [Q] 退出"
    echo ""
}


# 解析用户选择
parse_selection() {
    local selection="$1"
    local selected_modules=()
    
    # 将选择转换为小写并去除多余空格
    selection=$(echo "$selection" | tr '[:upper:]' '[:lower:]' | tr -s ' ')
    
    # 处理全部执行
    if [[ "$selection" == *"a"* ]] || [[ "$selection" == *"all"* ]]; then
        selected_modules=("create_user" "install_build_tools" "install_cpupower" "set_cpu_performance" "install_redis" "configure_ssh" "configure_firewall" "install_golang" "install_rust" "install_node" "install_fail2ban")
        echo "${selected_modules[@]}"
        return 0
    fi
    
    # 解析数字选择
    for num in $selection; do
        case "$num" in
            1) selected_modules+=("create_user") ;;
            2) selected_modules+=("install_build_tools") ;;
            3) selected_modules+=("install_cpupower") ;;
            4) selected_modules+=("set_cpu_performance") ;;
            5) selected_modules+=("install_redis") ;;
            6) selected_modules+=("configure_ssh") ;;
            7) selected_modules+=("configure_firewall") ;;
            8) selected_modules+=("install_golang") ;;
            9) selected_modules+=("install_rust") ;;
            10) selected_modules+=("install_node") ;;
            11) selected_modules+=("install_fail2ban") ;;
            12) selected_modules+=("configure_sysctl") ;;
        esac
    done
    
    echo "${selected_modules[@]}"
}

# 按依赖顺序排序模块
sort_modules_by_dependencies() {
    local modules=("$@")
    local sorted=()
    local processed=()
    
    # 定义模块执行顺序（按依赖关系）
    local execution_order=("create_user" "install_build_tools" "install_cpupower" "set_cpu_performance" "install_redis" "configure_ssh" "configure_firewall" "install_golang" "install_rust" "install_node" "install_fail2ban" "configure_sysctl")
    
    # 定义依赖关系：key 是模块名，value 是其依赖的模块
    declare -A dependencies
    dependencies["set_cpu_performance"]="install_cpupower"
    dependencies["configure_ssh"]="create_user"
    
    # 按照预定义的执行顺序，只添加用户选择的模块
    for module in "${execution_order[@]}"; do
        # 检查该模块是否在用户选择中
        if [[ " ${modules[@]} " =~ " ${module} " ]]; then
            # 检查依赖是否满足
            local dep="${dependencies[$module]}"
            if [ -n "$dep" ] && [[ " ${modules[@]} " =~ " ${dep} " ]]; then
                # 如果依赖还未处理，先添加依赖
                if [[ ! " ${processed[@]} " =~ " ${dep} " ]]; then
                    sorted+=("$dep")
                    processed+=("$dep")
                fi
            fi
            # 添加当前模块
            if [[ ! " ${processed[@]} " =~ " ${module} " ]]; then
                sorted+=("$module")
                processed+=("$module")
            fi
        fi
    done
    
    # 添加未在预定义顺序中的模块（理论上不应该有）
    for module in "${modules[@]}"; do
        if [[ ! " ${processed[@]} " =~ " ${module} " ]]; then
            sorted+=("$module")
            processed+=("$module")
        fi
    done
    
    echo "${sorted[@]}"
}

# 执行选中的模块（按依赖顺序）
execute_modules() {
    local modules=("$@")
    
    if [ ${#modules[@]} -eq 0 ]; then
        echo "未选择任何功能"
        read -p "按回车键继续..."
        return
    fi
    
    # 按依赖顺序排序（只排序一次）
    local sorted_modules=($(sort_modules_by_dependencies "${modules[@]}"))
    
    echo ""
    echo "将按以下顺序执行（已考虑依赖关系）:"
    local index=1
    for module in "${sorted_modules[@]}"; do
        echo "  [$index] $module"
        ((index++))
    done
    echo ""
    read -p "确认执行? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "已取消"
        read -p "按回车键继续..."
        return
    fi
    
    echo ""
    echo "=========================================="
    echo "开始执行..."
    echo "=========================================="
    echo ""
    
    # 执行模块
    for module in "${sorted_modules[@]}"; do
        # 检查依赖是否满足
        case "$module" in
            "set_cpu_performance")
                # 检查是否安装了 cpupower（检查是否在当前执行列表中，或已安装）
                local has_cpupower=false
                if [[ " ${sorted_modules[@]} " =~ " install_cpupower " ]]; then
                    has_cpupower=true
                elif command -v cpupower &>/dev/null; then
                    has_cpupower=true
                fi
                
                if [ "$has_cpupower" = false ]; then
                    echo ""
                    echo "警告: set_cpu_performance 需要 install_cpupower，但未选择安装 cpupower 且系统中未找到 cpupower，跳过..."
                    continue
                fi
                ;;
            "configure_ssh")
                # 检查用户是否存在（检查是否在当前执行列表中，或已存在）
                local user_exists=false
                if [[ " ${sorted_modules[@]} " =~ " create_user " ]]; then
                    user_exists=true
                elif [ -n "$TARGET_USER" ] && id "$TARGET_USER" &>/dev/null; then
                    user_exists=true
                fi
                
                if [ "$user_exists" = false ]; then
                    echo ""
                    echo "警告: configure_ssh 需要先创建用户，但未选择 create_user 且用户 $TARGET_USER 不存在，跳过..."
                    continue
                fi
                ;;
        esac
        
        echo ""
        echo "----------------------------------------"
        echo "执行模块: $module"
        echo "----------------------------------------"
        run_module "$module" || {
            echo ""
            echo "错误: 模块 $module 执行失败"
            read -p "是否继续执行其他模块? (y/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                echo "已停止执行"
                break
            fi
        }
    done
    
    echo ""
    echo "=========================================="
    echo "执行完成！"
    echo "=========================================="
    echo ""
    read -p "按回车键继续..."
}

# 主循环
main() {
    while true; do
        show_menu
        read -p "请选择 (例如: 1 2 3 或 A): " selection
        
        if [ -z "$selection" ]; then
            continue
        fi
        
        selection=$(echo "$selection" | tr '[:upper:]' '[:lower:]')
        
        # 处理特殊选项
        if [[ "$selection" == "q" ]] || [[ "$selection" == "quit" ]] || [[ "$selection" == "exit" ]]; then
            echo "退出"
            exit 0
        fi
        
        # 解析并执行选择
        selected_modules=($(parse_selection "$selection"))
        execute_modules "${selected_modules[@]}"
    done
}

# 运行主程序
main
