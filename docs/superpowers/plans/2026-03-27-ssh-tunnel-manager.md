# SSH Tunnel Manager Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a macOS menubar app that manages SSH tunnels with auto-reconnect, system notifications, and launch-at-login support.

**Architecture:** SwiftUI `MenuBarExtra` (macOS 13+) as the only Scene — no Dock icon. Each tunnel runs a system `ssh` process via `/bin/sh -c`. `TunnelProcess` monitors process lifecycle and reconnects with exponential backoff. `TunnelManager` coordinates all tunnels and triggers notifications. Persistence via JSON file in Application Support.

**Tech Stack:** Swift 5.9+, SwiftUI, Foundation (`Process`), UserNotifications (`UNUserNotificationCenter`), ServiceManagement (`SMAppService`)

---

## File Structure

```
tunnel/
├── Package.swift                             # SPM executable + test targets
├── Makefile                                  # Build, package .app, run, clean
├── Resources/
│   └── Info.plist                            # LSUIElement, bundle ID
├── Sources/
│   └── Tunnel/
│       ├── TunnelApp.swift                   # @main, MenuBarExtra, AppDelegate
│       ├── Models/
│       │   ├── TunnelConfig.swift            # TunnelConfig, AppSettings, AppConfig
│       │   └── TunnelState.swift             # TunnelStatus enum, TunnelState struct
│       ├── Services/
│       │   ├── ConfigStore.swift             # JSON file persistence
│       │   ├── ReconnectPolicy.swift         # Delay calculation, notification triggers
│       │   ├── SSHCommand.swift              # Command building, local port parsing
│       │   ├── TunnelProcess.swift           # Single ssh process lifecycle + reconnect
│       │   ├── TunnelManager.swift           # Coordinates all tunnels, health check
│       │   ├── NotificationService.swift     # UNUserNotificationCenter wrapper
│       │   └── LoginItemManager.swift        # SMAppService wrapper
│       └── Views/
│           ├── TunnelListView.swift          # Main popover: header, list, footer
│           ├── TunnelRowView.swift           # Single tunnel row with status
│           ├── AddTunnelView.swift           # Add/edit tunnel sheet
│           └── SettingsView.swift            # Settings sheet
└── Tests/
    └── TunnelTests/
        ├── TunnelConfigTests.swift
        ├── ConfigStoreTests.swift
        ├── ReconnectPolicyTests.swift
        └── SSHCommandTests.swift
```

---

### Task 1: Project Scaffolding

**Files:**
- Create: `Package.swift`
- Create: `Makefile`
- Create: `Resources/Info.plist`
- Create: `Sources/Tunnel/TunnelApp.swift` (placeholder)

- [ ] **Step 1: Create Package.swift**

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Tunnel",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "Tunnel",
            path: "Sources/Tunnel"
        ),
        .testTarget(
            name: "TunnelTests",
            dependencies: ["Tunnel"],
            path: "Tests/TunnelTests"
        )
    ]
)
```

- [ ] **Step 2: Create Resources/Info.plist**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>com.tunnel.app</string>
    <key>CFBundleName</key>
    <string>Tunnel</string>
    <key>CFBundleDisplayName</key>
    <string>Tunnel</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleExecutable</key>
    <string>Tunnel</string>
    <key>LSUIElement</key>
    <true/>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
</dict>
</plist>
```

- [ ] **Step 3: Create Makefile**

```makefile
APP_NAME = Tunnel
BUILD_DIR = .build/release
APP_BUNDLE = $(APP_NAME).app

.PHONY: build run clean test install

build:
	swift build -c release
	mkdir -p "$(APP_BUNDLE)/Contents/MacOS"
	mkdir -p "$(APP_BUNDLE)/Contents/Resources"
	cp "$(BUILD_DIR)/$(APP_NAME)" "$(APP_BUNDLE)/Contents/MacOS/"
	cp Resources/Info.plist "$(APP_BUNDLE)/Contents/"

run: build
	open "$(APP_BUNDLE)"

dev:
	swift run

test:
	swift test

clean:
	swift package clean
	rm -rf "$(APP_BUNDLE)"

install: build
	cp -r "$(APP_BUNDLE)" /Applications/
	@echo "Installed to /Applications/$(APP_BUNDLE)"
```

- [ ] **Step 4: Create minimal TunnelApp.swift to verify build**

```swift
import SwiftUI

@main
struct TunnelApp: App {
    var body: some Scene {
        MenuBarExtra("Tunnel", systemImage: "network") {
            Text("Hello Tunnel")
                .padding()
        }
        .menuBarExtraStyle(.window)
    }
}
```

- [ ] **Step 5: Verify build compiles**

Run: `swift build`
Expected: Build succeeds with no errors.

- [ ] **Step 6: Commit**

```bash
git add Package.swift Makefile Resources/Info.plist Sources/Tunnel/TunnelApp.swift
git commit -m "feat: scaffold project with SPM, Makefile, and minimal menubar app"
```

---

### Task 2: Data Models (TDD)

**Files:**
- Create: `Sources/Tunnel/Models/TunnelConfig.swift`
- Create: `Sources/Tunnel/Models/TunnelState.swift`
- Create: `Tests/TunnelTests/TunnelConfigTests.swift`

- [ ] **Step 1: Write failing tests for TunnelConfig**

