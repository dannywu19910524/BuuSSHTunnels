import Foundation

enum SSHCommand {
    private static let extraOptions = "-o ServerAliveInterval=15 -o ServerAliveCountMax=3 -o ExitOnForwardFailure=yes -N"

    /// Strips -f, -N, -T from user command (we add -N ourselves; -f backgrounds ssh
    /// which breaks our process management; -T is implied by -N).
    static func sanitizeCommand(_ command: String) -> String {
        let parts = command.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        let argFlags: Set<Character> = Set("bcDEeFIiJLlmOopQRSWw")
        let stripFlags: Set<Character> = Set("fNT")
        var result: [String] = []

        for part in parts {
            if part.hasPrefix("-") && !part.hasPrefix("--") && part.count > 1 {
                let flags = part.dropFirst()
                // If this flag group contains a flag that takes an argument, keep as-is
                if flags.contains(where: { argFlags.contains($0) }) {
                    result.append(part)
                    continue
                }
                let cleaned = flags.filter { !stripFlags.contains($0) }
                if !cleaned.isEmpty {
                    result.append("-" + cleaned)
                }
            } else {
                result.append(part)
            }
        }
        return result.joined(separator: " ")
    }

    static func buildFullCommand(from userCommand: String) -> String {
        let sanitized = sanitizeCommand(userCommand.trimmingCharacters(in: .whitespaces))
        guard let firstSpace = sanitized.firstIndex(of: " ") else { return sanitized }
        let binary = sanitized[..<firstSpace]
        let rest = sanitized[firstSpace...]
        return "\(binary) \(extraOptions)\(rest)"
    }

    static func parseLocalPorts(from command: String) -> [UInt16] {
        let args = command.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        var ports: [UInt16] = []
        var i = 0
        while i < args.count {
            if args[i] == "-L", i + 1 < args.count {
                i += 1
                let parts = args[i].split(separator: ":")
                let portStr: Substring
                if parts.count == 3 { portStr = parts[0] }
                else if parts.count == 4 { portStr = parts[1] }
                else { i += 1; continue }
                if let port = UInt16(portStr) { ports.append(port) }
            }
            i += 1
        }
        return ports
    }

    static func isPortListening(_ port: UInt16) -> Bool {
        let sock = socket(AF_INET, SOCK_STREAM, 0)
        guard sock >= 0 else { return false }
        defer { close(sock) }
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = port.bigEndian
        addr.sin_addr.s_addr = inet_addr("127.0.0.1")
        return withUnsafePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                connect(sock, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        } == 0
    }
}
