#!/bin/bash

# 系统内核参数优化配置模块
# 用于优化 BSC 节点等高性能应用的网络和系统参数

set -e

echo ""
echo "配置系统内核参数..."
echo ""

# 定义配置参数
declare -A SYSCTL_PARAMS=(
    ["net.core.rmem_default"]="33554432"
    ["net.core.rmem_max"]="134217728"
    ["net.core.wmem_default"]="33554432"
    ["net.core.wmem_max"]="134217728"
    ["net.ipv4.tcp_rmem"]="4096 87380 134217728"
    ["net.ipv4.tcp_wmem"]="4096 65536 134217728"
    ["net.ipv4.tcp_keepalive_time"]="600"
    ["net.ipv4.tcp_keepalive_intvl"]="30"
    ["net.ipv4.tcp_keepalive_probes"]="10"
    ["net.core.default_qdisc"]="fq"
    ["net.ipv4.tcp_congestion_control"]="bbr"
    ["net.ipv4.tcp_max_tw_buckets"]="1000000"
    ["vm.swappiness"]="0"
    ["fs.file-max"]="4194304"
    ["fs.nr_open"]="4194304"
    ["vm.dirty_ratio"]="10"
    ["vm.dirty_background_ratio"]="5"
)

# 配置文件路径
SYSCTL_CONF="/etc/sysctl.conf"
SYSCTL_D_DIR="/etc/sysctl.d"
SYSCTL_D_CONF="$SYSCTL_D_DIR/99-bsc-optimization.conf"

# 检查并设置参数到配置文件
set_sysctl_param() {
    local param="$1"
    local value="$2"
    local config_file="$3"
    
    # 转义特殊字符用于 sed
    local escaped_param=$(echo "$param" | sed 's/\./\\./g')
    local escaped_value=$(echo "$value" | sed 's/\./\\./g')
    
    # 检查参数是否已存在（支持注释和空行）
    if grep -qE "^[[:space:]]*${escaped_param}[[:space:]]*=" "$config_file" 2>/dev/null; then
        # 参数已存在，修改它
        # 处理可能存在的注释行
        sed -i "s/^[[:space:]]*${escaped_param}[[:space:]]*=.*/${param} = ${value}/" "$config_file"
        echo "  修改: $param = $value"
    else
        # 参数不存在，追加到文件末尾
        echo "$param = $value" >> "$config_file"
        echo "  新增: $param = $value"
    fi
}

# 应用单个参数（立即生效）
apply_sysctl_param() {
    local param="$1"
    local value="$2"
    
    # 检查参数是否可写
    if sysctl -w "$param=$value" > /dev/null 2>&1; then
        return 0
    else
        echo "  警告: 无法立即应用 $param，可能需要重启后生效"
        return 1
    fi
}

# 选择配置文件
select_config_file() {
    # 优先使用 /etc/sysctl.d/ 目录（更模块化）
    if [ -d "$SYSCTL_D_DIR" ]; then
        echo "$SYSCTL_D_CONF"
    else
        echo "$SYSCTL_CONF"
    fi
}

# 主配置函数
configure_sysctl() {
    local config_file=$(select_config_file)
    
    # 确保配置文件存在
    if [ ! -f "$config_file" ]; then
        touch "$config_file"
        echo "创建配置文件: $config_file"
    fi
    
    # 添加文件头注释
    if ! grep -qE "^#.*BSC.*优化" "$config_file" 2>/dev/null; then
        {
            echo ""
            echo "# =========================================="
            echo "# BSC 节点系统优化配置"
            echo "# 生成时间: $(date '+%Y-%m-%d %H:%M:%S')"
            echo "# =========================================="
            echo ""
        } >> "$config_file"
    fi
    
    echo "使用配置文件: $config_file"
    echo ""
    echo "配置参数:"
    
    # 配置所有参数
    for param in "${!SYSCTL_PARAMS[@]}"; do
        value="${SYSCTL_PARAMS[$param]}"
        set_sysctl_param "$param" "$value" "$config_file"
    done
    
    echo ""
    echo "配置文件已更新"
}

