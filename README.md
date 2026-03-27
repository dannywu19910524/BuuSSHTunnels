# Buu SSH Tunnels

macOS 状态栏应用，管理 SSH Tunnel 连接。断了自动重连，开机自启动。

## 功能

- 状态栏常驻，不占 Dock 栏
- 粘贴完整 SSH 命令即可配置（如 `ssh -L 3306:localhost:3306 user@server`）
- 自动重连：指数退避（2s、4s、8s...上限 60s），最多重连 999 次（可配置）
- 每 30 次重连发送系统通知，达到上限时通知
- 开机自启动
- 点击 tunnel 展开查看错误日志
- 日志文件：`~/Library/Application Support/Tunnel/tunnel.log`

## 系统要求

- macOS 13 (Ventura) 或更高版本
- SSH key 认证（依赖系统 ssh-agent 和 `~/.ssh/config`）

## 安装

### 方式一：下载安装

1. 下载 `Buu SSH Tunnels.zip`
2. 解压得到 `Buu SSH Tunnels.app`
3. 拖到 `/Applications`（可选）
4. **右键 → 打开 → 确认**（首次需要这样绕过 Gatekeeper）

### 方式二：从源码构建

```bash
git clone <repo-url>
cd tunnel

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
4. 输入名称和 SSH 命令，点击添加
5. 用 Toggle 开关启停 tunnel
6. 点击 tunnel 行可展开查看错误日志
7. 右键 tunnel 可编辑或删除

### 状态栏图标

| 图标 | 含义 |
|------|------|
| 🔗 `network` | 正常 / 无 tunnel |
| 🔄 `arrow.triangle.2.circlepath` | 有 tunnel 正在重连 |
| ❌ `network.slash` | 有 tunnel 重连失败 |

### SSH 命令示例

```bash
# MySQL 端口转发
ssh -L 3306:localhost:3306 user@server

# Redis
ssh -L 6379:localhost:6379 user@server

# 指定 key 和端口
ssh -i ~/.ssh/mykey -p 2222 -L 8080:localhost:80 user@server
```

> 不需要加 `-f`、`-N`、`-T`，app 会自动处理。

### 配置文件

`~/Library/Application Support/Tunnel/config.json`

```json
{
  "tunnels": [
    {
      "id": "uuid",
      "name": "生产数据库",
      "command": "ssh -L 3306:localhost:3306 user@server",
      "autoConnect": true
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
