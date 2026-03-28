# Buu SSH Tunnels

<p align="center">
  <img src="Resources/AppIcon.icns" width="128" alt="Buu SSH Tunnels Icon">
</p>

A macOS menubar app for managing SSH tunnel connections with auto-reconnect.

[English](#features) | [中文](#功能)

## Features

- **Form-based tunnel creation** — no SSH command knowledge needed, with visual port forwarding display
- Also supports pasting raw SSH commands for advanced users
- Lives in the menubar — no Dock icon
- Auto-reconnect with exponential backoff (2s, 4s, 8s... capped at 60s), up to 999 retries (configurable)
- **Port conflict detection** — warns when ports are occupied, option to auto-kill blocking processes
- **Custom config file path** — store config on iCloud Drive for cross-device sync
- System notification every 30 reconnect attempts, and when the limit is reached
- Launch at login
- Click a tunnel row to expand and view error logs
- Log file: `~/Library/Application Support/Tunnel/tunnel.log`

## Requirements

- macOS 13 (Ventura) or later
- SSH key authentication (relies on system ssh-agent and `~/.ssh/config`)

## Installation

### Download

1. Download `Buu SSH Tunnels.zip` from [Releases](https://github.com/dannywu19910524/BuuSSHTunnels/releases)
2. Unzip to get `Buu SSH Tunnels.app`
3. Drag to `/Applications` (optional)
4. **Right-click → Open → Confirm** (required on first launch to bypass Gatekeeper)

### Build from Source

```bash
git clone https://github.com/dannywu19910524/BuuSSHTunnels.git
cd BuuSSHTunnels

# Build
make build

# Install to /Applications
make install

# Or run directly
make run
```

Other commands:

```bash
make test    # Run tests
make dev     # Development mode (swift run)
make clean   # Clean build artifacts
```

## Usage

1. After launch, a network icon appears in the menubar
2. Click the icon to open the management panel
3. Click **+ New Connection**
4. Fill in the form (host, user, port forwards) or switch to command mode
5. Use the toggle switch to start/stop a tunnel
6. Click a tunnel row to expand and view error logs
7. Right-click a tunnel to edit or delete

### Creating a Tunnel

**Form mode (default):** Fill in host, username, SSH port, and add port forwarding rules visually.

**Command mode:** Paste a full SSH command like `ssh -L 3306:localhost:3306 user@server`.

> No need to add `-f`, `-N`, or `-T` — the app handles these automatically.

### Menubar Icon

| Icon | Meaning |
|------|---------|
| `network` | Normal / no tunnels |
| `arrow.triangle.2.circlepath` | A tunnel is reconnecting |
| `network.slash` | A tunnel has failed to reconnect |

### SSH Command Examples

```bash
# MySQL port forwarding
ssh -L 3306:localhost:3306 user@server

# Redis
ssh -L 6379:localhost:6379 user@server

# Custom key and port
ssh -i ~/.ssh/mykey -p 2222 -L 8080:localhost:80 user@server
```

### Config File

Default: `~/Library/Application Support/Tunnel/config.json`

Can be changed in Settings to any path (e.g. iCloud Drive for cross-device sync).

```json
{
  "tunnels": [
    {
      "id": "uuid",
      "name": "Production DB",
      "command": "ssh -L 3306:localhost:3306 user@server",
      "autoConnect": true,
      "autoKillPortConflicts": false
    }
  ],
  "settings": {
    "maxRetries": 999,
    "launchAtLogin": false
  }
}
```

## Tech Stack

- Swift + SwiftUI
- Foundation (`Process`) for invoking system ssh
- UserNotifications (system notifications)
- ServiceManagement (launch at login)

## License

This project is licensed under the GPL-3.0 License — see the [LICENSE](LICENSE) file for details.

---

# Buu SSH Tunnels

<p align="center">
  <img src="Resources/AppIcon.icns" width="128" alt="Buu SSH Tunnels 图标">
</p>

macOS 状态栏应用，管理 SSH Tunnel 连接。断了自动重连，开机自启动。

## 功能

- **表单式隧道创建** — 无需手写 SSH 命令，端口转发可视化显示
- 同时支持粘贴原始 SSH 命令（高级用户）
- 状态栏常驻，不占 Dock 栏
- 自动重连：指数退避（2s、4s、8s...上限 60s），最多重连 999 次（可配置）
- **端口冲突检测** — 连接前检查端口占用，可选自动关闭占用进程
- **自定义配置文件路径** — 可存到 iCloud Drive 实现多设备同步
- 每 30 次重连发送系统通知，达到上限时通知
- 开机自启动
- 点击 tunnel 展开查看错误日志
- 日志文件：`~/Library/Application Support/Tunnel/tunnel.log`

## 系统要求

- macOS 13 (Ventura) 或更高版本
- SSH key 认证（依赖系统 ssh-agent 和 `~/.ssh/config`）

## 安装

### 下载安装

1. 从 [Releases](https://github.com/dannywu19910524/BuuSSHTunnels/releases) 下载 `Buu SSH Tunnels.zip`
2. 解压得到 `Buu SSH Tunnels.app`
3. 拖到 `/Applications`（可选）
4. **右键 → 打开 → 确认**（首次需要这样绕过 Gatekeeper）

### 从源码构建

```bash
git clone https://github.com/dannywu19910524/BuuSSHTunnels.git
cd BuuSSHTunnels

# 构建
make build

# 安装到 /Applications
make install

# 或直接运行
make run
```

其他命令：

```bash
make test    # 运行测试
make dev     # 开发模式（swift run）
make clean   # 清理构建产物
```

## 使用

1. 启动后状态栏出现网络图标
2. 点击图标打开管理面板
3. 点击 **+ 新建连接**
4. 填写表单（主机、用户名、端口转发）或切换到命令模式
5. 用 Toggle 开关启停 tunnel
6. 点击 tunnel 行可展开查看错误日志
7. 右键 tunnel 可编辑或删除

### 创建隧道

**表单模式（默认）：** 填写主机、用户名、SSH 端口，可视化添加端口转发规则。

**命令模式：** 粘贴完整 SSH 命令，如 `ssh -L 3306:localhost:3306 user@server`。

> 不需要加 `-f`、`-N`、`-T`，app 会自动处理。

### 状态栏图标

| 图标 | 含义 |
|------|------|
| `network` | 正常 / 无 tunnel |
| `arrow.triangle.2.circlepath` | 有 tunnel 正在重连 |
| `network.slash` | 有 tunnel 重连失败 |

### SSH 命令示例

```bash
# MySQL 端口转发
ssh -L 3306:localhost:3306 user@server

# Redis
ssh -L 6379:localhost:6379 user@server

# 指定 key 和端口
ssh -i ~/.ssh/mykey -p 2222 -L 8080:localhost:80 user@server
```

### 配置文件

默认路径：`~/Library/Application Support/Tunnel/config.json`

可在设置中更改为任意路径（如 iCloud Drive，实现多设备同步）。

```json
{
  "tunnels": [
    {
      "id": "uuid",
      "name": "生产数据库",
      "command": "ssh -L 3306:localhost:3306 user@server",
      "autoConnect": true,
      "autoKillPortConflicts": false
    }
  ],
  "settings": {
    "maxRetries": 999,
    "launchAtLogin": false
  }
}
```

## 技术栈

- Swift + SwiftUI
- Foundation (`Process`) 调用系统 ssh
- UserNotifications（系统通知）
- ServiceManagement（开机自启动）

## 许可证

本项目采用 GPL-3.0 许可证 — 详见 [LICENSE](LICENSE) 文件。
