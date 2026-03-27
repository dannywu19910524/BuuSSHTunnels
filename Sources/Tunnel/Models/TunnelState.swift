import Foundation

enum TunnelStatus: Equatable {
    case disconnected
    case connecting
    case connected
    case reconnecting(attempt: Int)
    case failed(reason: String)

    var isConnected: Bool { if case .connected = self { return true }; return false }
    var isReconnecting: Bool { if case .reconnecting = self { return true }; return false }
    var isFailed: Bool { if case .failed = self { return true }; return false }
    var isActive: Bool {
        switch self {
        case .connecting, .connected, .reconnecting: return true
        default: return false
        }
    }
}

struct TunnelState {
    var status: TunnelStatus = .disconnected
    var retryCount: Int = 0
    var recentLogs: [String] = []
}
