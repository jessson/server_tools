#!/bin/bash

# 创建用户和 home 目录模块
# 支持用户输入自定义用户名，默认值为 four

set -e

# 获取脚本目录和用户信息文件路径
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_USER_FILE="$SCRIPT_DIR/../.target_user"

# 如果通过环境变量传入用户名，则使用它；否则提示用户输入
if [ -n "$TARGET_USER" ]; then
    USERNAME="$TARGET_USER"
    echo ""
    echo "使用指定的用户名: $USERNAME"
else
    # 如果之前已经设置过用户名，先读取它作为默认值
    if [ -f "$TARGET_USER_FILE" ]; then
        DEFAULT_USER=$(cat "$TARGET_USER_FILE" 2>/dev/null | head -1)
    else
        DEFAULT_USER="four"
    fi
    
    echo ""
    echo "创建用户..."
    echo ""
    read -p "请输入用户名 (默认: $DEFAULT_USER): " username
    username=$(echo "$username" | tr -d '[:space:]')  # 去除空格
    
    if [ -z "$username" ]; then
        USERNAME="$DEFAULT_USER"
        echo "使用默认用户名: $USERNAME"
    else
        # 验证用户名是否符合 Linux 用户名规范
        # 规则：只能包含小写字母、数字、下划线、连字符，必须以字母或下划线开头，长度1-32
        if [[ "$username" =~ ^[a-z_][a-z0-9_-]{0,30}[a-z0-9_]$ ]] || [[ "$username" =~ ^[a-z_]$ ]]; then
            USERNAME="$username"
            echo "用户名已设置为: $USERNAME"
        else
            echo ""
            echo "错误: 用户名不符合 Linux 用户名规范"
            echo "规则: 只能包含小写字母、数字、下划线(_)、连字符(-)"
            echo "      必须以字母或下划线开头"
            echo "      不能以连字符结尾"
            echo "      长度限制: 1-32 个字符"
            exit 1
        fi
    fi
fi

echo ""
echo "创建用户 $USERNAME 和 home 目录..."
if id "$USERNAME" &>/dev/null; then
    echo "用户 $USERNAME 已存在，跳过创建"
    # 询问是否要修改密码
    read -p "是否要为用户 $USERNAME 设置新密码? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        passwd "$USERNAME"
    fi
else
    useradd -m -s /bin/bash "$USERNAME"
    echo "用户 $USERNAME 创建成功"
    
    # 设置用户密码
    echo ""
    echo "请为用户 $USERNAME 设置密码:"
    passwd "$USERNAME"
fi

# 确保 home 目录存在
if [ ! -d "/home/$USERNAME" ]; then
    mkdir -p "/home/$USERNAME"
    chown "$USERNAME:$USERNAME" "/home/$USERNAME"
    echo "创建 home 目录: /home/$USERNAME"
fi

# 将用户添加到 sudo 组
echo ""
echo "将 $USERNAME 添加到 sudo 组..."
if groups "$USERNAME" | grep -q "\bsudo\b"; then
    echo "用户 $USERNAME 已在 sudo 组中"
else
    usermod -aG sudo "$USERNAME"
    echo "已将 $USERNAME 添加到 sudo 组"
fi

# 将用户名保存到文件，以便其他模块使用
echo "$USERNAME" > "$TARGET_USER_FILE"

echo "用户创建模块完成"