```swift
// Tests/TunnelTests/TunnelConfigTests.swift
import XCTest
@testable import Tunnel

final class TunnelConfigTests: XCTestCase {

    func testTunnelConfigDefaultValues() {
        let config = TunnelConfig(name: "test", command: "ssh -L 3306:localhost:3306 user@host")
        XCTAssertFalse(config.id.uuidString.isEmpty)
        XCTAssertEqual(config.name, "test")
        XCTAssertEqual(config.command, "ssh -L 3306:localhost:3306 user@host")
        XCTAssertTrue(config.autoConnect)
    }

    func testTunnelConfigEncodeDecode() throws {
        let original = TunnelConfig(name: "DB", command: "ssh -L 3306:localhost:3306 prod", autoConnect: false)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TunnelConfig.self, from: data)
        XCTAssertEqual(decoded.id, original.id)
        XCTAssertEqual(decoded.name, original.name)
        XCTAssertEqual(decoded.command, original.command)
        XCTAssertEqual(decoded.autoConnect, original.autoConnect)
    }

    func testAppConfigEncodeDecode() throws {
        let tunnel = TunnelConfig(name: "Redis", command: "ssh -L 6379:localhost:6379 prod")
        let settings = AppSettings(maxRetries: 500, launchAtLogin: true)
        let original = AppConfig(tunnels: [tunnel], settings: settings)

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AppConfig.self, from: data)

        XCTAssertEqual(decoded.tunnels.count, 1)
        XCTAssertEqual(decoded.tunnels[0].name, "Redis")
        XCTAssertEqual(decoded.settings.maxRetries, 500)
        XCTAssertTrue(decoded.settings.launchAtLogin)
    }

    func testAppSettingsDefaults() {
        let settings = AppSettings()
        XCTAssertEqual(settings.maxRetries, 999)
        XCTAssertFalse(settings.launchAtLogin)
    }

    func testAppConfigDefaults() {
        let config = AppConfig()
        XCTAssertTrue(config.tunnels.isEmpty)
        XCTAssertEqual(config.settings.maxRetries, 999)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter TunnelConfigTests`
Expected: Compilation error — `TunnelConfig` not defined.

- [ ] **Step 3: Implement TunnelConfig.swift**

```swift
// Sources/Tunnel/Models/TunnelConfig.swift
import Foundation

struct TunnelConfig: Codable, Identifiable {
    var id: UUID
    var name: String
    var command: String
    var autoConnect: Bool

    init(id: UUID = UUID(), name: String = "", command: String = "", autoConnect: Bool = true) {
        self.id = id
        self.name = name
        self.command = command
        self.autoConnect = autoConnect
    }
}

struct AppSettings: Codable {
    var maxRetries: Int
    var launchAtLogin: Bool

    init(maxRetries: Int = 999, launchAtLogin: Bool = false) {
        self.maxRetries = maxRetries
        self.launchAtLogin = launchAtLogin
    }
}

struct AppConfig: Codable {
    var tunnels: [TunnelConfig]
    var settings: AppSettings

    init(tunnels: [TunnelConfig] = [], settings: AppSettings = AppSettings()) {
        self.tunnels = tunnels
        self.settings = settings
    }
}
```

- [ ] **Step 4: Implement TunnelState.swift**

```swift
// Sources/Tunnel/Models/TunnelState.swift
import Foundation

enum TunnelStatus: Equatable {
    case disconnected
    case connecting
    case connected
    case reconnecting(attempt: Int)
    case failed(reason: String)

    var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }

    var isReconnecting: Bool {
        if case .reconnecting = self { return true }
        return false
    }

    var isFailed: Bool {
        if case .failed = self { return true }
        return false
    }

    var isActive: Bool {
        switch self {
        case .connecting, .connected, .reconnecting: return true
        default: return false
        }
    }
}

struct TunnelState {
    var status: TunnelStatus = .disconnected
    var retryCount: Int = 0
    var recentLogs: [String] = []
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `swift test --filter TunnelConfigTests`
Expected: All 5 tests pass.

- [ ] **Step 6: Commit**

```bash
git add Sources/Tunnel/Models/ Tests/TunnelTests/TunnelConfigTests.swift
git commit -m "feat: add data models TunnelConfig, AppSettings, TunnelStatus"
```

---

### Task 3: ConfigStore (TDD)

**Files:**
- Create: `Sources/Tunnel/Services/ConfigStore.swift`
- Create: `Tests/TunnelTests/ConfigStoreTests.swift`

- [ ] **Step 1: Write failing tests for ConfigStore**

```swift
// Tests/TunnelTests/ConfigStoreTests.swift
import XCTest
@testable import Tunnel

final class ConfigStoreTests: XCTestCase {
    var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("TunnelTests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    func testLoadReturnsDefaultsWhenNoFile() {
        let store = ConfigStore(directory: tempDir)
        let config = store.load()
        XCTAssertTrue(config.tunnels.isEmpty)
        XCTAssertEqual(config.settings.maxRetries, 999)
    }

    func testSaveAndLoadRoundtrip() {
        let store = ConfigStore(directory: tempDir)
        let tunnel = TunnelConfig(name: "DB", command: "ssh -L 3306:localhost:3306 prod")
        let config = AppConfig(tunnels: [tunnel], settings: AppSettings(maxRetries: 100))
        store.save(config)

        let store2 = ConfigStore(directory: tempDir)
        let loaded = store2.load()
        XCTAssertEqual(loaded.tunnels.count, 1)
        XCTAssertEqual(loaded.tunnels[0].name, "DB")
        XCTAssertEqual(loaded.settings.maxRetries, 100)
    }

