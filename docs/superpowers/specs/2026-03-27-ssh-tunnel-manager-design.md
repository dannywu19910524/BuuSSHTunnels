# SSH Tunnel Manager — macOS 桌面应用设计文档

## 概述

一个 macOS menubar 常驻应用，用于管理多个 SSH tunnel 连接。支持自动重连、开机自启动、macOS 系统通知。用户通过粘贴完整 ssh 命令来配置 tunnel。

## 技术栈

- **语言/框架**：Swift + SwiftUI
- **最低系统版本**：macOS 13 (Ventura)
- **SSH 实现**：调用系统 `ssh` 进程（`Process` / NSTask）
- **认证方式**：SSH key（依赖系统 ssh-agent 和 ~/.ssh/config）
- **未来扩展**：iOS 支持（本期不实现）

## 架构

### 核心组件

| 组件 | 职责 |
|------|------|
| **TunnelManager** | 管理所有 tunnel 的生命周期（启动、停止、重连） |
| **TunnelProcess** | 单个 ssh 进程的封装，负责启动 Process、监控退出、触发重连 |
| **TunnelConfig** | 数据模型，存储用户配置的 ssh 命令、名称、是否自启等 |
| **ConfigStore** | 持久化层，JSON 文件读写 |
| **NotificationService** | 封装 UNUserNotificationCenter，发送系统通知 |

### 数据流

用户在 UI 添加/编辑 tunnel → ConfigStore 持久化 → TunnelManager 启动/管理 TunnelProcess → 进程异常退出 → 自动重连 → 触发通知条件 → NotificationService 发通知

## UI 设计

### 风格

macOS 原生风格（Apple HIG），浅色背景，圆角卡片，Toggle 开关。

### Menubar 图标

状态栏常驻 SF Symbol 图标，不同状态使用不同图标变体：
- **正常**：`cable.connector`（所有 tunnel 连接正常）
- **重连中**：`cable.connector.slash`（有 tunnel 正在重连）
- **失败**：`exclamationmark.cable.connector`（有 tunnel 重连失败）
- **无 tunnel**：`cable.connector`（无配置时的默认状态）

无 Dock 图标，不占任务栏空间（`LSUIElement = YES`）。

### 主界面（Popover）

点击 menubar 图标展开：
- **顶部**：标题 + 设置按钮
- **中部**：tunnel 列表，每条显示：
  - 名称
  - ssh 命令预览
  - 状态（已连接/重连中/失败）
  - 重连次数
  - Toggle 开关（启停）
- **底部**："+ 新建连接" 按钮、"退出" 按钮

### 添加/编辑/删除 Tunnel

- **名称**（可选，用于识别，如 "生产数据库"）
- **SSH 命令**（文本框，粘贴完整命令如 `ssh -L 3306:localhost:3306 user@server`）
- **自动连接开关**（app 启动时是否自动连接此 tunnel）
- **删除**：tunnel 列表中左滑或右键菜单删除，需确认

### 设置界面

- 开机自启动（全局开关）
- 最大重连次数（默认 999）

## 进程管理与重连策略

### SSH 进程管理

- 使用 `Process`（Foundation）通过 `/bin/sh -c "<用户的ssh命令>"` 执行，避免手动解析命令参数
- 为 ssh 命令自动追加 `-o ServerAliveInterval=15 -o ServerAliveCountMax=3 -o ExitOnForwardFailure=yes -N` 参数，保持连接活跃并在转发失败时退出
- 设置 `terminationHandler` 监听进程退出
- 捕获 stderr 输出，保留最近 50 行日志用于错误排查
- 每个 tunnel 独立管理自己的进程生命周期
- **连接成功判定**：ssh 进程启动后，检测本地转发端口是否开始监听（轮询检测，超时 10 秒），端口监听成功则判定为连接建立
- app 退出时 `SIGTERM` 所有子进程，优雅关闭

### 重连策略

- **触发条件**：ssh 进程异常退出（exit code ≠ 0）时触发重连；用户手动停止不触发
- **指数退避**：第 1 次立即重连，之后等待 2s、4s、8s...，上限 60s
- **成功重置**：连接成功后重置重连计数器和退避时间
- **最大次数**：达到可配置的最大重连次数（默认 999）时停止重连

### 通知规则

- 连续重连超过 **3 次** → 发送一次通知
- 之后每 **10 次**重连发送一次通知（第 13、23、33... 次）
- 达到最大重连次数 → 停止重连，发送最终通知
- 通知方式：macOS 系统通知（UNUserNotificationCenter）

### 健康检查

- 每 30 秒检查一次进程状态（`Process.isRunning`），防止漏检

## 数据持久化

### 配置文件

- **路径**：`~/Library/Application Support/Tunnel/config.json`
- **结构**：

```json
{
  "tunnels": [
    {
      "id": "uuid-string",
      "name": "生产数据库",
      "command": "ssh -L 3306:localhost:3306 user@prod",
      "autoConnect": true
    }
  ],
  "settings": {
    "maxRetries": 999,
    "launchAtLogin": true
  }
}
```

- 每次用户增删改 tunnel 或修改设置时写入
- app 启动时读取，自动连接 `autoConnect: true` 的 tunnel

### 开机自启动

- 使用 `SMAppService.mainApp`（macOS 13+ Login Items API）
- 用户在设置界面通过开关控制

## 沙箱与权限

- **关闭 App Sandbox**：需要访问 `~/.ssh/` 目录和启动 ssh 子进程，沙箱不兼容
- **通知权限**：首次启动时请求 UNUserNotificationCenter 授权
- **Hardened Runtime**：启用，但允许子进程执行（`com.apple.security.inherit`）

## 错误排查

- 每个 tunnel 保留最近 50 行 stderr 日志
- UI 中点击 tunnel 可展开查看最近的错误输出
- 连接失败时通知内容包含简要错误原因

## 约束与限制

- 仅支持 macOS 13+
- 仅支持 SSH key 认证（依赖系统 ssh）
- tunnel 数量上限 5 条（UI 设计针对少量 tunnel 优化）
- 不支持 App Sandbox（需要访问 ssh 和 ~/.ssh/）
- iOS 版本留待后续实现
