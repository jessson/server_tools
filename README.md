# 服务器初始化工具

适用于 Debian/Ubuntu 系统的模块化服务器初始化脚本，提供交互式菜单选择，支持一键配置服务器环境。

## 特性

- 🎯 **模块化设计** - 每个功能独立模块，可按需选择
- 🔄 **依赖管理** - 自动处理模块间依赖关系，按正确顺序执行
- 🛡️ **安全配置** - SSH 密钥登录、防火墙配置等安全加固
- 🚀 **开发环境** - 一键安装常用开发工具（Go、Rust、Node.js）
- ⚡ **性能优化** - CPU 性能模式配置、系统内核参数优化
- 📦 **软件安装** - Redis 等常用服务安装
- 🔧 **系统调优** - 网络缓冲区、TCP 参数等内核参数优化（适用于 BSC 节点等高性能应用）

## 脚本结构

```
server_tools/
├── tools.sh                    # 主脚本（交互式菜单）
├── modules/                    # 功能模块目录
│   ├── create_user.sh          # 创建用户模块
│   ├── install_build_tools.sh  # 安装构建工具模块
│   ├── install_cpupower.sh    # 安装 cpupower 工具模块
│   ├── set_cpu_performance.sh # 设置 CPU 性能模式模块
│   ├── install_redis.sh        # 安装 Redis 模块
│   ├── configure_ssh.sh        # 配置 SSH 模块
│   ├── configure_firewall.sh   # 配置防火墙模块
│   ├── install_golang.sh       # 安装 Golang 模块
│   ├── install_rust.sh         # 安装 Rust 模块
│   ├── install_node.sh         # 安装 Node.js 模块
│   ├── install_fail2ban.sh     # 安装 fail2ban 模块
│   └── configure_sysctl.sh    # 系统内核参数优化模块
└── README.md                   # 说明文档
```

## 功能模块

### 基础配置

1. **创建用户** (`create_user.sh`)
   - 创建新用户并添加到 sudo 组
   - 支持自定义用户名（默认: `four`）
   - 用户名会自动保存，后续模块会使用该用户

2. **安装构建工具** (`install_build_tools.sh`)
   - 安装基础开发工具包
   - 包含: build-essential, git, curl, wget, vim, htop, net-tools 等

3. **安装 cpupower** (`install_cpupower.sh`)
   - 安装 CPU 频率管理工具
   - 用于设置和调整 CPU 性能模式

4. **设置 CPU 性能模式** (`set_cpu_performance.sh`)
   - 使用 cpupower 设置 CPU 为 performance 模式
   - **依赖**: `install_cpupower`

### 服务安装

5. **安装 Redis** (`install_redis.sh`)
   - 从 Redis 官方仓库安装最新稳定版
   - 自动配置为系统服务

### 安全配置

6. **配置 SSH** (`configure_ssh.sh`)
   - 配置 SSH 仅允许密钥登录
   - 禁用密码登录，提高安全性
   - **依赖**: `create_user`
   - 需要输入 SSH 公钥（支持单行或多行输入）

7. **配置防火墙** (`configure_firewall.sh`)
   - 使用 UFW (Uncomplicated Firewall) 配置防火墙
   - 支持预定义模板（Geth、Web）和自定义端口
   - 默认开放 SSH 端口 (22)，确保不会断开连接

### 开发环境

8. **安装 Golang** (`install_golang.sh`)
   - 从官方源下载并安装 Go
   - 支持自定义版本号（默认: 1.25.5）
   - 自动配置 PATH 环境变量
   - 安装路径: `/usr/local/go`
   - 支持为指定用户配置环境变量

9. **安装 Rust** (`install_rust.sh`)
   - 使用 rustup 安装 Rust 工具链
   - 自动安装最新稳定版
   - 支持为指定用户安装
   - 安装路径: `~/.cargo`

10. **安装 Node.js** (`install_node.sh`)
    - 使用 nvm (Node Version Manager) 安装
    - 自动安装最新的 LTS (长期支持) 版本
    - 支持为指定用户安装
    - 自动配置 nvm 环境变量

11. **安装 fail2ban** (`install_fail2ban.sh`)
    - 安装并配置 fail2ban 入侵防护系统
    - 自动配置 SSH 防护规则
    - 防止暴力破解攻击

12. **配置系统内核参数优化** (`configure_sysctl.sh`)
    - 优化系统内核参数，适用于高性能应用（如 BSC 节点）
    - 配置网络缓冲区、TCP 参数、系统资源等
    - 支持立即应用或重启后生效
    - **注意**: 此模块不在"全部执行"选项中，需要单独选择

## 使用方法

### 基本使用

