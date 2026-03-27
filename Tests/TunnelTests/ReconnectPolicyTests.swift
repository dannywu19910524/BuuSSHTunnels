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
    func testShouldNotifyEvery30() {
        XCTAssertFalse(ReconnectPolicy.shouldNotify(retryCount: 1))
        XCTAssertFalse(ReconnectPolicy.shouldNotify(retryCount: 15))
        XCTAssertFalse(ReconnectPolicy.shouldNotify(retryCount: 29))
        XCTAssertTrue(ReconnectPolicy.shouldNotify(retryCount: 30))
        XCTAssertFalse(ReconnectPolicy.shouldNotify(retryCount: 31))
        XCTAssertTrue(ReconnectPolicy.shouldNotify(retryCount: 60))
        XCTAssertTrue(ReconnectPolicy.shouldNotify(retryCount: 90))
        XCTAssertTrue(ReconnectPolicy.shouldNotify(retryCount: 990))
    }
    func testShouldNotifyNeverAtZero() {
        XCTAssertFalse(ReconnectPolicy.shouldNotify(retryCount: 0))
    }
}
