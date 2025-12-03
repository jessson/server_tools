#!/bin/bash

# 安装 fail2ban 模块

set -e

echo ""
echo "安装 fail2ban..."

# 检查是否已安装
if command -v fail2ban-client &> /dev/null; then
    echo "fail2ban 已安装，版本: $(fail2ban-client --version 2>/dev/null || echo 'unknown')"
    read -p "是否要重新配置 fail2ban? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "跳过 fail2ban 配置"
        exit 0
    fi
else
    # 安装 fail2ban
    echo "正在安装 fail2ban..."
    apt-get update
    apt-get install -y fail2ban
    
    # 启用并启动服务
    systemctl enable fail2ban
    systemctl start fail2ban
    echo "fail2ban 安装完成"
fi

# 配置 fail2ban
echo ""
echo "配置 fail2ban..."

# 备份原始配置文件
JAIL_LOCAL="/etc/fail2ban/jail.local"
JAIL_DEFAULT="/etc/fail2ban/jail.conf"

if [ ! -f "$JAIL_LOCAL" ]; then
    # 如果不存在 jail.local，从 jail.conf 创建
    if [ -f "$JAIL_DEFAULT" ]; then
        cp "$JAIL_DEFAULT" "$JAIL_LOCAL"
        echo "已创建配置文件: $JAIL_LOCAL"
    else
        # 创建基本配置文件
        cat > "$JAIL_LOCAL" <<'EOF'
[DEFAULT]
# 默认配置
EOF
        echo "已创建新的配置文件: $JAIL_LOCAL"
    fi
fi

# 配置基本参数
echo ""
echo "配置基本参数（直接回车使用默认值）:"

# 封禁时间（秒）
read -p "封禁时间（秒，默认: 3600，即 1 小时）: " bantime
bantime=${bantime:-3600}
if ! [[ "$bantime" =~ ^[0-9]+$ ]]; then
    echo "无效输入，使用默认值: 3600"
    bantime=3600
fi

# 查找时间窗口（秒）
read -p "查找时间窗口（秒，默认: 600，即 10 分钟）: " findtime
findtime=${findtime:-600}
if ! [[ "$findtime" =~ ^[0-9]+$ ]]; then
    echo "无效输入，使用默认值: 600"
    findtime=600
fi

# 最大尝试次数
read -p "最大尝试次数（默认: 3）: " maxretry
maxretry=${maxretry:-3}
if ! [[ "$maxretry" =~ ^[0-9]+$ ]]; then
    echo "无效输入，使用默认值: 3"
    maxretry=3
fi

# 邮件通知（可选）
read -p "是否启用邮件通知? (y/N): " -n 1 -r
echo
enable_email=false
destemail=""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    enable_email=true
    read -p "请输入接收通知的邮箱地址: " destemail
    if [ -z "$destemail" ]; then
        echo "未输入邮箱，将禁用邮件通知"
        enable_email=false
    fi
fi

# 配置 SSH jail
echo ""
read -p "是否启用 SSH 保护（sshd jail）? (Y/n): " -n 1 -r
echo
enable_ssh=true
if [[ $REPLY =~ ^[Nn]$ ]]; then
    enable_ssh=false
fi

# 写入配置
echo ""
echo "正在写入配置..."

# 使用 Python 或 sed 来更新配置文件
# 这里使用 sed 来更新配置