```bash
# 克隆或下载项目
cd server_tools

# 以 root 权限运行
sudo ./tools.sh
```

### 菜单操作

运行脚本后会显示交互式菜单：

```
==========================================
服务器初始化工具
==========================================

目标用户: four (将在创建用户时设置或修改)

请选择要执行的功能（可以多选，用空格分隔，例如: 1 2 3）:

  [1] 创建用户并添加到 sudo 组
  [2] 安装构建相关软件 (build-essential, git, curl, vim 等)
  [3] 安装 cpupower 工具
  [4] 设置 CPU 模式为 performance
  [5] 安装 Redis (从官方仓库)
  [6] 配置 SSH (仅允许密钥登录)
  [7] 配置防火墙 (UFW)
  [8] 安装 Golang
  [9] 安装 Rust
  [10] 安装 Node.js (使用 nvm)
  [11] 安装 fail2ban (入侵防护)
  [12] 配置系统内核参数优化 (BSC节点优化)

  [A] 全部执行（按依赖顺序）
  [Q] 退出
```

**选择方式**:
- **单个功能**: 输入数字编号，例如 `1` 或 `8`
- **多个功能**: 输入多个数字，用空格分隔，例如 `1 2 3` 或 `8 9 10`
- **全部执行**: 输入 `A` 或 `a`，将按依赖顺序执行所有功能
- **退出**: 输入 `Q` 或 `q`

### 执行流程

1. 选择功能后，脚本会显示执行顺序（已考虑依赖关系）
2. 确认后开始执行
3. 如果某个模块失败，可以选择继续执行其他模块
4. 执行完成后显示结果

## 依赖关系

脚本会自动处理模块间的依赖关系，确保按正确顺序执行：

- `set_cpu_performance` → 依赖于 `install_cpupower`
- `configure_ssh` → 依赖于 `create_user`

**全部执行时的顺序**:
1. create_user
2. install_build_tools
3. install_cpupower
4. set_cpu_performance
5. install_redis
6. configure_ssh
7. configure_firewall
8. install_golang
9. install_rust
10. install_node
11. install_fail2ban

**注意**: `configure_sysctl` (系统内核参数优化) 不在"全部执行"选项中，需要单独选择执行。

## 详细功能说明

### SSH 配置

配置 SSH 模块时：

1. **输入 SSH 公钥**
   - 如果直接按回车（不输入任何内容），将跳过整个 SSH 配置
   - 如果输入了 SSH 公钥：
     - **单行**: 直接粘贴公钥内容，然后按回车，在下一行输入 `END` 结束
     - **多行**: 粘贴第一行后按回车，继续粘贴后续行，最后输入 `END` 结束

2. **自动配置**
   - SSH 公钥会自动保存到 `/home/<用户名>/.ssh/authorized_keys`
   - 同时保存到 `/root/.ssh/authorized_keys`
   - 禁用密码登录，仅允许密钥登录

### 防火墙配置

防火墙模块使用 UFW 进行配置，支持预定义模板和自定义端口。

#### 预定义模板

1. **Geth (默认)**
   - SSH: 22 (TCP)
   - P2P 端口范围: 30000:31000 (TCP/UDP)
   - RPC 端口: 8545 (HTTP), 8546 (WebSocket)

2. **Web**
   - SSH: 22 (TCP)
   - HTTP: 80 (TCP)
   - HTTPS: 443 (TCP)

#### 使用流程

1. **选择模板**: 选择 Geth、Web 或自定义端口配置
2. **应用模板端口**: 如果选择了模板，会先应用模板的端口配置
3. **添加自定义端口**: 选择模板后，会询问是否继续添加自定义端口
4. **预览规则**: 配置完成后会显示所有防火墙规则预览
5. **启用防火墙**: 确认规则无误后，可选择是否立即启用防火墙

#### 自定义端口格式

- 单个端口: `8080`
- 端口范围: `8000:9000`
- 指定协议: `8080/tcp` 或 `8080/udp`
- 多个端口: `8080 9090 10000`
- 混合示例: `8080 9090/tcp 10000:10010/udp`

### 开发环境安装

#### Golang 安装

- 提示输入版本号（默认: 1.25.5）
- 从 `https://go.dev/dl/go{version}.linux-amd64.tar.gz` 下载
- 安装到 `/usr/local/go`
- 自动添加到系统 PATH 和用户 `.bashrc`
- 验证安装并显示版本信息

#### Rust 安装

- 使用官方 rustup 安装脚本
- 自动安装最新稳定版
- 如果已安装，会提示是否重新安装
- 支持为指定用户安装
- 安装路径: `~/.cargo`

#### Node.js 安装

