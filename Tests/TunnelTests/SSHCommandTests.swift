import XCTest
@testable import Tunnel

final class SSHCommandTests: XCTestCase {
    func testParseSingleLocalForward() {
        XCTAssertEqual(SSHCommand.parseLocalPorts(from: "ssh -L 3306:localhost:3306 user@host"), [3306])
    }
    func testParseLocalForwardWithBindAddress() {
        XCTAssertEqual(SSHCommand.parseLocalPorts(from: "ssh -L 0.0.0.0:8080:localhost:80 user@host"), [8080])
    }
    func testParseMultipleLocalForwards() {
        XCTAssertEqual(SSHCommand.parseLocalPorts(from: "ssh -L 3306:db:3306 -L 6379:redis:6379 user@host"), [3306, 6379])
    }
    func testParseNoPortFlags() {
        XCTAssertTrue(SSHCommand.parseLocalPorts(from: "ssh user@host").isEmpty)
    }
    func testParseRemoteForwardIgnored() {
        XCTAssertTrue(SSHCommand.parseLocalPorts(from: "ssh -R 8080:localhost:80 user@host").isEmpty)
    }
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

    // MARK: - sanitizeCommand

    func testSanitizeStripsCombinedFNT() {
        let result = SSHCommand.sanitizeCommand("ssh -fNT -L 3306:localhost:3306 user@host")
        XCTAssertEqual(result, "ssh -L 3306:localhost:3306 user@host")
    }

    func testSanitizeStripsSeparateFlags() {
        let result = SSHCommand.sanitizeCommand("ssh -f -N -T -L 3306:localhost:3306 user@host")
        XCTAssertEqual(result, "ssh -L 3306:localhost:3306 user@host")
    }

    func testSanitizeKeepsOtherFlags() {
        let result = SSHCommand.sanitizeCommand("ssh -vfNT -L 3306:localhost:3306 user@host")
        XCTAssertEqual(result, "ssh -v -L 3306:localhost:3306 user@host")
    }

    func testSanitizeKeepsFlagsWithArgs() {
        let result = SSHCommand.sanitizeCommand("ssh -i ~/.ssh/key -fNT -L 3306:localhost:3306 user@host")
        XCTAssertEqual(result, "ssh -i ~/.ssh/key -L 3306:localhost:3306 user@host")
    }

    func testBuildFullCommandStripsF() {
        let cmd = SSHCommand.buildFullCommand(from: "ssh -fNT -L 3306:localhost:3306 user@host")
        XCTAssertFalse(cmd.contains("-f"))
        XCTAssertFalse(cmd.contains("-T"))
        XCTAssertTrue(cmd.contains("-N"))
        XCTAssertTrue(cmd.contains("-L 3306:localhost:3306"))
    }
}