    func testSaveCreatesFile() {
        let store = ConfigStore(directory: tempDir)
        let config = AppConfig(tunnels: [], settings: AppSettings())
        store.save(config)

        let fileURL = tempDir.appendingPathComponent("config.json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
    }

    func testMultipleSavesOverwrite() {
        let store = ConfigStore(directory: tempDir)

        let config1 = AppConfig(tunnels: [TunnelConfig(name: "A", command: "ssh a")])
        store.save(config1)

        let config2 = AppConfig(tunnels: [
            TunnelConfig(name: "A", command: "ssh a"),
            TunnelConfig(name: "B", command: "ssh b")
        ])
        store.save(config2)

        let loaded = store.load()
        XCTAssertEqual(loaded.tunnels.count, 2)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter ConfigStoreTests`
Expected: Compilation error — `ConfigStore` not defined.

- [ ] **Step 3: Implement ConfigStore**

```swift
// Sources/Tunnel/Services/ConfigStore.swift
import Foundation

class ConfigStore {
    private let fileURL: URL

    init(directory: URL? = nil) {
        let dir = directory ?? FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first!.appendingPathComponent("Tunnel")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        self.fileURL = dir.appendingPathComponent("config.json")
    }

    func load() -> AppConfig {
        guard let data = try? Data(contentsOf: fileURL),
              let config = try? JSONDecoder().decode(AppConfig.self, from: data) else {
            return AppConfig()
        }
        return config
    }

    func save(_ config: AppConfig) {
        guard let data = try? JSONEncoder().encode(config) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter ConfigStoreTests`
Expected: All 4 tests pass.

- [ ] **Step 5: Commit**

```bash
git add Sources/Tunnel/Services/ConfigStore.swift Tests/TunnelTests/ConfigStoreTests.swift
git commit -m "feat: add ConfigStore for JSON persistence"
```

---

### Task 4: ReconnectPolicy and SSHCommand (TDD)

**Files:**
- Create: `Sources/Tunnel/Services/ReconnectPolicy.swift`
- Create: `Sources/Tunnel/Services/SSHCommand.swift`
- Create: `Tests/TunnelTests/ReconnectPolicyTests.swift`
- Create: `Tests/TunnelTests/SSHCommandTests.swift`

- [ ] **Step 1: Write failing tests for ReconnectPolicy**

```swift
// Tests/TunnelTests/ReconnectPolicyTests.swift
import XCTest
@testable import Tunnel

final class ReconnectPolicyTests: XCTestCase {

    func testDelayForFirstAttemptIsZero() {
        XCTAssertEqual(ReconnectPolicy.delay(forAttempt: 0), 0)
    }

    func testDelayExponentialBackoff() {
        XCTAssertEqual(ReconnectPolicy.delay(forAttempt: 1), 2)
        XCTAssertEqual(ReconnectPolicy.delay(forAttempt: 2), 4)
        XCTAssertEqual(ReconnectPolicy.delay(forAttempt: 3), 8)
        XCTAssertEqual(ReconnectPolicy.delay(forAttempt: 5), 32)
    }

    func testDelayCapsAt60() {
        XCTAssertEqual(ReconnectPolicy.delay(forAttempt: 6), 60) // 2^6=64 > 60
        XCTAssertEqual(ReconnectPolicy.delay(forAttempt: 10), 60)
        XCTAssertEqual(ReconnectPolicy.delay(forAttempt: 100), 60)
    }

    func testShouldNotifyAtThree() {
        XCTAssertFalse(ReconnectPolicy.shouldNotify(retryCount: 1))
        XCTAssertFalse(ReconnectPolicy.shouldNotify(retryCount: 2))
        XCTAssertTrue(ReconnectPolicy.shouldNotify(retryCount: 3))
    }

    func testShouldNotifyEveryTenAfterThree() {
        XCTAssertFalse(ReconnectPolicy.shouldNotify(retryCount: 4))
        XCTAssertFalse(ReconnectPolicy.shouldNotify(retryCount: 12))
        XCTAssertTrue(ReconnectPolicy.shouldNotify(retryCount: 13))
        XCTAssertFalse(ReconnectPolicy.shouldNotify(retryCount: 14))
        XCTAssertTrue(ReconnectPolicy.shouldNotify(retryCount: 23))
        XCTAssertTrue(ReconnectPolicy.shouldNotify(retryCount: 33))
        XCTAssertTrue(ReconnectPolicy.shouldNotify(retryCount: 993))
    }

    func testShouldNotifyNeverAtZero() {
        XCTAssertFalse(ReconnectPolicy.shouldNotify(retryCount: 0))
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter ReconnectPolicyTests`
Expected: Compilation error — `ReconnectPolicy` not defined.

- [ ] **Step 3: Implement ReconnectPolicy**

```swift
// Sources/Tunnel/Services/ReconnectPolicy.swift
import Foundation

enum ReconnectPolicy {
    /// Returns delay in seconds before the given retry attempt.
    /// Attempt 0 = immediate, then 2s, 4s, 8s, ..., capped at 60s.
    static func delay(forAttempt attempt: Int) -> TimeInterval {
        guard attempt > 0 else { return 0 }
        return min(pow(2.0, Double(attempt)), 60.0)
    }

    /// Returns true at retry counts that should trigger a notification:
    /// count 3, then every 10 after (13, 23, 33, ...).
    static func shouldNotify(retryCount: Int) -> Bool {
        guard retryCount >= 3 else { return false }
        return (retryCount - 3) % 10 == 0
    }
}
```

- [ ] **Step 4: Run ReconnectPolicy tests**

Run: `swift test --filter ReconnectPolicyTests`
Expected: All 6 tests pass.

- [ ] **Step 5: Write failing tests for SSHCommand**

```swift
// Tests/TunnelTests/SSHCommandTests.swift
import XCTest
@testable import Tunnel

final class SSHCommandTests: XCTestCase {

    // MARK: - parseLocalPorts

    func testParseSingleLocalForward() {
        let ports = SSHCommand.parseLocalPorts(from: "ssh -L 3306:localhost:3306 user@host")
        XCTAssertEqual(ports, [3306])
    }

    func testParseLocalForwardWithBindAddress() {
        let ports = SSHCommand.parseLocalPorts(from: "ssh -L 0.0.0.0:8080:localhost:80 user@host")
        XCTAssertEqual(ports, [8080])
    }

    func testParseMultipleLocalForwards() {
        let ports = SSHCommand.parseLocalPorts(from: "ssh -L 3306:db:3306 -L 6379:redis:6379 user@host")
        XCTAssertEqual(ports, [3306, 6379])
    }

    func testParseNoPortFlags() {
        let ports = SSHCommand.parseLocalPorts(from: "ssh user@host")
        XCTAssertTrue(ports.isEmpty)
    }

    func testParseRemoteForwardIgnored() {
        let ports = SSHCommand.parseLocalPorts(from: "ssh -R 8080:localhost:80 user@host")
        XCTAssertTrue(ports.isEmpty)
    }

    // MARK: - buildFullCommand

    func testBuildFullCommandInsertsOptions() {
        let cmd = SSHCommand.buildFullCommand(from: "ssh -L 3306:localhost:3306 user@host")
        XCTAssertTrue(cmd.contains("-o ServerAliveInterval=15"))
        XCTAssertTrue(cmd.contains("-o ServerAliveCountMax=3"))
        XCTAssertTrue(cmd.contains("-o ExitOnForwardFailure=yes"))
        XCTAssertTrue(cmd.contains("-N"))
        XCTAssertTrue(cmd.contains("-L 3306:localhost:3306 user@host"))
    }

    func testBuildFullCommandPreservesOriginalArgs() {
        let cmd = SSHCommand.buildFullCommand(from: "ssh -i ~/.ssh/key -L 80:localhost:80 user@host")
        XCTAssertTrue(cmd.contains("-i ~/.ssh/key"))
        XCTAssertTrue(cmd.contains("-L 80:localhost:80"))
    }
}
```

- [ ] **Step 6: Run tests to verify they fail**

Run: `swift test --filter SSHCommandTests`
Expected: Compilation error — `SSHCommand` not defined.

- [ ] **Step 7: Implement SSHCommand**

```swift
// Sources/Tunnel/Services/SSHCommand.swift
import Foundation

enum SSHCommand {
    private static let extraOptions = "-o ServerAliveInterval=15 -o ServerAliveCountMax=3 -o ExitOnForwardFailure=yes -N"

    /// Inserts keepalive options and -N after the ssh binary name.
    static func buildFullCommand(from userCommand: String) -> String {
        let trimmed = userCommand.trimmingCharacters(in: .whitespaces)
        guard let firstSpace = trimmed.firstIndex(of: " ") else { return trimmed }
        let binary = trimmed[..<firstSpace]
        let rest = trimmed[firstSpace...]
        return "\(binary) \(extraOptions)\(rest)"
    }

    /// Parses -L flags to extract local forwarding ports.
    static func parseLocalPorts(from command: String) -> [UInt16] {
        let args = command.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        var ports: [UInt16] = []
        var i = 0
        while i < args.count {
            if args[i] == "-L", i + 1 < args.count {
                i += 1
                let parts = args[i].split(separator: ":")
                // -L port:host:hostport  OR  -L bind:port:host:hostport
                let portStr: Substring
                if parts.count == 3 {
                    portStr = parts[0]
                } else if parts.count == 4 {
                    portStr = parts[1]
                } else {
                    i += 1; continue
                }
                if let port = UInt16(portStr) {
                    ports.append(port)
                }
            }
            i += 1
        }
        return ports
    }

    /// Checks if a TCP port is accepting connections on localhost.
    static func isPortListening(_ port: UInt16) -> Bool {
        let sock = socket(AF_INET, SOCK_STREAM, 0)
        guard sock >= 0 else { return false }
        defer { close(sock) }

        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = port.bigEndian
        addr.sin_addr.s_addr = inet_addr("127.0.0.1")

        return withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                connect(sock, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        } == 0
    }
}
```

- [ ] **Step 8: Run all tests**

Run: `swift test --filter SSHCommandTests`
Expected: All 7 tests pass.

- [ ] **Step 9: Run full test suite**

Run: `swift test`
Expected: All tests pass (TunnelConfigTests + ConfigStoreTests + ReconnectPolicyTests + SSHCommandTests).

- [ ] **Step 10: Commit**

```bash
git add Sources/Tunnel/Services/ReconnectPolicy.swift Sources/Tunnel/Services/SSHCommand.swift Tests/TunnelTests/ReconnectPolicyTests.swift Tests/TunnelTests/SSHCommandTests.swift
git commit -m "feat: add ReconnectPolicy and SSHCommand with tests"
```

---

### Task 5: NotificationService and LoginItemManager

**Files:**
- Create: `Sources/Tunnel/Services/NotificationService.swift`
- Create: `Sources/Tunnel/Services/LoginItemManager.swift`

- [ ] **Step 1: Implement NotificationService**

```swift
// Sources/Tunnel/Services/NotificationService.swift
import Foundation
import UserNotifications

class NotificationService: NSObject, UNUserNotificationCenterDelegate {
    override init() {
        super.init()
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func send(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    // Show notifications even when app is frontmost
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
```

- [ ] **Step 2: Implement LoginItemManager**

```swift
// Sources/Tunnel/Services/LoginItemManager.swift
import ServiceManagement

enum LoginItemManager {
    static func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("Login item error: \(error)")
        }
    }

    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }
}
```

- [ ] **Step 3: Verify build**

Run: `swift build`
Expected: Build succeeds.

- [ ] **Step 4: Commit**

```bash
git add Sources/Tunnel/Services/NotificationService.swift Sources/Tunnel/Services/LoginItemManager.swift
git commit -m "feat: add NotificationService and LoginItemManager"
```

---

### Task 6: TunnelProcess

**Files:**
- Create: `Sources/Tunnel/Services/TunnelProcess.swift`

- [ ] **Step 1: Implement TunnelProcess**

```swift
// Sources/Tunnel/Services/TunnelProcess.swift
import Foundation

class TunnelProcess {
    let tunnelId: UUID
    let command: String
    private(set) var retryCount: Int = 0
    private(set) var recentLogs: [String] = []

    private var process: Process?
    private var stderrPipe: Pipe?
    private var manualStop = false
    private var maxRetries: Int
    private var reconnectTask: DispatchWorkItem?

    var isRunning: Bool { process?.isRunning ?? false }
    var onStateChange: ((TunnelState) -> Void)?

    init(tunnelId: UUID, command: String, maxRetries: Int) {
        self.tunnelId = tunnelId
        self.command = command
        self.maxRetries = maxRetries
    }

    func start() {
        manualStop = false
        retryCount = 0
        recentLogs = []
        launchProcess()
    }

    func stop() {
        manualStop = true
        reconnectTask?.cancel()
        reconnectTask = nil
        if let proc = process, proc.isRunning {
            proc.terminate()
        }
    }

    func updateMaxRetries(_ value: Int) {
        maxRetries = value
    }

    // MARK: - Private

    private func launchProcess() {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/sh")
        proc.arguments = ["-c", SSHCommand.buildFullCommand(from: command)]

        let pipe = Pipe()
        proc.standardError = pipe
        proc.standardOutput = FileHandle.nullDevice

        proc.terminationHandler = { [weak self] p in
            DispatchQueue.main.async {
                self?.handleTermination(exitCode: p.terminationStatus)
            }
        }

        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            DispatchQueue.main.async {
                self?.appendLog(text)
            }
        }

        self.process = proc
        self.stderrPipe = pipe
        notifyState(.connecting)

        do {
            try proc.run()
            checkConnection()
        } catch {
            appendLog("Failed to start: \(error.localizedDescription)")
            notifyState(.failed(reason: error.localizedDescription))
        }
    }

    private func checkConnection() {
        let ports = SSHCommand.parseLocalPorts(from: command)

        if ports.isEmpty {
            // No local ports to check — assume connected after 3s if still running
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                guard let self, self.process?.isRunning == true else { return }
                self.retryCount = 0
                self.notifyState(.connected)
            }
            return
        }

        // Poll for ports listening, up to 10 seconds
        var checks = 0
        let maxChecks = 20

        func poll() {
            guard self.process?.isRunning == true, !self.manualStop else { return }

            if ports.allSatisfy({ SSHCommand.isPortListening($0) }) {
                self.retryCount = 0
                self.notifyState(.connected)
                return
            }

            checks += 1
            if checks >= maxChecks {
                // Timeout but process alive — consider connected
                self.retryCount = 0
                self.notifyState(.connected)
                return
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { poll() }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { poll() }
    }

    private func handleTermination(exitCode: Int32) {
        stderrPipe?.fileHandleForReading.readabilityHandler = nil
        process = nil

        guard !manualStop else {
            notifyState(.disconnected)
            return
        }

        // exit code 0 can happen with -N when server closes cleanly; still reconnect
        retryCount += 1

        if retryCount >= maxRetries {
            notifyState(.failed(reason: "已达到最大重连次数 (\(maxRetries))"))
            return
        }

        scheduleReconnect()
    }

    private func scheduleReconnect() {
        let delay = ReconnectPolicy.delay(forAttempt: retryCount)
        notifyState(.reconnecting(attempt: retryCount))

        let task = DispatchWorkItem { [weak self] in
            self?.launchProcess()
        }
        self.reconnectTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: task)
    }

    private func appendLog(_ text: String) {
        let lines = text.components(separatedBy: .newlines).filter { !$0.isEmpty }
        recentLogs.append(contentsOf: lines)
        if recentLogs.count > 50 {
            recentLogs = Array(recentLogs.suffix(50))
        }
    }

    private func notifyState(_ status: TunnelStatus) {
        let state = TunnelState(status: status, retryCount: retryCount, recentLogs: recentLogs)
        onStateChange?(state)
    }
}
```

- [ ] **Step 2: Verify build**

Run: `swift build`
Expected: Build succeeds.

- [ ] **Step 3: Commit**

```bash
git add Sources/Tunnel/Services/TunnelProcess.swift
git commit -m "feat: add TunnelProcess with ssh lifecycle and auto-reconnect"
```

---

### Task 7: TunnelManager

**Files:**
- Create: `Sources/Tunnel/Services/TunnelManager.swift`

- [ ] **Step 1: Implement TunnelManager**

```swift
// Sources/Tunnel/Services/TunnelManager.swift
import Foundation
import Combine

class TunnelManager: ObservableObject {
    @Published var tunnels: [TunnelConfig] = []
    @Published var settings: AppSettings = AppSettings()
    @Published private(set) var tunnelStates: [UUID: TunnelState] = [:]

    private let store: ConfigStore
    private var processes: [UUID: TunnelProcess] = [:]
    private var healthCheckTimer: Timer?
    private let notificationService = NotificationService()
    private var lastNotifiedRetry: [UUID: Int] = [:]

    var menuBarIcon: String {
        let states = tunnelStates.values
        if states.contains(where: { $0.status.isFailed }) {
            return "network.slash"
        }
        if states.contains(where: { $0.status.isReconnecting }) {
            return "arrow.triangle.2.circlepath"
        }
        return "network"
    }

    init(store: ConfigStore = ConfigStore()) {
        self.store = store
        let config = store.load()
        self.tunnels = config.tunnels
        self.settings = config.settings
        startHealthCheck()
        autoConnect()

        NotificationCenter.default.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.stopAll()
        }
    }

    func autoConnect() {
        for tunnel in tunnels where tunnel.autoConnect {
            guard processes[tunnel.id] == nil else { continue }
            startTunnel(id: tunnel.id)
        }
    }

    // MARK: - Tunnel CRUD

    func addTunnel(_ tunnel: TunnelConfig) {
        tunnels.append(tunnel)
        persistConfig()
    }

    func updateTunnel(_ tunnel: TunnelConfig) {
        guard let index = tunnels.firstIndex(where: { $0.id == tunnel.id }) else { return }
        let wasRunning = processes[tunnel.id] != nil
        if wasRunning { stopTunnel(id: tunnel.id) }
        tunnels[index] = tunnel
        persistConfig()
        if wasRunning { startTunnel(id: tunnel.id) }
    }

    func removeTunnel(id: UUID) {
        stopTunnel(id: id)
        tunnels.removeAll { $0.id == id }
        tunnelStates.removeValue(forKey: id)
        lastNotifiedRetry.removeValue(forKey: id)
        persistConfig()
    }

    func updateSettings(_ newSettings: AppSettings) {
        settings = newSettings
        for proc in processes.values {
            proc.updateMaxRetries(newSettings.maxRetries)
        }
        persistConfig()
    }

    // MARK: - Tunnel Control

    func startTunnel(id: UUID) {
        guard let config = tunnels.first(where: { $0.id == id }) else { return }
        stopTunnel(id: id)

        let proc = TunnelProcess(tunnelId: id, command: config.command, maxRetries: settings.maxRetries)
        proc.onStateChange = { [weak self] state in
            self?.handleStateChange(tunnelId: id, state: state)
        }
        processes[id] = proc
        proc.start()
    }

    func stopTunnel(id: UUID) {
        processes[id]?.stop()
        processes.removeValue(forKey: id)
    }

    func stopAll() {
        for id in processes.keys {
            processes[id]?.stop()
        }
        processes.removeAll()
    }

    // MARK: - Private

    private func handleStateChange(tunnelId: UUID, state: TunnelState) {
        tunnelStates[tunnelId] = state
        let tunnelName = tunnels.first(where: { $0.id == tunnelId })?.name ?? "Tunnel"
        let displayName = tunnelName.isEmpty ? "Tunnel" : tunnelName

        // Notification: at retry 3, then every 10 (13, 23, 33...)
        if ReconnectPolicy.shouldNotify(retryCount: state.retryCount) {
            let prev = lastNotifiedRetry[tunnelId] ?? 0
            if state.retryCount > prev {
                notificationService.send(
                    title: "SSH Tunnel 重连中",
                    body: "\(displayName) 已重连 \(state.retryCount) 次"
                )
                lastNotifiedRetry[tunnelId] = state.retryCount
            }
        }

        // Notification: final failure
        if case .failed(let reason) = state.status {
            notificationService.send(
                title: "SSH Tunnel 已停止",
                body: "\(displayName): \(reason)"
            )
        }

        // Reset notification tracking on successful connection
        if state.status.isConnected {
            lastNotifiedRetry[tunnelId] = 0
        }
    }

    private func startHealthCheck() {
        healthCheckTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.performHealthCheck()
        }
    }

    private func performHealthCheck() {
        for (id, proc) in processes {
            guard let state = tunnelStates[id] else { continue }
            if state.status.isConnected && !proc.isRunning {
                startTunnel(id: id)
            }
        }
    }

    private func persistConfig() {
        store.save(AppConfig(tunnels: tunnels, settings: settings))
    }

    deinit {
        healthCheckTimer?.invalidate()
    }
}
```

- [ ] **Step 2: Verify build**

Run: `swift build`
Expected: Build succeeds.

- [ ] **Step 3: Commit**

```bash
git add Sources/Tunnel/Services/TunnelManager.swift
git commit -m "feat: add TunnelManager to coordinate tunnels, health check, and notifications"
```

---

### Task 8: App Entry Point and MenuBar

**Files:**
- Modify: `Sources/Tunnel/TunnelApp.swift`

- [ ] **Step 1: Update TunnelApp.swift**

Replace the entire file content:

```swift
// Sources/Tunnel/TunnelApp.swift
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.accessory)
    }
}

@main
struct TunnelApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var manager = TunnelManager()