# 更新 DEFAULT 部分
if grep -q "^\[DEFAULT\]" "$JAIL_LOCAL"; then
    # 如果存在 DEFAULT 部分，更新其中的配置
    # 更新 bantime
    if grep -q "^bantime\s*=" "$JAIL_LOCAL"; then
        sed -i "s/^bantime\s*=.*/bantime = $bantime/" "$JAIL_LOCAL"
    else
        sed -i "/^\[DEFAULT\]/a bantime = $bantime" "$JAIL_LOCAL"
    fi
    
    # 更新 findtime
    if grep -q "^findtime\s*=" "$JAIL_LOCAL"; then
        sed -i "s/^findtime\s*=.*/findtime = $findtime/" "$JAIL_LOCAL"
    else
        sed -i "/^\[DEFAULT\]/a findtime = $findtime" "$JAIL_LOCAL"
    fi
    
    # 更新 maxretry
    if grep -q "^maxretry\s*=" "$JAIL_LOCAL"; then
        sed -i "s/^maxretry\s*=.*/maxretry = $maxretry/" "$JAIL_LOCAL"
    else
        sed -i "/^\[DEFAULT\]/a maxretry = $maxretry" "$JAIL_LOCAL"
    fi
    
    # 配置邮件通知
    if [ "$enable_email" = true ]; then
        if grep -q "^destemail\s*=" "$JAIL_LOCAL"; then
            sed -i "s|^destemail\s*=.*|destemail = $destemail|" "$JAIL_LOCAL"
        else
            sed -i "/^\[DEFAULT\]/a destemail = $destemail" "$JAIL_LOCAL"
        fi
        
        if grep -q "^sendername\s*=" "$JAIL_LOCAL"; then
            sed -i "s|^sendername\s*=.*|sendername = Fail2Ban|" "$JAIL_LOCAL"
        else
            sed -i "/^\[DEFAULT\]/a sendername = Fail2Ban" "$JAIL_LOCAL"
        fi
        
        if grep -q "^mta\s*=" "$JAIL_LOCAL"; then
            sed -i "s|^mta\s*=.*|mta = sendmail|" "$JAIL_LOCAL"
        else
            sed -i "/^\[DEFAULT\]/a mta = sendmail" "$JAIL_LOCAL"
        fi
        
        if grep -q "^action\s*=" "$JAIL_LOCAL"; then
            # 如果已有 action，检查是否包含邮件通知
            if ! grep -q "action_mwl" "$JAIL_LOCAL"; then
                sed -i "s|^action\s*=.*|action = %(action_mwl)s|" "$JAIL_LOCAL"
            fi
        else
            sed -i "/^\[DEFAULT\]/a action = %(action_mwl)s" "$JAIL_LOCAL"
        fi
    fi
else
    # 如果不存在 DEFAULT 部分，创建它
    cat >> "$JAIL_LOCAL" <<EOF

[DEFAULT]
bantime = $bantime
findtime = $findtime
maxretry = $maxretry
EOF
    if [ "$enable_email" = true ]; then
        cat >> "$JAIL_LOCAL" <<EOF
destemail = $destemail
sendername = Fail2Ban
mta = sendmail
action = %(action_mwl)s
EOF
    fi
fi

# 配置 SSH jail
if [ "$enable_ssh" = true ]; then
    echo "配置 SSH 保护..."
    
    # 检查是否存在 sshd jail 配置
    if grep -q "^\[sshd\]" "$JAIL_LOCAL"; then
        # 使用 Python 来更新配置（更可靠）
        if command -v python3 &> /dev/null; then
            python3 <<PYTHON_SCRIPT
import sys

filename = "$JAIL_LOCAL"
with open(filename, "r") as f:
    lines = f.readlines()

in_sshd = False
sshd_enabled_found = False
new_lines = []

for i, line in enumerate(lines):
    if line.strip().startswith("[sshd]"):
        in_sshd = True
        new_lines.append(line)
    elif in_sshd and line.strip().startswith("["):
        # 遇到下一个 section，结束 sshd section
        if not sshd_enabled_found:
            # 在 section 结束前添加 enabled
            new_lines.append("enabled = true\n")
        in_sshd = False
        new_lines.append(line)
    elif in_sshd and line.strip().startswith("enabled"):
        # 替换现有的 enabled
        new_lines.append("enabled = true\n")
        sshd_enabled_found = True
    else:
        new_lines.append(line)

# 如果整个文件中没有 [sshd] section，添加它
if not any("[sshd]" in line for line in lines):
    new_lines.append("\n[sshd]\n")
    new_lines.append("enabled = true\n")
    new_lines.append("port = ssh\n")
    new_lines.append("logpath = %(sshd_log)s\n")
    new_lines.append("backend = %(sshd_backend)s\n")
elif in_sshd and not sshd_enabled_found:
    # 如果还在 sshd section 中但没有找到 enabled，添加它
    new_lines.append("enabled = true\n")

with open(filename, "w") as f:
    f.writelines(new_lines)
