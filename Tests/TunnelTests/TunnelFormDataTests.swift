import XCTest
@testable import Tunnel

final class TunnelFormDataTests: XCTestCase {

    // MARK: - toCommand()

    func testToCommandBasic() {
        var form = TunnelFormData()
        form.host = "server.com"
        form.user = "root"
        form.forwards = [
            PortForward(type: .local, bindAddress: "", bindPort: "3306", destHost: "localhost", destPort: "3306")
        ]
        XCTAssertEqual(form.toCommand(), "ssh -L 3306:localhost:3306 root@server.com")
    }

    func testToCommandCustomSSHPort() {
        var form = TunnelFormData()
        form.host = "server.com"
        form.port = 2222
        form.user = "deploy"
        form.forwards = [
            PortForward(type: .local, bindAddress: "", bindPort: "8080", destHost: "localhost", destPort: "80")
        ]
        XCTAssertEqual(form.toCommand(), "ssh -p 2222 -L 8080:localhost:80 deploy@server.com")
    }

    func testToCommandMultipleForwards() {
        var form = TunnelFormData()
        form.host = "server.com"
        form.user = "root"
        form.forwards = [
            PortForward(type: .local, bindAddress: "", bindPort: "3306", destHost: "localhost", destPort: "3306"),
            PortForward(type: .local, bindAddress: "", bindPort: "6379", destHost: "localhost", destPort: "6379")
        ]
        XCTAssertEqual(form.toCommand(), "ssh -L 3306:localhost:3306 -L 6379:localhost:6379 root@server.com")
    }

    func testToCommandRemoteForward() {
        var form = TunnelFormData()
        form.host = "server.com"
        form.user = "root"
        form.forwards = [
            PortForward(type: .remote, bindAddress: "", bindPort: "8080", destHost: "localhost", destPort: "3000")
        ]
        XCTAssertEqual(form.toCommand(), "ssh -R 8080:localhost:3000 root@server.com")
    }

    func testToCommandWithBindAddress() {
        var form = TunnelFormData()
        form.host = "server.com"
        form.user = "root"
        form.forwards = [
            PortForward(type: .local, bindAddress: "0.0.0.0", bindPort: "3306", destHost: "db.internal", destPort: "3306")
        ]
        XCTAssertEqual(form.toCommand(), "ssh -L 0.0.0.0:3306:db.internal:3306 root@server.com")
    }

    func testToCommandDefaultPort22OmitsFlag() {
        var form = TunnelFormData()
        form.host = "server.com"
        form.port = 22
        form.user = "root"
        form.forwards = [
            PortForward(type: .local, bindAddress: "", bindPort: "3306", destHost: "localhost", destPort: "3306")
        ]
        let cmd = form.toCommand()
        XCTAssertFalse(cmd.contains("-p "))
    }

    // MARK: - init?(fromCommand:)

    func testFromCommandBasic() {
        let form = TunnelFormData(fromCommand: "ssh -L 3306:localhost:3306 root@server.com")
        XCTAssertNotNil(form)
        XCTAssertEqual(form?.host, "server.com")
        XCTAssertEqual(form?.port, 22)
        XCTAssertEqual(form?.user, "root")
        XCTAssertEqual(form?.forwards.count, 1)
        XCTAssertEqual(form?.forwards[0].type, .local)
        XCTAssertEqual(form?.forwards[0].bindPort, "3306")
        XCTAssertEqual(form?.forwards[0].destHost, "localhost")
        XCTAssertEqual(form?.forwards[0].destPort, "3306")
    }

    func testFromCommandWithPort() {
        let form = TunnelFormData(fromCommand: "ssh -p 2222 -L 8080:localhost:80 deploy@server.com")
        XCTAssertNotNil(form)
        XCTAssertEqual(form?.port, 2222)
        XCTAssertEqual(form?.user, "deploy")
        XCTAssertEqual(form?.host, "server.com")
    }

    func testFromCommandMultipleForwards() {
        let form = TunnelFormData(fromCommand: "ssh -L 3306:localhost:3306 -L 6379:localhost:6379 root@server.com")
        XCTAssertNotNil(form)
        XCTAssertEqual(form?.forwards.count, 2)
        XCTAssertEqual(form?.forwards[0].bindPort, "3306")
        XCTAssertEqual(form?.forwards[1].bindPort, "6379")
    }

    func testFromCommandRemoteForward() {
        let form = TunnelFormData(fromCommand: "ssh -R 8080:localhost:3000 root@server.com")
        XCTAssertNotNil(form)
        XCTAssertEqual(form?.forwards[0].type, .remote)
        XCTAssertEqual(form?.forwards[0].bindPort, "8080")
        XCTAssertEqual(form?.forwards[0].destHost, "localhost")
        XCTAssertEqual(form?.forwards[0].destPort, "3000")
    }

    func testFromCommandWithBindAddress() {
        let form = TunnelFormData(fromCommand: "ssh -L 0.0.0.0:3306:db.internal:3306 root@server.com")
        XCTAssertNotNil(form)
        XCTAssertEqual(form?.forwards[0].bindAddress, "0.0.0.0")
        XCTAssertEqual(form?.forwards[0].bindPort, "3306")
        XCTAssertEqual(form?.forwards[0].destHost, "db.internal")
        XCTAssertEqual(form?.forwards[0].destPort, "3306")
    }

    func testFromCommandReturnsNilForIdentityFlag() {
        let form = TunnelFormData(fromCommand: "ssh -i ~/.ssh/key -L 3306:localhost:3306 root@server.com")
        XCTAssertNil(form)
    }

    func testFromCommandReturnsNilForDynamicForward() {
        let form = TunnelFormData(fromCommand: "ssh -D 1080 root@server.com")
        XCTAssertNil(form)
    }

    func testFromCommandReturnsNilForCustomOption() {
        let form = TunnelFormData(fromCommand: "ssh -o StrictHostKeyChecking=no -L 3306:localhost:3306 root@server.com")
        XCTAssertNil(form)
    }

    func testFromCommandIgnoresAutoAddedFlags() {
        let form = TunnelFormData(fromCommand: "ssh -N -L 3306:localhost:3306 root@server.com")
        XCTAssertNotNil(form)
        XCTAssertEqual(form?.forwards.count, 1)
    }

    func testFromCommandRoundTrip() {
        var original = TunnelFormData()
        original.host = "server.com"
        original.port = 2222
        original.user = "deploy"
        original.forwards = [
            PortForward(type: .local, bindAddress: "", bindPort: "3306", destHost: "localhost", destPort: "3306"),
            PortForward(type: .remote, bindAddress: "", bindPort: "8080", destHost: "localhost", destPort: "80")
        ]
        let command = original.toCommand()
        let parsed = TunnelFormData(fromCommand: command)
        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.host, "server.com")
        XCTAssertEqual(parsed?.port, 2222)
        XCTAssertEqual(parsed?.user, "deploy")
        XCTAssertEqual(parsed?.forwards.count, 2)
        XCTAssertEqual(parsed?.forwards[0].type, .local)
        XCTAssertEqual(parsed?.forwards[1].type, .remote)
    }
}