    var body: some Scene {
        MenuBarExtra {
            TunnelListView()
                .environmentObject(manager)
        } label: {
            Image(systemName: manager.menuBarIcon)
        }
        .menuBarExtraStyle(.window)
    }

    // autoConnect is called in TunnelManager.init() — no action needed here
}
```

- [ ] **Step 2: Verify build**

Run: `swift build`
Expected: Build may fail because `TunnelListView` doesn't exist yet. That's OK — we'll create it next.

- [ ] **Step 3: Commit (if build succeeds, otherwise defer)**

```bash
git add Sources/Tunnel/TunnelApp.swift
git commit -m "feat: configure app entry point with MenuBarExtra and AppDelegate"
```

---

### Task 9: TunnelListView and TunnelRowView

**Files:**
- Create: `Sources/Tunnel/Views/TunnelListView.swift`
- Create: `Sources/Tunnel/Views/TunnelRowView.swift`

- [ ] **Step 1: Implement TunnelRowView**

```swift
// Sources/Tunnel/Views/TunnelRowView.swift
import SwiftUI

struct TunnelRowView: View {
    let tunnel: TunnelConfig
    let onEdit: () -> Void
    @EnvironmentObject var manager: TunnelManager
    @State private var showLogs = false
    @State private var showDeleteAlert = false

