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
        XCTAssertEqual(ReconnectPolicy.delay(forAttempt: 6), 60)
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
