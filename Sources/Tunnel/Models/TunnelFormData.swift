import Foundation

enum ForwardType: String, CaseIterable {
    case local = "本地转发"
    case remote = "远程转发"

    var flag: String {
        switch self {
        case .local: return "-L"
        case .remote: return "-R"
        }
    }
}

struct PortForward: Identifiable {
    var id = UUID()
    var type: ForwardType = .local
    var bindAddress: String = ""
    var bindPort: String = ""
    var destHost: String = "localhost"
    var destPort: String = ""
}

struct TunnelFormData {
    var host: String = ""
    var port: Int = 22
    var user: String = ""
    var forwards: [PortForward] = [PortForward()]

    init() {}

    /// Parses an SSH command into form data. Returns nil if command contains unsupported flags.
    init?(fromCommand command: String) {
        let args = command.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
        guard args.first == "ssh" else { return nil }

        // Flags we auto-add (safe to ignore during parsing)
        let autoAddedFlags: Set<Character> = Set("fNT")
        // Flags that take an argument and that we do NOT support (cause fallback)
        let unsupportedArgFlags: Set<String> = ["-i", "-D", "-o", "-J", "-W", "-F",
                                                 "-b", "-c", "-E", "-e", "-I", "-l",
                                                 "-m", "-O", "-Q", "-S", "-w"]

        var host = ""
        var port = 22
        var user = ""
        var forwards: [PortForward] = []

        var i = 1 // skip "ssh"
        while i < args.count {
            let arg = args[i]

            if unsupportedArgFlags.contains(arg) {
                return nil
            }

            if arg == "-o" {
                // Check if it's one of our auto-added options
                if i + 1 < args.count {
                    let val = args[i + 1]
                    if val.hasPrefix("ServerAliveInterval") || val.hasPrefix("ServerAliveCountMax") || val.hasPrefix("ExitOnForwardFailure") {
                        i += 2
                        continue
                    }
                }
                return nil
            }

            if arg == "-p" {
                guard i + 1 < args.count, let p = Int(args[i + 1]) else { return nil }
                port = p
                i += 2
                continue
            }

            if arg == "-L" || arg == "-R" {
                guard i + 1 < args.count else { return nil }
                let fwdType: ForwardType = arg == "-L" ? .local : .remote
                let spec = args[i + 1]
                let parts = spec.split(separator: ":")
                var fwd = PortForward(type: fwdType)
                if parts.count == 3 {
                    fwd.bindAddress = ""
                    fwd.bindPort = String(parts[0])
                    fwd.destHost = String(parts[1])
                    fwd.destPort = String(parts[2])
                } else if parts.count == 4 {
                    fwd.bindAddress = String(parts[0])
                    fwd.bindPort = String(parts[1])
                    fwd.destHost = String(parts[2])
                    fwd.destPort = String(parts[3])
                } else {
                    return nil
                }
                forwards.append(fwd)
                i += 2
                continue
            }

            if arg.hasPrefix("-") && !arg.hasPrefix("--") && arg.count > 1 {
                let flags = arg.dropFirst()
                // Check if all flags are auto-added (safe to ignore)
                for flag in flags {
                    if !autoAddedFlags.contains(flag) {
                        return nil
                    }
                }
                i += 1
                continue
            }

            // Should be user@host
            if arg.contains("@") {
                let atParts = arg.split(separator: "@", maxSplits: 1)
                if atParts.count == 2 {
                    user = String(atParts[0])
                    host = String(atParts[1])
                }
                i += 1
                continue
            }

            // Unrecognized argument — could be hostname without user@
            if host.isEmpty && !arg.hasPrefix("-") {
                host = arg
                i += 1
                continue
            }

            return nil
        }

        guard !host.isEmpty, !user.isEmpty else { return nil }

        self.host = host
        self.port = port
        self.user = user
        self.forwards = forwards.isEmpty ? [PortForward()] : forwards
    }

    func toCommand() -> String {
        var parts = ["ssh"]
        if port != 22 {
            parts.append("-p")
            parts.append("\(port)")
        }
        for fwd in forwards {
            let bind: String
            if fwd.bindAddress.isEmpty {
                bind = fwd.bindPort
            } else {
                bind = "\(fwd.bindAddress):\(fwd.bindPort)"
            }
            parts.append(fwd.type.flag)
            parts.append("\(bind):\(fwd.destHost):\(fwd.destPort)")
        }
        parts.append("\(user)@\(host)")
        return parts.joined(separator: " ")
    }
}
