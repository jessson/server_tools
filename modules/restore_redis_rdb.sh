#!/bin/bash

# 恢复 Redis RDB 文件模块

set -e

echo ""
echo "恢复 Redis RDB 文件..."

# 检查 Redis 是否安装
if ! command -v redis-server &> /dev/null; then
    echo "错误: Redis 未安装，请先运行 install_redis 模块"
    exit 1
fi

echo "Redis 已安装，版本: $(redis-server --version)"

# 查找 Redis 配置文件
REDIS_CONF=""
if [ -f "/etc/redis/redis.conf" ]; then
    REDIS_CONF="/etc/redis/redis.conf"
elif [ -f "/etc/redis-server.conf" ]; then
    REDIS_CONF="/etc/redis-server.conf"
elif [ -f "/etc/redis.conf" ]; then
    REDIS_CONF="/etc/redis.conf"
fi

if [ -z "$REDIS_CONF" ]; then
    echo "错误: 未找到 Redis 配置文件"
    exit 1
fi

echo "找到 Redis 配置文件: $REDIS_CONF"

# 从配置文件读取 RDB 文件路径
RDB_DIR=$(grep "^dir " "$REDIS_CONF" | awk '{print $2}' | tr -d '"' || echo "/var/lib/redis")
RDB_FILENAME=$(grep "^dbfilename " "$REDIS_CONF" | awk '{print $2}' | tr -d '"' || echo "dump.rdb")
RDB_PATH="${RDB_DIR}/${RDB_FILENAME}"

echo "Redis 数据目录: $RDB_DIR"
echo "RDB 文件名: $RDB_FILENAME"
echo "RDB 文件路径: $RDB_PATH"

# 提示输入要恢复的 RDB 文件路径
echo ""
read -p "请输入要恢复的 RDB 文件路径: " SOURCE_RDB
SOURCE_RDB=$(echo "$SOURCE_RDB" | xargs)  # 去除首尾空格

if [ -z "$SOURCE_RDB" ]; then
    echo "错误: 未输入 RDB 文件路径"
    exit 1
fi

if [ ! -f "$SOURCE_RDB" ]; then
    echo "错误: RDB 文件不存在: $SOURCE_RDB"
    exit 1
fi

echo "源 RDB 文件: $SOURCE_RDB"
echo "目标 RDB 文件: $RDB_PATH"

# 确认操作
echo ""
read -p "警告: 此操作将覆盖当前 Redis 数据，是否继续? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "操作已取消"
    exit 0
fi

# 停止 Redis 服务
echo ""
echo "停止 Redis 服务..."
systemctl stop redis-server || true
sleep 2

# 确保 Redis 服务已停止
if systemctl is-active --quiet redis-server; then
    echo "警告: Redis 服务仍在运行，强制停止..."
    systemctl kill redis-server || pkill -9 redis-server || true
    sleep 2
fi

# 备份当前 RDB 文件（如果存在）
if [ -f "$RDB_PATH" ]; then
    BACKUP_PATH="${RDB_PATH}.backup.$(date +%Y%m%d_%H%M%S)"
    echo "备份当前 RDB 文件到: $BACKUP_PATH"
    cp "$RDB_PATH" "$BACKUP_PATH"
    chown redis:redis "$BACKUP_PATH" 2>/dev/null || true
    echo "备份完成"
fi

# 确保数据目录存在
mkdir -p "$RDB_DIR"

# 复制新的 RDB 文件
echo ""
echo "复制 RDB 文件..."
cp "$SOURCE_RDB" "$RDB_PATH"

# 设置正确的权限和所有者
chown redis:redis "$RDB_PATH" 2>/dev/null || chown root:root "$RDB_PATH"
chmod 660 "$RDB_PATH"

# 确保数据目录权限正确
chown redis:redis "$RDB_DIR" 2>/dev/null || chown root:root "$RDB_DIR"
chmod 755 "$RDB_DIR"

echo "RDB 文件已复制并设置权限"

# 启动 Redis 服务
echo ""
echo "启动 Redis 服务..."
systemctl start redis-server

# 等待服务启动
sleep 3

# 验证服务状态
if systemctl is-active --quiet redis-server; then
    echo "Redis 服务已成功启动"
    
    # 验证数据
    echo ""
    echo "验证恢复的数据..."
    sleep 1
    
    # 尝试连接 Redis 并获取信息
    if command -v redis-cli &> /dev/null; then
        # 检查是否使用 Unix Socket
        SOCKET_PATH=$(grep "^unixsocket " "$REDIS_CONF" | awk '{print $2}' | tr -d '"' || echo "")
        
        if [ -n "$SOCKET_PATH" ] && [ -S "$SOCKET_PATH" ]; then
            echo "使用 Unix Socket 连接: $SOCKET_PATH"
            DB_SIZE=$(redis-cli -s "$SOCKET_PATH" DBSIZE 2>/dev/null || echo "无法连接")
        else
            echo "使用 TCP 连接: 127.0.0.1:6379"
            DB_SIZE=$(redis-cli -h 127.0.0.1 -p 6379 DBSIZE 2>/dev/null || echo "无法连接")
        fi
        
        if [ "$DB_SIZE" != "无法连接" ]; then
            echo "数据库中的键数量: $DB_SIZE"
            echo "RDB 恢复成功！"
        else
            echo "警告: 无法连接到 Redis 验证数据，请手动检查"
        fi
    else
        echo "警告: redis-cli 未安装，无法验证数据"
    fi
else
    echo "错误: Redis 服务启动失败"
    echo "查看服务状态:"
    systemctl status redis-server --no-pager -l || true
    echo ""
    echo "请检查日志: journalctl -u redis-server -n 50"
    exit 1
fi

echo ""
echo "RDB 恢复完成！"

