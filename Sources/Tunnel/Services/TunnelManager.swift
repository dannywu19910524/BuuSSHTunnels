import Foundation
import Combine
import AppKit

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