    private var state: TunnelState {
        manager.tunnelStates[tunnel.id] ?? TunnelState()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)

                VStack(alignment: .leading, spacing: 2) {
                    Text(tunnel.name.isEmpty ? "Untitled" : tunnel.name)
                        .font(.system(size: 13, weight: .medium))

                    Text(tunnel.command)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                if state.retryCount > 0 && state.status.isActive {
                    Text("重连 \(state.retryCount)")
                        .font(.system(size: 10))
                        .foregroundColor(.orange)
                }

                Toggle("", isOn: Binding(
                    get: { state.status.isActive },
                    set: { newValue in
                        if newValue {
                            manager.startTunnel(id: tunnel.id)
                        } else {
                            manager.stopTunnel(id: tunnel.id)
                        }
                    }
                ))
                .toggleStyle(.switch)
                .controlSize(.small)
                .labelsHidden()
            }

            // Expandable error log
            if showLogs && !state.recentLogs.isEmpty {
                ScrollView {
                    Text(state.recentLogs.joined(separator: "\n"))
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                .frame(maxHeight: 80)
                .padding(6)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(4)
            }
        }
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(borderColor, lineWidth: 1)
        )
        .onTapGesture { showLogs.toggle() }
        .contextMenu {
            Button("编辑") { onEdit() }
            Divider()
            Button("删除", role: .destructive) { showDeleteAlert = true }
        }
        .alert("确定删除?", isPresented: $showDeleteAlert) {
            Button("删除", role: .destructive) { manager.removeTunnel(id: tunnel.id) }
            Button("取消", role: .cancel) {}
        } message: {
            Text("将删除 \"\(tunnel.name.isEmpty ? "Untitled" : tunnel.name)\"")
        }
    }

    private var statusColor: Color {
        switch state.status {
        case .disconnected: return .gray
        case .connecting: return .yellow
        case .connected: return .green
        case .reconnecting: return .orange
        case .failed: return .red
        }
    }

    private var borderColor: Color {
        switch state.status {
        case .failed: return .red.opacity(0.3)
        case .reconnecting: return .orange.opacity(0.3)
        default: return Color(nsColor: .separatorColor)
        }
    }
}
```

- [ ] **Step 2: Implement TunnelListView**

```swift
// Sources/Tunnel/Views/TunnelListView.swift
import SwiftUI

