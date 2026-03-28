import Foundation

struct PathSettings: Codable {
    var customConfigPath: String?
}

class ConfigStore {
    private(set) var fileURL: URL
    private static let defaultDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!.appendingPathComponent("Tunnel")
    private static var pathSettingsURL: URL { defaultDir.appendingPathComponent("path-settings.json") }

    init(directory: URL? = nil) {
        let dir = directory ?? Self.defaultDir
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        // Check for custom config path
        if directory == nil, let customPath = Self.loadPathSettings()?.customConfigPath, !customPath.isEmpty {
            let customURL = URL(fileURLWithPath: customPath)
            // Ensure parent directory exists
            let parentDir = customURL.deletingLastPathComponent()
            try? FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)
            self.fileURL = customURL
        } else {
            self.fileURL = dir.appendingPathComponent("config.json")
        }
    }

    func load() -> AppConfig {
        guard let data = try? Data(contentsOf: fileURL),
              let config = try? JSONDecoder().decode(AppConfig.self, from: data) else { return AppConfig() }
        return config
    }

    func save(_ config: AppConfig) {
        guard let data = try? JSONEncoder().encode(config) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    // MARK: - Path Settings (stored separately in app's local dir)

    static func loadPathSettings() -> PathSettings? {
        try? FileManager.default.createDirectory(at: defaultDir, withIntermediateDirectories: true)
        guard let data = try? Data(contentsOf: pathSettingsURL),
              let settings = try? JSONDecoder().decode(PathSettings.self, from: data) else { return nil }
        return settings
    }

    static func savePathSettings(_ settings: PathSettings) {
        try? FileManager.default.createDirectory(at: defaultDir, withIntermediateDirectories: true)
        guard let data = try? JSONEncoder().encode(settings) else { return }
        try? data.write(to: pathSettingsURL, options: .atomic)
    }
}
