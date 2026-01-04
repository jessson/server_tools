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
- [系统服务配置](#系统服务配置)
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

#### 最小配置（测试/开发环境）

- **CPU**: 4 核心
- **内存**: 16 GB RAM
- **存储**: 2 TB SSD（推荐 NVMe SSD）
- **网络**: 100 Mbps 带宽

#### 推荐配置（主网生产环境）

- **CPU**: 8+ 核心（推荐 16 核心）
- **内存**: 32 GB RAM（推荐 64 GB）
- **存储**: 4 TB+ NVMe SSD（预留未来增长空间）
- **网络**: 1 Gbps 带宽

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

### 1. 启动 Reth

#### 基本启动命令

```bash
# 主网启动命令
reth node \
    --full \
    --datadir /path/to/data \
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
    --port 30303
```

#### 参数说明

- `--datadir`: 数据存储目录
- `--http`: 启用 HTTP JSON-RPC
- `--http.api`: 启用的 API 接口
- `--ws`: 启用 WebSocket JSON-RPC
- `--authrpc.*`: Engine API 配置（供 Lighthouse 连接）
- `--authrpc.jwtsecret`: JWT 密钥文件路径
- `--port`: P2P 网络端口

#### 完整启动命令（包含更多选项）

```bash
reth node \
    --datadir /var/lib/reth \
    --chain mainnet \
    --http \
    --http.api eth,net,web3,engine,admin,debug,trace \
    --http.port 8545 \
    --http.addr 0.0.0.0 \
    --http.corsdomain "*" \
    --ws \
    --ws.api eth,net,web3,engine,admin \
    --ws.port 8546 \
    --ws.addr 0.0.0.0 \
    --authrpc.addr 127.0.0.1 \
    --authrpc.port 8551 \
    --authrpc.jwtsecret /var/lib/reth/jwt-secret \
    --port 30303 \
    --max-peers 50 \
    --nat extip:$(curl -s ifconfig.me)
```

### 2. 启动 Lighthouse

在 Reth 启动后，启动 Lighthouse：

#### 基本启动命令

```bash
# 启动 Lighthouse 信标节点
lighthouse bn \
    --network mainnet \
    --datadir /var/lib/lighthouse \
    --execution-endpoint http://127.0.0.1:8551 \
    --execution-jwt /var/lib/reth/jwt-secret \
    --checkpoint-sync-url https://beaconstate.info \
    --http \
    --http-address 0.0.0.0 \
    --http-port 5052 \
    --metrics \
    --metrics-address 0.0.0.0 \
    --metrics-port 5054 \
    --port 9000
```

#### 参数说明

- `bn`: 信标节点（beacon node）模式
- `--network`: 网络类型（mainnet, goerli, sepolia 等）
- `--datadir`: 数据存储目录
- `--execution-endpoint`: Reth Engine API 地址
- `--execution-jwt`: JWT 密钥文件路径（与 Reth 使用相同的文件）
- `--checkpoint-sync-url`: 检查点同步 URL（可选，加速同步）
- `--http`: 启用 HTTP API
- `--metrics`: 启用指标收集
- `--port`: P2P 网络端口

#### 完整启动命令（包含更多选项）

```bash
lighthouse bn \
    --network mainnet \
    --datadir /var/lib/lighthouse \
    --execution-endpoint http://127.0.0.1:8551 \
    --execution-jwt /var/lib/reth/jwt-secret \
    --checkpoint-sync-url https://beaconstate.info \
    --http \
    --http-address 0.0.0.0 \
    --http-port 5052 \
    --http-allow-origin "*" \
    --metrics \
    --metrics-address 0.0.0.0 \
    --metrics-port 5054 \
    --port 9000 \
    --target-peers 50 \
    --disable-deposit-contract-sync \
    --validator-monitor-auto \
    --execution-timeout-multiplier 2
```

### 3. 使用 nohup 或 screen 运行

为了在后台运行，可以使用 `nohup` 或 `screen`：

```bash
# 使用 nohup
nohup reth node --datadir /var/lib/reth --http --http.port 8545 --authrpc.addr 127.0.0.1 --authrpc.port 8551 --authrpc.jwtsecret /var/lib/reth/jwt-secret > /var/log/reth.log 2>&1 &

nohup lighthouse bn --network mainnet --datadir /var/lib/lighthouse --execution-endpoint http://127.0.0.1:8551 --execution-jwt /var/lib/reth/jwt-secret --http --http-port 5052 > /var/log/lighthouse.log 2>&1 &
```

或使用 `screen`：

```bash
# 安装 screen
sudo apt install screen -y

# 启动 screen 会话
screen -S reth
# 运行 reth 命令
# 按 Ctrl+A, 然后按 D 退出 screen

screen -S lighthouse
# 运行 lighthouse 命令
# 按 Ctrl+A, 然后按 D 退出 screen

# 重新连接
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

- **完整同步**: 首次同步可能需要数天到数周，取决于硬件和网络
- **检查点同步**: 使用 `--checkpoint-sync-url` 可以大幅加速同步（推荐）

## 系统服务配置

为了确保节点在系统重启后自动启动，可以配置 systemd 服务。

### 1. 创建 Reth 服务

创建文件 `/etc/systemd/system/reth.service`:

```ini
[Unit]
Description=Reth Ethereum Execution Client
After=network.target

[Service]
Type=simple
User=your_username
Group=your_username
WorkingDirectory=/var/lib/reth
ExecStart=/usr/local/bin/reth node \
    --datadir /var/lib/reth \
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
    --max-peers 50
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=reth

[Install]
WantedBy=multi-user.target
```

**注意**: 将 `your_username` 替换为实际运行节点的用户名。

### 2. 创建 Lighthouse 服务

创建文件 `/etc/systemd/system/lighthouse-beacon.service`:

```ini
[Unit]
Description=Lighthouse Ethereum Consensus Client
After=network.target reth.service
Requires=reth.service

[Service]
Type=simple
User=your_username
Group=your_username
WorkingDirectory=/var/lib/lighthouse
ExecStart=/usr/local/bin/lighthouse bn \
    --network mainnet \
    --datadir /var/lib/lighthouse \
    --execution-endpoint http://127.0.0.1:8551 \
    --execution-jwt /var/lib/reth/jwt-secret \
    --checkpoint-sync-url https://beaconstate.info \
    --http \
    --http-address 0.0.0.0 \
    --http-port 5052 \
    --metrics \
    --metrics-address 0.0.0.0 \
    --metrics-port 5054 \
    --port 9000 \
    --target-peers 50
Restart=always
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=lighthouse

[Install]
WantedBy=multi-user.target
```

### 3. 启用和启动服务

```bash
# 重新加载 systemd
sudo systemctl daemon-reload

# 启用服务（开机自启）
sudo systemctl enable reth.service
sudo systemctl enable lighthouse-beacon.service

# 启动服务
sudo systemctl start reth.service
sudo systemctl start lighthouse-beacon.service

# 查看状态
sudo systemctl status reth.service
sudo systemctl status lighthouse-beacon.service

# 查看日志
sudo journalctl -u reth.service -f
sudo journalctl -u lighthouse-beacon.service -f
```

## 监控和维护

### 1. 日志管理

#### 查看实时日志

```bash
# Reth 日志（如果使用 systemd）
sudo journalctl -u reth.service -f

# Lighthouse 日志（如果使用 systemd）
sudo journalctl -u lighthouse-beacon.service -f

# 如果使用 nohup
tail -f /var/log/reth.log
tail -f /var/log/lighthouse.log
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
    /etc/systemd/system/reth.service \
    /etc/systemd/system/lighthouse-beacon.service
```

#### 更新客户端

```bash
# 停止服务
sudo systemctl stop lighthouse-beacon.service
sudo systemctl stop reth.service

# 更新代码（如果从源码编译）
cd /path/to/reth
git pull
cargo build --release
sudo cp target/release/reth /usr/local/bin/

cd /path/to/lighthouse
git pull
make
sudo cp target/release/lighthouse /usr/local/bin/

# 重启服务
sudo systemctl start reth.service
sudo systemctl start lighthouse-beacon.service
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

- 检查 Reth 是否正在运行: `sudo systemctl status reth.service`
- 检查 JWT secret 路径是否正确
- 检查 Engine API 地址和端口（应该是 `127.0.0.1:8551`）
- 检查防火墙是否阻止了本地连接

```bash
# 测试连接
curl -X POST -H "Content-Type: application/json" \
    --data '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}' \
    http://127.0.0.1:8551
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
- 预留足够的磁盘空间（建议 4TB+）
- 考虑使用更大的磁盘或扩展存储

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

# 优化网络参数（参考 configure_sysctl.sh）
sudo sysctl -w net.core.rmem_max=134217728
sudo sysctl -w net.core.wmem_max=134217728
sudo sysctl -w net.ipv4.tcp_fin_timeout=30
```

### 2. Reth 优化

- 使用 NVMe SSD
- 增加 `--max-peers` 参数（根据网络带宽调整）
- 使用 `--db.chaindata` 指定数据目录在快速磁盘上

### 3. Lighthouse 优化

- 使用检查点同步加速初始同步
- 调整 `--target-peers` 参数
- 如果不需要验证器，可以使用轻量级模式

### 4. 硬件建议

- **存储**: 使用 NVMe SSD，读写速度对同步性能至关重要
- **内存**: 至少 32GB，推荐 64GB
- **CPU**: 多核心有助于并行处理
- **网络**: 稳定的高带宽连接

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

