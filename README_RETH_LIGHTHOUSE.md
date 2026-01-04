# Reth + Lighthouse 以太坊节点运行指南

本指南介绍如何使用 Reth（执行层客户端）和 Lighthouse（共识层客户端）运行一个完整的以太坊节点。

## 目录

- [概述](#概述)
- [系统要求](#系统要求)
- [架构说明](#架构说明)
- [安装步骤](#安装步骤)
- [配置说明](#配置说明)
- [运行节点](#运行节点)
- [同步状态](#同步状态)
- [监控和维护](#监控和维护)
- [故障排除](#故障排除)
- [性能优化建议](#性能优化建议)

## 概述

### Reth

Reth 是一个用 Rust 编写的以太坊执行层客户端，具有以下特点：

- 🚀 **高性能**: 使用 Rust 编写，性能优异
- 📦 **模块化设计**: 架构清晰，易于维护和扩展
- 🔄 **快速同步**: 高效的数据库设计和同步算法
- 🛡️ **安全性**: 经过严格的安全审计

### Lighthouse

Lighthouse 是一个用 Rust 编写的以太坊共识层（信标链）客户端，特点包括：

- ⚡ **高性能**: Rust 实现的共识层客户端
- 🔒 **安全可靠**: 生产环境验证的稳定性
- 📊 **完整功能**: 支持验证器、API 等完整功能
- 🌐 **活跃开发**: 持续更新和维护

### 组合优势

Reth + Lighthouse 的组合优势：

- 两个客户端都用 Rust 编写，资源占用相对较低
- 性能优异，同步速度快
- 代码开源，社区活跃
- 适合生产环境部署

## 系统要求

### 硬件要求

#### 最小配置（轻量级优化模式）

- **CPU**: 4 核心（推荐 8 核心）
- **内存**: 16 GB RAM（推荐 32 GB）
- **存储**: 500 GB SSD（推荐 1 TB NVMe SSD，使用修剪模式）
- **网络**: 100 Mbps 带宽

#### 推荐配置（主网生产环境）

- **CPU**: 8+ 核心（推荐 16 核心）
- **内存**: 32 GB RAM（推荐 64 GB）
- **存储**: 1-2 TB NVMe SSD（使用修剪模式，无需完整历史数据）
- **网络**: 1 Gbps 带宽

**注意**: 本配置使用修剪模式（pruned mode），只保留必要的链数据，大幅减少磁盘占用。

### 软件要求

- **操作系统**: Ubuntu 20.04 LTS 或更高版本（推荐 22.04 LTS）
- **内核版本**: Linux 5.4+
- **Rust**: 最新稳定版（Reth 和 Lighthouse 需要）
- **其他依赖**: 
  - `build-essential`
  - `git`
  - `curl`
  - `pkg-config`
  - `libssl-dev`
  - `clang`
  - `libclang-dev`

## 架构说明

### 执行层 + 共识层架构

```
┌─────────────────┐
│   Reth (EL)     │  ← 执行层客户端
│   Port: 8545    │     处理交易和执行
└────────┬────────┘
         │ Engine API
         │ (JSON-RPC)
┌────────▼────────┐
│  Lighthouse (CL)│  ← 共识层客户端
│  Port: 5052     │     处理共识和区块验证
└─────────────────┘
```

### 端口说明

**Reth (执行层)**:
- `8545` - HTTP JSON-RPC
- `8546` - WebSocket JSON-RPC
- `30303` - P2P 端口（TCP/UDP）

**Lighthouse (共识层)**:
- `5052` - HTTP REST API
- `5054` - Metrics (可选)
- `9000` - P2P 端口（TCP/UDP）

**Engine API**:
- Reth 默认: `8551`
- Lighthouse 默认: `8551`

## 安装步骤

### 1. 系统准备

```bash
# 更新系统
sudo apt update && sudo apt upgrade -y

# 安装基础依赖
sudo apt install -y \
    build-essential \
    git \
    curl \
    pkg-config \
    libssl-dev \
    clang \
    libclang-dev \
    cmake
```

### 2. 安装 Rust

Reth 和 Lighthouse 都需要 Rust 编译环境。

```bash
# 安装 Rust (使用 rustup)
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source ~/.cargo/env

# 验证安装
rustc --version
cargo --version
```

### 3. 安装 Reth

#### 方式一：从源码编译（推荐）

```bash
# 克隆仓库
git clone https://github.com/paradigmxyz/reth.git
cd reth

# 切换到最新稳定版本
git checkout $(git describe --tags --abbrev=0)

# 编译（这可能需要较长时间）
cargo build --release

# 安装到系统路径
sudo cp target/release/reth /usr/local/bin/

# 验证安装
reth --version
```

#### 方式二：使用预编译二进制（如果可用）

```bash
# 下载最新版本（替换 VERSION 为实际版本号）
RELEASE_URL=$(curl -s https://api.github.com/repos/paradigmxyz/reth/releases/latest | grep "browser_download_url.*linux.*tar.gz" | cut -d '"' -f 4)
curl -L $RELEASE_URL -o reth.tar.gz
tar -xzf reth.tar.gz
sudo cp reth /usr/local/bin/
```

### 4. 安装 Lighthouse

#### 方式一：从源码编译（推荐）

```bash
# 克隆仓库
git clone https://github.com/sigp/lighthouse.git
cd lighthouse

# 切换到最新稳定版本
git checkout $(git describe --tags --abbrev=0)

# 编译（这可能需要较长时间）
make

# 安装到系统路径
sudo cp target/release/lighthouse /usr/local/bin/

# 验证安装
lighthouse --version
```

#### 方式二：使用预编译二进制（如果可用）

```bash
# 下载最新版本
RELEASE_URL=$(curl -s https://api.github.com/repos/sigp/lighthouse/releases/latest | grep "browser_download_url.*x86_64.*tar.gz" | cut -d '"' -f 4)
curl -L $RELEASE_URL -o lighthouse.tar.gz
tar -xzf lighthouse.tar.gz
sudo cp lighthouse /usr/local/bin/
```

## 配置说明

### 1. 创建数据目录

```bash
# 创建数据目录
sudo mkdir -p /var/lib/reth
sudo mkdir -p /var/lib/lighthouse
sudo chown -R $USER:$USER /var/lib/reth
sudo chown -R $USER:$USER /var/lib/lighthouse
```

### 2. Reth 配置

#### 基本配置

创建 Reth 配置文件 `/etc/reth/config.toml`（可选）：

```toml
[datadir]
# 数据目录
datadir = "/var/lib/reth"

[network]
# P2P 端口
port = 30303
# 最大对等节点数
max_peers = 50

[rpc]
# HTTP RPC 端口
http_port = 8545
# WebSocket RPC 端口
ws_port = 8546
# 允许的 HTTP 来源
http_cors = ["*"]
# RPC 地址绑定
http_addr = "0.0.0.0"
ws_addr = "0.0.0.0"

[engine]
# Engine API 地址（供 Lighthouse 连接）
listen_addr = "127.0.0.1"
port = 8551
# JWT 密钥路径
jwt_secret = "/var/lib/reth/jwt-secret"
```

#### 生成 JWT Secret

Reth 和 Lighthouse 需要通过 JWT 密钥进行认证：

```bash
# 生成 JWT secret
openssl rand -hex 32 | tr -d "\n" > /var/lib/reth/jwt-secret
chmod 600 /var/lib/reth/jwt-secret
```

### 3. Lighthouse 配置

Lighthouse 主要通过命令行参数配置，也可以使用配置文件。

#### 基本配置示例

创建 Lighthouse 配置目录：

```bash
mkdir -p /etc/lighthouse
```

## 运行节点

### 启动顺序

**重要**: 必须先启动 Reth（执行层），然后再启动 Lighthouse（共识层）。

### 1. 启动 Reth（优化配置）

#### 优化启动命令（推荐 - 节省磁盘空间和 CPU）

本配置使用修剪模式，只保留必要的链数据，大幅减少磁盘占用和 CPU 负载：

```bash
# 创建日志目录
mkdir -p /var/log/reth

# 优化启动命令（手动启动）
reth node \
    --datadir /var/lib/reth \
    --chain mainnet \
    --prune \
    --prune.max-history 128 \
    --http \
    --http.api eth,net,web3,engine,admin \
    --http.port 8545 \
    --http.addr 0.0.0.0 \
    --ws \
    --ws.api eth,net,web3,engine,admin \
    --ws.port 8546 \
    --ws.addr 0.0.0.0 \
    --authrpc.addr 127.0.0.1 \
    --authrpc.port 8551 \
    --authrpc.jwtsecret /var/lib/reth/jwt-secret \
    --port 30303 \
    --max-peers 25 \
    --db.max-readers 8 \
    --db.max-writers 4 \
    --txpool.max-size 1000 \
    --txpool.max-account-slots 16
```

#### 优化参数说明

**磁盘空间优化**:
- `--prune`: 启用修剪模式，自动清理旧的历史数据
- `--prune.max-history 128`: 只保留最近 128 个区块的历史数据（可根据需要调整，值越小占用越少）

**CPU 性能优化**:
- `--max-peers 25`: 减少对等节点数（默认 50），降低网络和 CPU 负载
- `--db.max-readers 8`: 限制数据库读取器数量，避免过度并发
- `--db.max-writers 4`: 限制数据库写入器数量，优化 I/O 性能
- `--txpool.max-size 1000`: 限制交易池大小，减少内存占用
- `--txpool.max-account-slots 16`: 限制每个账户的交易槽位

**API 优化**:
- 移除了 `debug` 和 `trace` API（这些会占用大量资源）
- 只保留必要的 API：`eth,net,web3,engine,admin`

#### 使用 nohup 后台启动（推荐）

```bash
# 使用 nohup 在后台启动 Reth
nohup reth node \
    --datadir /var/lib/reth \
    --chain mainnet \
    --prune \
    --prune.max-history 128 \
    --http \
    --http.api eth,net,web3,engine,admin \
    --http.port 8545 \
    --http.addr 0.0.0.0 \
    --ws \
    --ws.api eth,net,web3,engine,admin \
    --ws.port 8546 \
    --ws.addr 0.0.0.0 \
    --authrpc.addr 127.0.0.1 \
    --authrpc.port 8551 \
    --authrpc.jwtsecret /var/lib/reth/jwt-secret \
    --port 30303 \
    --max-peers 25 \
    --db.max-readers 8 \
    --db.max-writers 4 \
    --txpool.max-size 1000 \
    --txpool.max-account-slots 16 \
    > /var/log/reth.log 2>&1 &

# 查看进程
ps aux | grep reth

# 查看日志
tail -f /var/log/reth.log
```

#### 使用 screen 启动（便于管理）

```bash
# 安装 screen（如果未安装）
sudo apt install screen -y

# 创建启动脚本
cat > ~/start_reth.sh << 'EOF'
#!/bin/bash
cd /var/lib/reth
reth node \
    --datadir /var/lib/reth \
    --chain mainnet \
    --prune \
    --prune.max-history 128 \
    --http \
    --http.api eth,net,web3,engine,admin \
    --http.port 8545 \
    --http.addr 0.0.0.0 \
    --ws \
    --ws.api eth,net,web3,engine,admin \
    --ws.port 8546 \
    --ws.addr 0.0.0.0 \
    --authrpc.addr 127.0.0.1 \
    --authrpc.port 8551 \
    --authrpc.jwtsecret /var/lib/reth/jwt-secret \
    --port 30303 \
    --max-peers 25 \
    --db.max-readers 8 \
    --db.max-writers 4 \
    --txpool.max-size 1000 \
    --txpool.max-account-slots 16
EOF

chmod +x ~/start_reth.sh

# 在 screen 中启动
screen -S reth -dm bash -c '~/start_reth.sh'

# 查看 screen 会话
screen -ls

# 连接到 screen 会话
screen -r reth

# 退出 screen（不断开进程）：按 Ctrl+A，然后按 D
# 停止 Reth：在 screen 中按 Ctrl+C
```

### 2. 启动 Lighthouse（优化配置）

在 Reth 启动并运行后，启动 Lighthouse：

#### 优化启动命令

```bash
# 创建日志目录
mkdir -p /var/log/lighthouse

# 优化启动命令（手动启动）
lighthouse bn \
    --network mainnet \
    --datadir /var/lib/lighthouse \
    --execution-endpoint http://127.0.0.1:8551 \
    --execution-jwt /var/lib/reth/jwt-secret \
    --checkpoint-sync-url https://beaconstate.info \
    --http \
    --http-address 0.0.0.0 \
    --http-port 5052 \
    --port 9000 \
    --target-peers 25 \
    --disable-deposit-contract-sync \
    --execution-timeout-multiplier 2
```

#### 优化参数说明

**资源优化**:
- `--target-peers 25`: 减少目标对等节点数（默认 50），降低网络和 CPU 负载
- `--disable-deposit-contract-sync`: 禁用存款合约同步，节省资源
- 移除了 `--metrics`：如果不需要监控指标，可以移除以节省资源

**同步优化**:
- `--checkpoint-sync-url https://beaconstate.info`: 使用检查点同步，大幅加速初始同步
- `--execution-timeout-multiplier 2`: 增加执行层超时倍数，提高稳定性

#### 使用 nohup 后台启动（推荐）

```bash
# 使用 nohup 在后台启动 Lighthouse
nohup lighthouse bn \
    --network mainnet \
    --datadir /var/lib/lighthouse \
    --execution-endpoint http://127.0.0.1:8551 \
    --execution-jwt /var/lib/reth/jwt-secret \
    --checkpoint-sync-url https://beaconstate.info \
    --http \
    --http-address 0.0.0.0 \
    --http-port 5052 \
    --port 9000 \
    --target-peers 25 \
    --disable-deposit-contract-sync \
    --execution-timeout-multiplier 2 \
    > /var/log/lighthouse.log 2>&1 &

# 查看进程
ps aux | grep lighthouse

# 查看日志
tail -f /var/log/lighthouse.log
```

#### 使用 screen 启动（便于管理）

```bash
# 创建启动脚本
cat > ~/start_lighthouse.sh << 'EOF'
#!/bin/bash
cd /var/lib/lighthouse
lighthouse bn \
    --network mainnet \
    --datadir /var/lib/lighthouse \
    --execution-endpoint http://127.0.0.1:8551 \
    --execution-jwt /var/lib/reth/jwt-secret \
    --checkpoint-sync-url https://beaconstate.info \
    --http \
    --http-address 0.0.0.0 \
    --http-port 5052 \
    --port 9000 \
    --target-peers 25 \
    --disable-deposit-contract-sync \
    --execution-timeout-multiplier 2
EOF

chmod +x ~/start_lighthouse.sh

# 在 screen 中启动
screen -S lighthouse -dm bash -c '~/start_lighthouse.sh'

# 查看 screen 会话
screen -ls

# 连接到 screen 会话
screen -r lighthouse

# 退出 screen（不断开进程）：按 Ctrl+A，然后按 D
# 停止 Lighthouse：在 screen 中按 Ctrl+C
```

### 3. 停止节点

```bash
# 查找进程
ps aux | grep -E "reth|lighthouse"

# 停止 Reth
pkill -f "reth node"

# 停止 Lighthouse
pkill -f "lighthouse bn"

# 如果在 screen 中运行，可以连接到 screen 后按 Ctrl+C
screen -r reth
screen -r lighthouse
```

## 同步状态

### 检查 Reth 同步状态

```bash
# 通过 RPC 查询同步状态
curl -X POST -H "Content-Type: application/json" \
    --data '{"jsonrpc":"2.0","method":"eth_syncing","params":[],"id":1}' \
    http://localhost:8545

# 查询最新区块号
curl -X POST -H "Content-Type: application/json" \
    --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
    http://localhost:8545
```

如果返回 `false`，说明已同步完成。

### 检查 Lighthouse 同步状态

```bash
# 查询同步状态
curl http://localhost:5052/eth/v1/node/syncing

# 查询健康状态
curl http://localhost:5052/eth/v1/node/health

# 查询链头信息
curl http://localhost:5052/eth/v1/beacon/headers/finalized
```

### 同步时间

- **修剪模式同步**: 使用 `--prune` 模式，首次同步时间会大幅缩短，通常数小时到数天即可完成
- **检查点同步**: 使用 `--checkpoint-sync-url` 可以大幅加速 Lighthouse 初始同步（推荐）
- **磁盘占用**: 修剪模式下的磁盘占用约为完整节点的 10-20%，通常只需要 200-500 GB

## 启动脚本（可选）

为了方便管理，可以创建启动和停止脚本：

### 创建启动脚本

```bash
# 创建启动脚本
cat > ~/start_nodes.sh << 'EOF'
#!/bin/bash

# 检查 Reth 是否已运行
if pgrep -f "reth node" > /dev/null; then
    echo "Reth 已在运行"
else
    echo "启动 Reth..."
    nohup reth node \
        --datadir /var/lib/reth \
        --chain mainnet \
        --prune \
        --prune.max-history 128 \
        --http \
        --http.api eth,net,web3,engine,admin \
        --http.port 8545 \
        --http.addr 0.0.0.0 \
        --ws \
        --ws.api eth,net,web3,engine,admin \
        --ws.port 8546 \
        --ws.addr 0.0.0.0 \
        --authrpc.addr 127.0.0.1 \
        --authrpc.port 8551 \
        --authrpc.jwtsecret /var/lib/reth/jwt-secret \
        --port 30303 \
        --max-peers 25 \
        --db.max-readers 8 \
        --db.max-writers 4 \
        --txpool.max-size 1000 \
        --txpool.max-account-slots 16 \
        > /var/log/reth.log 2>&1 &
    echo "Reth 已启动，PID: $(pgrep -f 'reth node')"
fi

# 等待 Reth 启动
sleep 5

# 检查 Lighthouse 是否已运行
if pgrep -f "lighthouse bn" > /dev/null; then
    echo "Lighthouse 已在运行"
else
    echo "启动 Lighthouse..."
    nohup lighthouse bn \
        --network mainnet \
        --datadir /var/lib/lighthouse \
        --execution-endpoint http://127.0.0.1:8551 \
        --execution-jwt /var/lib/reth/jwt-secret \
        --checkpoint-sync-url https://beaconstate.info \
        --http \
        --http-address 0.0.0.0 \
        --http-port 5052 \
        --port 9000 \
        --target-peers 25 \
        --disable-deposit-contract-sync \
        --execution-timeout-multiplier 2 \
        > /var/log/lighthouse.log 2>&1 &
    echo "Lighthouse 已启动，PID: $(pgrep -f 'lighthouse bn')"
fi

echo "节点启动完成"
EOF

chmod +x ~/start_nodes.sh
```

### 创建停止脚本

```bash
# 创建停止脚本
cat > ~/stop_nodes.sh << 'EOF'
#!/bin/bash

echo "停止 Lighthouse..."
pkill -f "lighthouse bn"
sleep 2

echo "停止 Reth..."
pkill -f "reth node"
sleep 2

echo "检查进程..."
if pgrep -f "reth node" > /dev/null || pgrep -f "lighthouse bn" > /dev/null; then
    echo "警告: 仍有进程在运行"
    pgrep -f "reth node" && echo "Reth PID: $(pgrep -f 'reth node')"
    pgrep -f "lighthouse bn" && echo "Lighthouse PID: $(pgrep -f 'lighthouse bn')"
else
    echo "所有节点已停止"
fi
EOF

chmod +x ~/stop_nodes.sh
```

### 使用脚本

```bash
# 启动节点
~/start_nodes.sh

# 停止节点
~/stop_nodes.sh

# 查看状态
ps aux | grep -E "reth|lighthouse"
```

## 监控和维护

### 1. 日志管理

#### 查看实时日志

```bash
# 查看 Reth 日志
tail -f /var/log/reth.log

# 查看 Lighthouse 日志
tail -f /var/log/lighthouse.log

# 同时查看两个日志
tail -f /var/log/reth.log /var/log/lighthouse.log
```

#### 日志轮转

创建日志轮转配置 `/etc/logrotate.d/reth-lighthouse`:

```
/var/log/reth.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 0640 your_username your_username
}

/var/log/lighthouse.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 0640 your_username your_username
}
```

### 2. 监控指标

#### Lighthouse Metrics

如果启用了 metrics（`--metrics`），可以访问：

```bash
# 查看指标
curl http://localhost:5054/metrics
```

常用监控指标：

- `lighthouse_sync_eth1_fallback_configured`: ETH1 连接状态
- `lighthouse_network_peers`: 对等节点数
- `lighthouse_beacon_current_slot`: 当前 slot
- `lighthouse_beacon_head_slot`: 链头 slot

### 3. 资源监控

```bash
# 查看进程资源使用
top -p $(pgrep reth) -p $(pgrep lighthouse)

# 或使用 htop
htop -p $(pgrep reth),$(pgrep lighthouse)

# 查看磁盘使用
df -h /var/lib/reth /var/lib/lighthouse

# 查看网络连接
netstat -an | grep -E "30303|9000|8545|5052"
```

### 4. 定期维护

#### 备份配置

```bash
# 备份重要配置和密钥
sudo tar -czf reth-lighthouse-backup-$(date +%Y%m%d).tar.gz \
    /var/lib/reth/jwt-secret \
    ~/start_nodes.sh \
    ~/stop_nodes.sh \
    ~/start_reth.sh \
    ~/start_lighthouse.sh
```

#### 更新客户端

```bash
# 停止节点
~/stop_nodes.sh
# 或手动停止
pkill -f "reth node"
pkill -f "lighthouse bn"

# 更新代码（如果从源码编译）
cd /path/to/reth
git pull
cargo build --release
sudo cp target/release/reth /usr/local/bin/

cd /path/to/lighthouse
git pull
make
sudo cp target/release/lighthouse /usr/local/bin/

# 重启节点
~/start_nodes.sh
# 或手动启动（参考运行节点章节）
```

## 故障排除

### 常见问题

#### 1. Reth 无法启动

**问题**: 端口被占用

```bash
# 检查端口占用
sudo netstat -tulpn | grep -E "8545|30303|8551"
sudo lsof -i :8545

# 杀死占用进程
sudo kill -9 <PID>
```

**问题**: JWT secret 文件不存在或权限错误

```bash
# 检查文件
ls -l /var/lib/reth/jwt-secret

# 重新生成
openssl rand -hex 32 | tr -d "\n" > /var/lib/reth/jwt-secret
chmod 600 /var/lib/reth/jwt-secret
```

#### 2. Lighthouse 无法连接到 Reth

**问题**: Engine API 连接失败

- 检查 Reth 是否正在运行: `ps aux | grep "reth node"`
- 检查 JWT secret 路径是否正确
- 检查 Engine API 地址和端口（应该是 `127.0.0.1:8551`）
- 检查防火墙是否阻止了本地连接

```bash
# 检查 Reth 进程
ps aux | grep "reth node"

# 测试连接
curl -X POST -H "Content-Type: application/json" \
    --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
    http://127.0.0.1:8551

# 查看 Reth 日志
tail -n 50 /var/log/reth.log
```

#### 3. 同步缓慢

**解决方案**:

- 使用检查点同步（checkpoint sync）
- 增加最大对等节点数
- 检查网络带宽
- 使用 SSD 存储
- 检查系统资源（CPU、内存、磁盘 I/O）

#### 4. 内存不足

**解决方案**:

- 增加系统内存
- 关闭其他占用内存的服务
- 检查是否有内存泄漏（查看日志）

#### 5. 磁盘空间不足

**解决方案**:

- 监控磁盘使用: `df -h`
- 使用修剪模式（`--prune`）可以大幅减少磁盘占用
- 调整 `--prune.max-history` 参数，值越小占用越少（但会影响历史查询能力）
- 定期清理日志文件: `find /var/log -name "*.log" -mtime +7 -delete`
- 检查数据目录大小: `du -sh /var/lib/reth /var/lib/lighthouse`

### 日志分析

#### Reth 日志关键词

- `Syncing`: 正在同步
- `Synced`: 已同步
- `Error`: 错误信息
- `Peer`: 对等节点连接

#### Lighthouse 日志关键词

- `Syncing`: 正在同步
- `Synced`: 已同步
- `ERROR`: 错误信息
- `WARN`: 警告信息
- `Connected to execution node`: 连接到执行节点

### 调试技巧

```bash
# 查看详细日志级别（如果支持）
# Reth
reth node --log-level debug ...

# Lighthouse
lighthouse bn --log-level debug ...

# 检查网络连接
ss -tulpn | grep -E "30303|9000|8545|5052|8551"

# 检查进程状态
ps aux | grep -E "reth|lighthouse"

# 查看系统资源
iostat -x 1
vmstat 1
```

## 性能优化建议

### 1. 系统优化

```bash
# 增加文件描述符限制
echo "* soft nofile 65535" | sudo tee -a /etc/security/limits.conf
echo "* hard nofile 65535" | sudo tee -a /etc/security/limits.conf

# 优化网络参数
sudo sysctl -w net.core.rmem_max=134217728
sudo sysctl -w net.core.wmem_max=134217728
sudo sysctl -w net.ipv4.tcp_fin_timeout=30
sudo sysctl -w net.ipv4.tcp_keepalive_time=600
sudo sysctl -w net.ipv4.tcp_keepalive_probes=3
sudo sysctl -w net.ipv4.tcp_keepalive_intvl=15

# 优化 I/O 调度（针对 SSD）
echo noop | sudo tee /sys/block/nvme0n1/queue/scheduler 2>/dev/null || true
```

### 2. Reth 磁盘空间优化

**修剪模式配置**:
- `--prune`: 启用自动修剪，删除旧的历史数据
- `--prune.max-history 128`: 只保留最近 128 个区块的历史（可根据需要调整）
  - 值越小，磁盘占用越少，但历史查询能力越弱
  - 推荐值：64-256 个区块

**数据库优化**:
- `--db.max-readers 8`: 限制并发读取，避免过度占用资源
- `--db.max-writers 4`: 限制并发写入，优化 I/O 性能

**交易池优化**:
- `--txpool.max-size 1000`: 限制交易池大小（默认更大）
- `--txpool.max-account-slots 16`: 限制每个账户的交易槽位

### 3. Reth CPU 性能优化

**网络优化**:
- `--max-peers 25`: 减少对等节点数（默认 50），降低网络处理负载
- 根据实际网络带宽调整，带宽较小可以进一步降低

**API 优化**:
- 移除不必要的 API：`debug`, `trace` 等会占用大量 CPU 和内存
- 只启用必要的 API：`eth,net,web3,engine,admin`

### 4. Lighthouse 优化

**同步优化**:
- `--checkpoint-sync-url`: 使用检查点同步，大幅加速初始同步
- `--target-peers 25`: 减少对等节点数，降低资源占用

**功能裁剪**:
- `--disable-deposit-contract-sync`: 如果不需要验证器功能，可以禁用
- 移除 `--metrics`: 如果不需要监控指标，可以节省资源

### 5. 磁盘空间占用对比

| 模式 | 磁盘占用 | 历史数据 | 适用场景 |
|------|---------|---------|---------|
| 完整节点 | 2-4 TB | 完整历史 | 需要完整历史查询 |
| 修剪模式（本配置） | 200-500 GB | 最近 128 区块 | 轻量级节点，节省空间 |
| 最小修剪 | 100-200 GB | 最近 32-64 区块 | 极简配置 |

### 6. 硬件建议（优化配置）

- **存储**: 500 GB - 1 TB NVMe SSD（修剪模式）
- **内存**: 16-32 GB RAM（足够运行修剪模式）
- **CPU**: 4-8 核心（修剪模式对 CPU 要求较低）
- **网络**: 100 Mbps+ 稳定连接

### 7. 监控资源使用

```bash
# 监控 CPU 和内存
top -p $(pgrep -d, -f "reth|lighthouse")

# 监控磁盘 I/O
iostat -x 1

# 监控磁盘使用
df -h
du -sh /var/lib/reth /var/lib/lighthouse

# 监控网络连接
netstat -an | grep -E "30303|9000|8545|5052" | wc -l
```

## 安全建议

1. **防火墙配置**: 只开放必要的端口
   - RPC 端口（8545, 5052）应该限制访问
   - P2P 端口（30303, 9000）需要对外开放

2. **用户权限**: 使用非 root 用户运行节点

3. **密钥安全**: 保护 JWT secret 文件
   ```bash
   chmod 600 /var/lib/reth/jwt-secret
   ```

4. **RPC 访问控制**: 如果不需要对外暴露 RPC，将 `--http.addr` 设置为 `127.0.0.1`

5. **定期更新**: 保持客户端版本更新，及时修复安全漏洞

## 参考资源

- **Reth 官方文档**: https://reth.rs/
- **Reth GitHub**: https://github.com/paradigmxyz/reth
- **Lighthouse 官方文档**: https://lighthouse-book.sigmaprime.io/
- **Lighthouse GitHub**: https://github.com/sigp/lighthouse
- **以太坊官方文档**: https://ethereum.org/en/developers/docs/nodes-and-clients/

## 许可证

本文档遵循 MIT 许可证。