- 使用 nvm (Node Version Manager) 安装
- 自动安装最新的 LTS 版本
- 如果已安装 nvm，会检测并询问是否重新安装
- 自动设置默认版本为 LTS
- 支持为指定用户安装
- nvm 配置会自动添加到 `.bashrc`

**环境变量配置**:
- 新终端会话需要执行: `source ~/.nvm/nvm.sh` (Node.js)
- 或重新登录以自动加载环境变量

### 系统内核参数优化

系统内核参数优化模块 (`configure_sysctl.sh`) 用于优化高性能应用（如 BSC 节点）的系统参数。

#### 配置的参数

**网络缓冲区**:
- `net.core.rmem_default/wmem_default`: 32MB
- `net.core.rmem_max/wmem_max`: 128MB
- `net.ipv4.tcp_rmem/wmem`: TCP 接收/发送缓冲区配置

**TCP 参数**:
- `net.ipv4.tcp_keepalive_*`: TCP 保活配置
- `net.core.default_qdisc`: fq (公平队列)
- `net.ipv4.tcp_congestion_control`: bbr (拥塞控制算法)
- `net.ipv4.tcp_max_tw_buckets`: TIME_WAIT 连接数限制

**系统资源**:
- `vm.swappiness`: 0 (禁用 swap)
- `fs.file-max`: 4194304 (文件描述符上限)
- `fs.nr_open`: 4194304 (单进程文件描述符上限)
- `vm.dirty_ratio/dirty_background_ratio`: 脏页刷盘配置

#### 配置文件位置

- 优先使用: `/etc/sysctl.d/99-bsc-optimization.conf` (模块化配置)
- 备用: `/etc/sysctl.conf` (传统配置文件)

#### 应用方式

1. **立即应用**: 脚本会询问是否立即应用配置，选择 `y` 后配置会立即生效
2. **重启生效**: 如果选择不立即应用，配置会保存到文件，重启后自动生效
3. **手动应用**: 
   - 使用 `/etc/sysctl.d/`: `systemctl restart systemd-sysctl` 或 `sysctl -p /etc/sysctl.d/99-bsc-optimization.conf`
   - 使用 `/etc/sysctl.conf`: `sysctl -p /etc/sysctl.conf`

#### 自动加载机制

- `/etc/sysctl.d/` 目录下的配置文件会在系统启动时由 `systemd-sysctl.service` 自动加载
- 无需额外配置，系统会自动读取并应用这些配置

#### 验证配置

脚本执行完成后会自动验证所有配置参数，显示当前值与期望值的对比。

### 自定义用户名

创建用户模块会在执行时提示输入用户名：

- 用户名必须符合 Linux 用户名规范
- 只能包含小写字母、数字、下划线(_)、连字符(-)
- 必须以字母或下划线开头
- 不能以连字符结尾
- 长度限制: 1-32 个字符
- 默认用户名: `four`
- 如果之前设置过用户名，会自动读取作为默认值

## 注意事项

### 运行要求

- ⚠️ **必须以 root 权限运行**: `sudo ./tools.sh`
- ⚠️ **适用于 Debian/Ubuntu 系统**
- ⚠️ **需要网络连接**（下载软件包和源码）

### 安全提示

- 🔒 SSH 配置会禁用密码登录，请确保已准备好 SSH 公钥
- 🔒 防火墙配置默认禁止所有入站连接，请确认端口配置正确
- 🔒 建议在配置防火墙前先测试 SSH 连接

### 使用建议

- ✅ 每个模块可以独立运行，也可以跳过
- ✅ 如果某个模块执行失败，可以选择继续执行其他模块
- ✅ 建议先单独测试各个模块，确认无误后再使用"全部执行"
- ✅ 开发环境安装（Go、Rust、Node.js）支持为指定用户安装，建议先创建用户

### 故障排除

- **Go 安装失败**: 检查版本号是否正确，网络连接是否正常
- **Rust 安装失败**: 检查网络连接，确保可以访问 rustup.rs
- **Node.js 安装失败**: 检查网络连接，确保可以访问 GitHub 和 nvm 仓库
- **SSH 连接断开**: 检查防火墙配置，确保 SSH 端口 (22) 已开放
- **环境变量未生效**: 执行 `source ~/.bashrc` 或重新登录
- **sysctl 配置未生效**: 
  - 检查配置文件是否存在: `ls -l /etc/sysctl.d/99-bsc-optimization.conf`
  - 手动应用: `systemctl restart systemd-sysctl` 或 `sysctl -p <配置文件路径>`
  - 检查 BBR 模块: `lsmod | grep tcp_bbr`，如未加载则执行 `modprobe tcp_bbr`

## 许可证

本项目采用 MIT 许可证。

## 贡献

欢迎提交 Issue 和 Pull Request！
