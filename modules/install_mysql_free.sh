#!/bin/bash

# 安装 MySQL Community Server（免费版），仅允许本地访问

set -e

echo ""
echo "安装 MySQL (Community Server)..."

MYSQL_INSTALLED=false
if command -v mysql &>/dev/null; then
    echo "检测到 MySQL 已安装: $(mysql --version)"
    MYSQL_INSTALLED=true
else
    echo "开始安装 MySQL..."
    apt-get update
    apt-get install -y mysql-server
    systemctl enable mysql
    systemctl start mysql
    echo "MySQL 安装完成"
    MYSQL_INSTALLED=true
fi

if [ "$MYSQL_INSTALLED" = true ]; then
    echo ""
    echo "配置 MySQL 仅允许本地访问..."

    MYSQL_CONF=""
    if [ -f "/etc/mysql/mysql.conf.d/mysqld.cnf" ]; then
        MYSQL_CONF="/etc/mysql/mysql.conf.d/mysqld.cnf"
    elif [ -f "/etc/mysql/my.cnf" ]; then
        MYSQL_CONF="/etc/mysql/my.cnf"
    fi

    if [ -n "$MYSQL_CONF" ]; then
        echo "找到 MySQL 配置文件: $MYSQL_CONF"

        if [ ! -f "${MYSQL_CONF}.bak" ]; then
            cp "$MYSQL_CONF" "${MYSQL_CONF}.bak"
            echo "已备份配置文件到: ${MYSQL_CONF}.bak"
        fi

        if grep -qE "^[# ]*bind-address" "$MYSQL_CONF"; then
            sed -i -E "s/^[# ]*bind-address\s*=.*/bind-address = 127.0.0.1/" "$MYSQL_CONF"
        else
            if grep -q "^\[mysqld\]" "$MYSQL_CONF"; then
                sed -i "/^\[mysqld\]/a bind-address = 127.0.0.1" "$MYSQL_CONF"
            else
                echo "" >> "$MYSQL_CONF"
                echo "[mysqld]" >> "$MYSQL_CONF"
                echo "bind-address = 127.0.0.1" >> "$MYSQL_CONF"
            fi
        fi

        echo "重启 MySQL 服务以应用配置..."
        systemctl restart mysql

        if systemctl is-active --quiet mysql; then
            echo "MySQL 服务运行正常"
            echo "仅监听本地地址: 127.0.0.1"
        else
            echo "警告: MySQL 服务可能未正常启动，请检查配置和日志"
            systemctl status mysql --no-pager -l || true
        fi
    else
        echo "警告: 未找到 MySQL 配置文件，请手动设置 bind-address = 127.0.0.1"
    fi
fi