struct TunnelListView: View {
    @EnvironmentObject var manager: TunnelManager
    @State private var activeSheet: SheetType?

    enum SheetType: Identifiable {
        case add
        case edit(TunnelConfig)
        case settings

        var id: String {
            switch self {
            case .add: return "add"
            case .edit(let t): return t.id.uuidString
            case .settings: return "settings"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Tunnel Manager")
                    .font(.headline)
                Spacer()
                Button { activeSheet = .settings } label: {
                    Image(systemName: "gear")
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            // Content
            if manager.tunnels.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "network")
                        .font(.system(size: 24))
                        .foregroundColor(.secondary)
                    Text("没有配置的连接")
                        .foregroundColor(.secondary)
                        .font(.system(size: 13))
                }
                .frame(maxWidth: .infinity, minHeight: 100)
            } else {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(manager.tunnels) { tunnel in
                            TunnelRowView(tunnel: tunnel, onEdit: {
                                activeSheet = .edit(tunnel)
                            })
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
                .frame(maxHeight: 350)
            }

            Divider()

            // Footer
            HStack {
                Button { activeSheet = .add } label: {
                    Label("新建连接", systemImage: "plus")
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .foregroundColor(.accentColor)

                Spacer()

                Button("退出") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
                .font(.system(size: 12))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .frame(width: 360)
        .sheet(item: $activeSheet) { sheet in
            Group {
                switch sheet {
                case .add:
                    AddTunnelView()
                case .edit(let tunnel):
                    AddTunnelView(editingTunnel: tunnel)
                case .settings:
                    SettingsView()
                }
            }
            .environmentObject(manager)
        }
    }
}
```

- [ ] **Step 3: Verify build**

Run: `swift build`
Expected: Build may fail — `AddTunnelView` and `SettingsView` don't exist yet. Continue to next task.

- [ ] **Step 4: Commit (defer until all views compile)**

---

### Task 10: AddTunnelView

**Files:**
- Create: `Sources/Tunnel/Views/AddTunnelView.swift`

- [ ] **Step 1: Implement AddTunnelView**

```swift
// Sources/Tunnel/Views/AddTunnelView.swift
import SwiftUI

struct AddTunnelView: View {
    @EnvironmentObject var manager: TunnelManager
    @Environment(\.dismiss) var dismiss

    var editingTunnel: TunnelConfig?

    @State private var name: String = ""
    @State private var command: String = ""
    @State private var autoConnect: Bool = true

    private var isEditing: Bool { editingTunnel != nil }

    private var isValid: Bool {
        !command.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(spacing: 16) {
            Text(isEditing ? "编辑连接" : "新建连接")
                .font(.headline)

            VStack(alignment: .leading, spacing: 4) {
                Text("名称")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                TextField("例如: 生产数据库", text: $name)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("SSH 命令")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                TextField("ssh -L 3306:localhost:3306 user@server", text: $command)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13, design: .monospaced))
            }

            Toggle("启动时自动连接", isOn: $autoConnect)
                .font(.system(size: 13))

            HStack {
                Button("取消") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button(isEditing ? "保存" : "添加") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!isValid)
            }
        }
        .padding(20)
        .frame(width: 420)
        .onAppear {
            if let tunnel = editingTunnel {
                name = tunnel.name
                command = tunnel.command
                autoConnect = tunnel.autoConnect
            }
        }
    }

