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

    /// Returns PIDs of processes listening on the given port, or empty if none.
    static func findProcesses(onPort port: UInt16) -> [(pid: Int32, name: String)] {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        proc.arguments = ["-ti", ":\(port)"]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = FileHandle.nullDevice
        do {
            try proc.run()
            proc.waitUntilExit()
        } catch {
            return []
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else { return [] }
        var results: [(pid: Int32, name: String)] = []
        for line in output.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard let pid = Int32(trimmed) else { continue }
            // Get process name via ps
            let ps = Process()
            ps.executableURL = URL(fileURLWithPath: "/bin/ps")
            ps.arguments = ["-p", "\(pid)", "-o", "comm="]
            let psPipe = Pipe()
            ps.standardOutput = psPipe
            ps.standardError = FileHandle.nullDevice
            do {
                try ps.run()
                ps.waitUntilExit()
                let psData = psPipe.fileHandleForReading.readDataToEndOfFile()
                let name = String(data: psData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                results.append((pid: pid, name: name))
            } catch {
                results.append((pid: pid, name: ""))
            }
        }
        return results
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
