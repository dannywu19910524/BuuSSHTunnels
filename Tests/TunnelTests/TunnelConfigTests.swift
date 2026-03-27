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
