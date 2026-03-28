# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/),
and this project adheres to [Semantic Versioning](https://semver.org/).

## [1.1.0] - 2026-03-28

### Added

- Form-based tunnel creation UI — no need to write SSH commands manually
  - Visual port forwarding with color-coded display (local/remote/target)
  - Form mode (default) and command mode, switchable via segmented control
  - Auto-parse existing SSH commands into form fields when editing
  - Falls back to command mode for unsupported SSH flags (`-i`, `-D`, `-o`, etc.)
- Tunnel tags for future grouping/filtering
- Port conflict detection — warns when local ports are already in use before connecting
  - Shows blocking process PID and name
  - Per-tunnel option to auto-kill conflicting processes
- Custom config file path — store config on iCloud Drive for cross-device sync
  - Select an existing config file or a folder (auto-creates `config.json`)
  - Validates file format before accepting to prevent overwriting unrelated files
  - Path stored separately in local `path-settings.json`
- GPL-3.0 license
- Bilingual README (English / Chinese)
- Contributing guidelines

### Fixed

- Popover focus issue — clicking "新建连接" no longer traps focus and blocks other windows (replaced `.sheet` with inline view switching)

### 新增

- 表单式隧道创建 UI — 无需手写 SSH 命令
  - 端口转发可视化，颜色区分（本机/远程主机/目标主机）
  - 表单模式（默认）和命令模式，通过分段控件切换
  - 编辑已有隧道时自动解析 SSH 命令填充表单
  - 不支持的 SSH 参数（`-i`、`-D`、`-o` 等）自动回退到命令模式
- 隧道标签，为将来分组/筛选做准备
- 端口冲突检测 — 连接前检查本地端口是否被占用
  - 显示占用进程的 PID 和名称
  - 可为每个隧道单独配置自动关闭占用进程
- 自定义配置文件路径 — 可存放到 iCloud Drive 实现多设备同步
  - 支持选择已有配置文件或文件夹（自动创建 `config.json`）
  - 选择文件时验证格式，防止覆盖无关文件
  - 路径单独保存在本地 `path-settings.json`
- GPL-3.0 开源许可证
- 中英双语 README
- 贡献指南

### 修复

- 弹出面板焦点问题 — 点击"新建连接"后不再锁定焦点导致无法操作其他窗口（用视图切换替代 `.sheet`）

---

## [1.0.0] - 2026-03-28

### Added

- Menubar app with NSStatusItem + NSPopover
- SSH tunnel management — add, edit, and delete tunnels
- Auto-reconnect with exponential backoff (2s, 4s, 8s... capped at 60s)
- Configurable max retries (default 999)
- System notifications every 30 reconnect attempts and at retry limit
- Launch at login support via ServiceManagement
- File logging to `~/Library/Application Support/Tunnel/tunnel.log`
- JSON config persistence to `~/Library/Application Support/Tunnel/config.json`
- SSH command sanitization — strips `-f`, `-N`, `-T` flags, adds keepalive options

### 新增

- 状态栏应用（NSStatusItem + NSPopover）
- SSH 隧道管理 — 添加、编辑、删除隧道
- 自动重连，指数退避（2s、4s、8s...上限 60s）
- 可配置最大重连次数（默认 999）
- 每 30 次重连发送系统通知，达到上限时通知
- 开机自启动（ServiceManagement）
- 文件日志：`~/Library/Application Support/Tunnel/tunnel.log`
- JSON 配置持久化：`~/Library/Application Support/Tunnel/config.json`
- SSH 命令清理 — 自动去除 `-f`、`-N`、`-T` 参数，添加 keepalive 选项

### Fixed

- Strip `-f` flag from SSH commands to prevent background process breaking process management
- Port check false positive from orphaned processes (pre-listening port detection)
- Synchronous state update on tunnel stop (avoid deallocation race in terminationHandler)

### 修复

- 去除 SSH 命令中的 `-f` 参数，防止后台进程导致进程管理失效
- 端口检测误报（预记录已监听端口，排除孤儿进程干扰）
- 停止隧道时同步更新状态（避免 terminationHandler 的释放竞态）