# 应用配置（立即生效）
apply_sysctl() {
    echo ""
    echo "应用配置（立即生效）..."
    
    local success_count=0
    local fail_count=0
    
    for param in "${!SYSCTL_PARAMS[@]}"; do
        value="${SYSCTL_PARAMS[$param]}"
        if apply_sysctl_param "$param" "$value"; then
            ((success_count++))
        else
            ((fail_count++))
        fi
    done
    
    echo ""
    echo "应用完成: 成功 $success_count 个，失败 $fail_count 个"
    
    # 检查 BBR 是否可用
    if [ -f /proc/sys/net/ipv4/tcp_congestion_control ]; then
        local current_cc=$(cat /proc/sys/net/ipv4/tcp_congestion_control)
        if [ "$current_cc" != "bbr" ]; then
            echo ""
            echo "注意: BBR 拥塞控制算法未生效"
            echo "可能需要加载 BBR 模块: modprobe tcp_bbr"
            echo "或检查内核是否支持 BBR（需要 Linux 4.9+）"
        fi
    fi
}

# 验证配置
verify_config() {
    echo ""
    echo "验证当前配置..."
    echo ""
    
    local all_ok=true
    
    for param in "${!SYSCTL_PARAMS[@]}"; do
        expected_value="${SYSCTL_PARAMS[$param]}"
        
        # 读取当前值
        if [ -f "/proc/sys/${param//\.//}" ]; then
            current_value=$(cat "/proc/sys/${param//\.//}" 2>/dev/null || echo "N/A")
            
            # 对于多值参数（如 tcp_rmem），只比较是否包含期望值
            if [[ "$param" == *"rmem"* ]] || [[ "$param" == *"wmem"* ]]; then
                if echo "$current_value" | grep -q "$expected_value"; then
                    echo "  ✓ $param = $current_value"
                else
                    echo "  ✗ $param = $current_value (期望包含: $expected_value)"
                    all_ok=false
                fi
            else
                if [ "$current_value" = "$expected_value" ]; then
                    echo "  ✓ $param = $current_value"
                else
                    echo "  ✗ $param = $current_value (期望: $expected_value)"
                    all_ok=false
                fi
            fi
        else
            echo "  ? $param (无法读取)"
            all_ok=false
        fi
    done
    
    echo ""
    if [ "$all_ok" = true ]; then
        echo "所有配置验证通过"
    else
        echo "部分配置未生效，可能需要重启系统"
    fi
}

# 主流程
main() {
    # 检查 root 权限
    if [ "$EUID" -ne 0 ]; then
        echo "错误: 此脚本需要 root 权限运行"
        echo "请使用: sudo $0"
        exit 1
    fi
    
    # 配置参数到文件
    configure_sysctl
    
    # 询问是否立即应用
    echo ""
    read -p "是否立即应用配置? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        apply_sysctl
        
        # 如果使用 /etc/sysctl.d/，尝试通过 systemd-sysctl 重新加载
        if [[ "$config_file" == "$SYSCTL_D_CONF" ]] && systemctl is-active systemd-sysctl &>/dev/null; then
            echo ""
            echo "通过 systemd-sysctl 重新加载配置..."
            if systemctl restart systemd-sysctl &>/dev/null; then
                echo "配置已通过 systemd-sysctl 重新加载"
            else
                echo "注意: systemd-sysctl 重新加载失败，但配置已直接应用"
            fi
        fi
    else
        echo "配置已保存到文件"
        if [[ "$config_file" == "$SYSCTL_D_CONF" ]]; then
            echo "  - 重启后会自动生效（systemd 会自动加载 /etc/sysctl.d/ 目录下的配置）"
            echo "  - 或手动运行: systemctl restart systemd-sysctl"
        else
            echo "  - 重启后会自动生效"
            echo "  - 或手动运行: sysctl -p $config_file"
        fi
    fi
    
    # 验证配置
    verify_config
    
    echo ""
    echo "系统内核参数配置完成"
    echo ""
    local config_file=$(select_config_file)
    echo "提示:"
    echo "  - 配置文件位置: $config_file"
    if [[ "$config_file" == "$SYSCTL_D_CONF" ]]; then
        echo "  - 重启后自动生效: systemd 会在启动时自动加载 /etc/sysctl.d/ 目录下的配置"
        echo "  - 手动应用配置（无需重启）:"
        echo "    * systemctl restart systemd-sysctl"
        echo "    * 或: sysctl -p $config_file"
    else
        echo "  - 重启后自动生效"
        echo "  - 手动应用配置: sysctl -p $config_file"
    fi
    echo "  - 查看所有配置: sysctl -a | grep <参数名>"
    echo ""
}

# 执行主函数
main
