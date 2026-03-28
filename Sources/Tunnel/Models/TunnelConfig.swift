import Foundation

struct TunnelConfig: Codable, Identifiable {
    var id: UUID
    var name: String
    var command: String
    var autoConnect: Bool
    var tag: String?
    var autoKillPortConflicts: Bool
    init(id: UUID = UUID(), name: String = "", command: String = "", autoConnect: Bool = true, tag: String? = nil, autoKillPortConflicts: Bool = false) {
        self.id = id
        self.name = name
        self.command = command
        self.autoConnect = autoConnect
        self.tag = tag
        self.autoKillPortConflicts = autoKillPortConflicts
    }
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        command = try c.decode(String.self, forKey: .command)
        autoConnect = try c.decode(Bool.self, forKey: .autoConnect)
        tag = try c.decodeIfPresent(String.self, forKey: .tag)
        autoKillPortConflicts = try c.decodeIfPresent(Bool.self, forKey: .autoKillPortConflicts) ?? false
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
