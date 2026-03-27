import XCTest
@testable import Tunnel

final class ConfigStoreTests: XCTestCase {
    var tempDir: URL!
    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("TunnelTests-\(UUID().uuidString)")
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
        store.save(AppConfig())
        let fileURL = tempDir.appendingPathComponent("config.json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: fileURL.path))
    }
    func testMultipleSavesOverwrite() {
        let store = ConfigStore(directory: tempDir)
        store.save(AppConfig(tunnels: [TunnelConfig(name: "A", command: "ssh a")]))
        store.save(AppConfig(tunnels: [TunnelConfig(name: "A", command: "ssh a"), TunnelConfig(name: "B", command: "ssh b")]))
        XCTAssertEqual(store.load().tunnels.count, 2)
    }
}
