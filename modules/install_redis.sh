#!/bin/bash

# 安装 Redis 模块

set -e

echo ""
echo "安装 Redis..."
REDIS_INSTALLED=false
if command -v redis-server &> /dev/null; then
    echo "Redis 已安装，版本: $(redis-server --version)"
    REDIS_INSTALLED=true
else
    echo "配置 Redis 官方仓库..."
    
    # 下载并添加 Redis GPG 密钥
    curl -fsSL https://packages.redis.io/gpg | gpg --dearmor -o /usr/share/keyrings/redis-archive-keyring.gpg
    chmod 644 /usr/share/keyrings/redis-archive-keyring.gpg
    
    # 添加 Redis 仓库
    echo "deb [signed-by=/usr/share/keyrings/redis-archive-keyring.gpg] https://packages.redis.io/deb $(lsb_release -cs) main" | tee /etc/apt/sources.list.d/redis.list
    
    # 更新软件包列表并安装 Redis
    apt-get update
    apt-get install -y redis
    
    # 启用并启动 Redis 服务
    systemctl enable redis-server
    systemctl start redis-server
    echo "Redis 安装完成"
    REDIS_INSTALLED=true
fi

# 配置 Redis 连接方式
if [ "$REDIS_INSTALLED" = true ]; then
    echo ""
    echo "配置 Redis 连接方式..."
    read -p "是否使用 Unix Domain Socket 而不是 HTTP 连接? (Y/n): " -n 1 -r
    echo
    USE_UNIX_SOCKET=true
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        USE_UNIX_SOCKET=false
        echo "将使用 TCP 连接（默认端口 6379）"
    else
        echo "将使用 Unix Domain Socket 连接"
    fi
    
    # 查找 Redis 配置文件
    REDIS_CONF=""
    if [ -f "/etc/redis/redis.conf" ]; then
        REDIS_CONF="/etc/redis/redis.conf"
    elif [ -f "/etc/redis-server.conf" ]; then
        REDIS_CONF="/etc/redis-server.conf"
    elif [ -f "/etc/redis.conf" ]; then
        REDIS_CONF="/etc/redis.conf"
    fi
    
    if [ -n "$REDIS_CONF" ]; then
        echo "找到 Redis 配置文件: $REDIS_CONF"
        
        # 备份配置文件
        if [ ! -f "${REDIS_CONF}.bak" ]; then
            cp "$REDIS_CONF" "${REDIS_CONF}.bak"
            echo "已备份配置文件到: ${REDIS_CONF}.bak"
        fi
        
        if [ "$USE_UNIX_SOCKET" = true ]; then
            # 配置使用 Unix Domain Socket
            SOCKET_PATH="/var/run/redis/redis-server.sock"
            SOCKET_DIR=$(dirname "$SOCKET_PATH")
            
            # 创建 socket 目录
            mkdir -p "$SOCKET_DIR"
            
            # 配置 socket 路径
            if grep -q "^unixsocket " "$REDIS_CONF"; then
                # 如果已存在 unixsocket 配置，则修改它
                sed -i "s|^unixsocket .*|unixsocket $SOCKET_PATH|" "$REDIS_CONF"
            else
                # 如果不存在，则添加配置
                # 找到 port 配置行，在其后添加 unixsocket 配置
                if grep -q "^port " "$REDIS_CONF"; then
                    sed -i "/^port /a unixsocket $SOCKET_PATH" "$REDIS_CONF"
                else
                    echo "unixsocket $SOCKET_PATH" >> "$REDIS_CONF"
                fi
            fi
            
            # 启用 unixsocket
            if grep -q "^unixsocketperm " "$REDIS_CONF"; then
                sed -i "s|^unixsocketperm .*|unixsocketperm 770|" "$REDIS_CONF"
            else
                # 在 unixsocket 配置后添加 unixsocketperm
                sed -i "/^unixsocket /a unixsocketperm 770" "$REDIS_CONF"
            fi
            
            # 可选：禁用 TCP 监听（注释掉 port 配置）
            read -p "是否禁用 TCP 连接（仅使用 Unix Socket）? (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                if grep -q "^port " "$REDIS_CONF"; then
                    sed -i "s/^port /#port /" "$REDIS_CONF"
                    echo "已禁用 TCP 端口监听"
                fi
            fi
            
            echo "已配置 Unix Domain Socket: $SOCKET_PATH"
            echo "Socket 权限: 770"
            
        else
            # 确保使用 TCP 连接（取消注释 port，禁用 unixsocket）
            if grep -q "^#port " "$REDIS_CONF"; then
                sed -i "s/^#port /port /" "$REDIS_CONF"
            fi
            
            if grep -q "^unixsocket " "$REDIS_CONF"; then
                sed -i "s/^unixsocket /#unixsocket /" "$REDIS_CONF"
            fi
            
            echo "已配置为使用 TCP 连接（端口 6379）"
        fi
        
        # 重启 Redis 服务以应用配置
        echo ""
        echo "重启 Redis 服务以应用配置..."
        systemctl restart redis-server
        
        # 验证配置
        sleep 1
        if systemctl is-active --quiet redis-server; then
            echo "Redis 服务运行正常"
            if [ "$USE_UNIX_SOCKET" = true ]; then
                echo "Unix Socket 路径: $SOCKET_PATH"
                if [ -S "$SOCKET_PATH" ]; then
                    echo "Socket 文件已创建"
                else
                    echo "警告: Socket 文件未找到，请检查配置"
                fi
            else
                echo "TCP 端口: 6379"
            fi
        else
            echo "警告: Redis 服务可能未正常启动，请检查配置和日志"
            systemctl status redis-server --no-pager -l || true
        fi
    else
        echo "警告: 未找到 Redis 配置文件，请手动配置"
    fi
fi

