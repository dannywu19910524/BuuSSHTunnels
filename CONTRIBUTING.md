# Contributing to Buu SSH Tunnels

Thank you for your interest in contributing! This guide will help you get started.

## Development Environment

- **macOS 13** (Ventura) or later
- **Swift 5.9+** (ships with Xcode 15+)
- Xcode 15+ or the Swift command-line tools

No additional dependencies are required — the project uses only Apple system frameworks.

## Build & Run

```bash
make build    # Build release binary and package .app bundle
make run      # Build and launch the app
make test     # Run unit tests
make dev      # Development run (swift run, debug build)
make clean    # Clean build artifacts
```

> **Note:** Before running `make run`, quit any existing instance of the app first (via the "退出" / Quit button in the menubar). macOS may reuse the old process otherwise.

## Project Structure

```
Sources/Tunnel/
├── TunnelApp.swift          # App entry point, NSStatusItem + NSPopover
├── Models/                  # Data types (TunnelConfig, TunnelState)
├── Services/                # Business logic
│   ├── ConfigStore.swift    # JSON persistence
│   ├── TunnelProcess.swift  # SSH process lifecycle
│   ├── TunnelManager.swift  # Coordinates all tunnels
│   ├── ReconnectPolicy.swift
│   ├── SSHCommand.swift     # Command parsing and sanitization
│   ├── NotificationService.swift
│   ├── LoginItemManager.swift
│   └── FileLogger.swift
└── Views/                   # SwiftUI views
    ├── TunnelListView.swift
    ├── TunnelRowView.swift
    ├── AddTunnelView.swift
    └── SettingsView.swift
```

## Code Style

- Follow existing patterns in the codebase
- SwiftUI views go in `Views/`, business logic in `Services/`, data types in `Models/`
- Use Swift standard naming conventions (camelCase for properties/methods, PascalCase for types)
- Keep files focused — one primary type per file

## Commit Convention

We use [Conventional Commits](https://www.conventionalcommits.org/):

```
feat: add tunnel group support
fix: prevent reconnect loop when ssh key is missing
chore: update minimum deployment target
docs: add troubleshooting section to README
test: add tests for ReconnectPolicy edge cases
```

- Use lowercase English
- Use imperative mood ("add" not "added" or "adds")
- Keep the subject line under 72 characters
- Add a body for non-trivial changes

## Submitting Issues

### Bug Reports

Please include:

1. **Steps to reproduce** — what you did
2. **Expected behavior** — what you expected to happen
3. **Actual behavior** — what actually happened
4. **macOS version** — e.g., macOS 14.2
5. **Log output** — check `~/Library/Application Support/Tunnel/tunnel.log`

### Feature Requests

Describe:

1. **The problem** — what are you trying to do?
2. **Proposed solution** — how do you think it should work?
3. **Alternatives considered** — any other approaches you thought of?

## Pull Requests

1. **Fork** the repository
2. **Create a feature branch** from `main`: `git checkout -b feat/my-feature`
3. **Make your changes** — keep commits focused and atomic
4. **Run tests**: `make test`
5. **Push** to your fork and open a PR against `main`

Guidelines:

- One PR per issue or feature
- All tests must pass (`make test`)
- Include a clear description of what changed and why
- If adding a new feature, add corresponding tests
