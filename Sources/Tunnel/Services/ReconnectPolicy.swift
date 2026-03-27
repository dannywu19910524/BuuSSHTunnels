import Foundation

enum ReconnectPolicy {
    static func delay(forAttempt attempt: Int) -> TimeInterval {
        guard attempt > 0 else { return 0 }
        return min(pow(2.0, Double(attempt)), 60.0)
    }
    static func shouldNotify(retryCount: Int) -> Bool {
        guard retryCount >= 3 else { return false }
        return (retryCount - 3) % 10 == 0
    }
}
