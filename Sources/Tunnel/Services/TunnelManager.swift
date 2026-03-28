import Foundation
import Combine
import AppKit

struct PortConflict {
    let tunnelId: UUID
    let ports: [(port: UInt16, pid: Int32, processName: String)]
}

class TunnelManager: ObservableObject {
    @Published var tunnels: [TunnelConfig] = []
    @Published var settings: AppSettings = AppSettings()
    @Published private(set) var tunnelStates: [UUID: TunnelState] = [:]
    @Published var portConflict: PortConflict?

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

        // Check for port conflicts before starting
        let ports = SSHCommand.parseLocalPorts(from: config.command)
        var conflicts: [(port: UInt16, pid: Int32, processName: String)] = []
        for port in ports {
            let procs = SSHCommand.findProcesses(onPort: port)
            for p in procs {
                conflicts.append((port: port, pid: p.pid, processName: p.name))
            }
        }

        if !conflicts.isEmpty {
            if config.autoKillPortConflicts {
                let conflict = PortConflict(tunnelId: id, ports: conflicts)
                forceStartTunnel(killingConflicts: conflict)
                return
            }
            portConflict = PortConflict(tunnelId: id, ports: conflicts)
            return
        }

        launchTunnel(id: id, command: config.command, name: config.name)
    }

    func forceStartTunnel(killingConflicts conflict: PortConflict) {
        for entry in conflict.ports {
            kill(entry.pid, SIGTERM)
            FileLogger.shared.log("Killed process \(entry.pid) (\(entry.processName)) on port \(entry.port)")
        }
        portConflict = nil
        // Brief delay to let ports release
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self, let config = self.tunnels.first(where: { $0.id == conflict.tunnelId }) else { return }
            self.launchTunnel(id: conflict.tunnelId, command: config.command, name: config.name)
        }
    }

    func cancelPortConflict() {
        portConflict = nil
    }

    private func launchTunnel(id: UUID, command: String, name: String) {
        let proc = TunnelProcess(tunnelId: id, command: command, maxRetries: settings.maxRetries, name: name)
        proc.onStateChange = { [weak self] state in
            self?.handleStateChange(tunnelId: id, state: state)
        }
        processes[id] = proc
        proc.start()
    }

    func stopTunnel(id: UUID) {
        processes[id]?.stop()
        processes.removeValue(forKey: id)
        // Update state immediately — don't rely on async terminationHandler
        // which may not fire if TunnelProcess is deallocated
        if tunnelStates[id] != nil {
            tunnelStates[id] = TunnelState(
                status: .disconnected,
                retryCount: 0,
                recentLogs: tunnelStates[id]?.recentLogs ?? []
            )
        }
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

        if case .failed(let reason) = state.status {
            notificationService.send(
                title: "SSH Tunnel 已停止",
                body: "\(displayName): \(reason)"
            )
        }

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
