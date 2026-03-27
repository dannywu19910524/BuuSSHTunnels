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