    private func save() {
        let trimmedCommand = command.trimmingCharacters(in: .whitespaces)
        if var tunnel = editingTunnel {
            tunnel.name = name
            tunnel.command = trimmedCommand
            tunnel.autoConnect = autoConnect
            manager.updateTunnel(tunnel)
        } else {
            let tunnel = TunnelConfig(
                name: name,
                command: trimmedCommand,
                autoConnect: autoConnect
            )
            manager.addTunnel(tunnel)
        }
        dismiss()
    }
}
```

- [ ] **Step 2: Verify build (still needs SettingsView)**

---

### Task 11: SettingsView

**Files:**
- Create: `Sources/Tunnel/Views/SettingsView.swift`

- [ ] **Step 1: Implement SettingsView**

```swift
// Sources/Tunnel/Views/SettingsView.swift
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var manager: TunnelManager
    @Environment(\.dismiss) var dismiss

    @State private var maxRetriesText: String = ""
    @State private var launchAtLogin: Bool = false

    var body: some View {
        VStack(spacing: 16) {
            Text("设置")
                .font(.headline)

            VStack(spacing: 12) {
                Toggle("开机自启动", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { newValue in
                        var s = manager.settings
                        s.launchAtLogin = newValue
                        manager.updateSettings(s)
                        LoginItemManager.setEnabled(newValue)
                    }

                HStack {
                    Text("最大重连次数")
                    Spacer()
                    TextField("999", text: $maxRetriesText)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                        .multilineTextAlignment(.trailing)
                        .onSubmit { applyMaxRetries() }
                }
            }
            .font(.system(size: 13))

            Spacer().frame(height: 4)

            Button("完成") {
                applyMaxRetries()
                dismiss()
            }
            .keyboardShortcut(.defaultAction)
        }
        .padding(20)
        .frame(width: 300)
        .onAppear {
            maxRetriesText = String(manager.settings.maxRetries)
            launchAtLogin = manager.settings.launchAtLogin
        }
    }

    private func applyMaxRetries() {
        guard let value = Int(maxRetriesText), value > 0 else {
            maxRetriesText = String(manager.settings.maxRetries)
            return
        }
        var s = manager.settings
        s.maxRetries = value
        manager.updateSettings(s)
    }
}
```

- [ ] **Step 2: Build the full project**

Run: `swift build`
Expected: Build succeeds — all files compile.

- [ ] **Step 3: Run all tests**

Run: `swift test`
Expected: All tests pass.

- [ ] **Step 4: Commit all view files and TunnelApp update**

```bash
git add Sources/Tunnel/TunnelApp.swift Sources/Tunnel/Views/
git commit -m "feat: add SwiftUI views — TunnelList, TunnelRow, AddTunnel, Settings"
```

---

### Task 12: Build .app Bundle and Integration Verification

**Files:**
- No new files

- [ ] **Step 1: Build the .app bundle**

Run: `make build`
Expected: `Tunnel.app` created in project root with `Contents/MacOS/Tunnel` binary and `Contents/Info.plist`.

- [ ] **Step 2: Verify .app structure**

Run: `ls -la Tunnel.app/Contents/ && ls -la Tunnel.app/Contents/MacOS/`
Expected: Shows `Info.plist` and `Tunnel` executable.

- [ ] **Step 3: Launch and smoke test**

Run: `make run`
Expected: App launches, menubar icon (network) appears, no Dock icon. Click menubar icon → popover shows "没有配置的连接" with "+ 新建连接" and "退出" buttons.

Manual verification checklist:
1. Click "+ 新建连接" → Add tunnel sheet opens
2. Enter name "Test" and command `ssh -L 8888:localhost:80 user@host` → click "添加"
3. Tunnel appears in list with toggle OFF (disconnected, gray dot)
4. Toggle ON → status changes to "connecting" (yellow dot)
5. If ssh fails → status shows reconnecting with retry count
6. Click tunnel row → expands to show error logs
7. Right-click tunnel → context menu shows "编辑" and "删除"
8. Click "删除" → confirmation dialog appears
9. Open Settings → verify "开机自启动" toggle and max retries field
10. Click "退出" → app terminates

- [ ] **Step 4: Run full test suite one final time**

Run: `swift test`
Expected: All tests pass.

- [ ] **Step 5: Add .gitignore and commit**

Create `.gitignore`:
```
.build/
.swiftpm/
Tunnel.app/
.superpowers/
```

```bash
git add .gitignore
git commit -m "chore: add .gitignore for build artifacts"
```

- [ ] **Step 6: Final commit for any remaining changes**

Run: `git status`
If any unstaged files, add and commit:
```bash
git add -A
git commit -m "chore: finalize SSH Tunnel Manager v1.0"
```