PYTHON_SCRIPT
        else
            # 如果没有 Python，使用简单的 sed 方法
            # 先尝试替换
            sed -i '/^\[sshd\]/,/^\[/{s/^enabled\s*=.*/enabled = true/;}' "$JAIL_LOCAL"
            # 如果替换失败（没有找到 enabled），则添加
            if ! sed -n '/^\[sshd\]/,/^\[/p' "$JAIL_LOCAL" | grep -q "^enabled\s*="; then
                sed -i '/^\[sshd\]/a enabled = true' "$JAIL_LOCAL"
            fi
        fi
    else
        # 添加 sshd jail 配置
        cat >> "$JAIL_LOCAL" <<EOF

[sshd]
enabled = true
port = ssh
logpath = %(sshd_log)s
backend = %(sshd_backend)s
EOF
    fi
else
    # 禁用 sshd jail
    if grep -q "^\[sshd\]" "$JAIL_LOCAL"; then
        if command -v python3 &> /dev/null; then
            python3 <<PYTHON_SCRIPT
import sys

filename = "$JAIL_LOCAL"
with open(filename, "r") as f:
    lines = f.readlines()

in_sshd = False
sshd_enabled_found = False
new_lines = []

for i, line in enumerate(lines):
    if line.strip().startswith("[sshd]"):
        in_sshd = True
        new_lines.append(line)
    elif in_sshd and line.strip().startswith("["):
        # 遇到下一个 section，结束 sshd section
        if not sshd_enabled_found:
            # 在 section 结束前添加 enabled
            new_lines.append("enabled = false\n")
        in_sshd = False
        new_lines.append(line)
    elif in_sshd and line.strip().startswith("enabled"):
        # 替换现有的 enabled
        new_lines.append("enabled = false\n")
        sshd_enabled_found = True
    else:
        new_lines.append(line)

# 如果还在 sshd section 中但没有找到 enabled，添加它
if in_sshd and not sshd_enabled_found:
    new_lines.append("enabled = false\n")

with open(filename, "w") as f:
    f.writelines(new_lines)
PYTHON_SCRIPT
        else
            # 使用 sed
            sed -i '/^\[sshd\]/,/^\[/{s/^enabled\s*=.*/enabled = false/;}' "$JAIL_LOCAL"
            if ! sed -n '/^\[sshd\]/,/^\[/p' "$JAIL_LOCAL" | grep -q "^enabled\s*="; then
                sed -i '/^\[sshd\]/a enabled = false' "$JAIL_LOCAL"
            fi
        fi
    fi
fi

# 验证配置文件语法
echo ""
echo "验证配置文件语法..."
if fail2ban-client -t &>/dev/null; then
    echo "配置文件语法正确"
else
    echo "警告: 配置文件可能有语法错误，请检查: $JAIL_LOCAL"
fi

# 重启 fail2ban 服务
echo ""
echo "重启 fail2ban 服务以应用配置..."
systemctl restart fail2ban

# 等待服务启动
sleep 2

# 验证服务状态
if systemctl is-active --quiet fail2ban; then
    echo "fail2ban 服务运行正常"
    
    # 显示配置摘要
    echo ""
    echo "配置摘要:"
    echo "  封禁时间: $bantime 秒 ($(($bantime / 3600)) 小时)"
    echo "  查找时间窗口: $findtime 秒 ($(($findtime / 60)) 分钟)"
    echo "  最大尝试次数: $maxretry"
    if [ "$enable_email" = true ]; then
        echo "  邮件通知: 已启用 ($destemail)"
    else
        echo "  邮件通知: 已禁用"
    fi
    if [ "$enable_ssh" = true ]; then
        echo "  SSH 保护: 已启用"
    else
        echo "  SSH 保护: 已禁用"
    fi
    
    # 显示当前状态
    echo ""
    echo "当前 fail2ban 状态:"
    fail2ban-client status 2>/dev/null || echo "无法获取状态"
    
    if [ "$enable_ssh" = true ]; then
        echo ""
        echo "SSH jail 状态:"
        fail2ban-client status sshd 2>/dev/null || echo "SSH jail 未启用"
    fi
else
    echo "错误: fail2ban 服务启动失败"
    systemctl status fail2ban --no-pager -l || true
    exit 1
fi

echo ""
echo "fail2ban 配置完成！"
echo "配置文件位置: $JAIL_LOCAL"
echo ""
echo "常用命令:"
echo "  查看状态: fail2ban-client status"
echo "  查看 SSH jail: fail2ban-client status sshd"
echo "  解封 IP: fail2ban-client set sshd unbanip <IP地址>"
echo "  查看被禁 IP: fail2ban-client get sshd banned"
