import Foundation

class TunnelProcess {
    let tunnelId: UUID
    let command: String
    private(set) var retryCount: Int = 0
    private(set) var recentLogs: [String] = []

    private var process: Process?
    private var stderrPipe: Pipe?
    private var manualStop = false
    private var maxRetries: Int
    private var reconnectTask: DispatchWorkItem?
    private var launchTime: Date?
    private var tunnelName: String
    private var preListeningPorts: Set<UInt16> = []

    var isRunning: Bool { process?.isRunning ?? false }
    var onStateChange: ((TunnelState) -> Void)?

    private static let quickFailThreshold: TimeInterval = 5
    private static let quickFailMinDelay: TimeInterval = 5

    init(tunnelId: UUID, command: String, maxRetries: Int, name: String = "") {
        self.tunnelId = tunnelId
        self.command = command
        self.maxRetries = maxRetries
        self.tunnelName = name.isEmpty ? tunnelId.uuidString.prefix(8).description : name
    }

    func start() {
        manualStop = false
        retryCount = 0
        recentLogs = []
        FileLogger.shared.log("Starting: \(command)", tunnel: tunnelName)
        launchProcess()
    }

    func stop() {
        manualStop = true
        reconnectTask?.cancel()
        reconnectTask = nil
        if let proc = process, proc.isRunning {
            proc.terminate()
        }
        FileLogger.shared.log("Stopped by user", tunnel: tunnelName)
    }

    func updateMaxRetries(_ value: Int) {
        maxRetries = value
    }

    // MARK: - Private

    private func launchProcess() {
        // Record which ports are already listening before we start,
        // so we don't get false-positive "connected" from orphaned processes
        let ports = SSHCommand.parseLocalPorts(from: command)
        preListeningPorts = Set(ports.filter { SSHCommand.isPortListening($0) })
        if !preListeningPorts.isEmpty {
            FileLogger.shared.log("Ports already in use before launch: \(preListeningPorts)", tunnel: tunnelName)
        }

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/sh")
        let fullCommand = SSHCommand.buildFullCommand(from: command)
        proc.arguments = ["-c", fullCommand]

        let pipe = Pipe()
        proc.standardError = pipe
        proc.standardOutput = FileHandle.nullDevice

        proc.terminationHandler = { [weak self] p in
            DispatchQueue.main.async {
                self?.handleTermination(exitCode: p.terminationStatus)
            }
        }

        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            DispatchQueue.main.async {
                self?.appendLog(text)
            }
        }

        self.process = proc
        self.stderrPipe = pipe
        self.launchTime = Date()
        notifyState(.connecting)

        FileLogger.shared.log("Launching: /bin/sh -c \"\(fullCommand)\"", tunnel: tunnelName)

        do {
            try proc.run()
            checkConnection()
        } catch {
            let msg = "Failed to start: \(error.localizedDescription)"
            appendLog(msg)
            FileLogger.shared.log(msg, tunnel: tunnelName)
            notifyState(.failed(reason: error.localizedDescription))
        }
    }

    private func checkConnection() {
        let ports = SSHCommand.parseLocalPorts(from: command)
        // Only check ports that weren't already listening before we started
        let portsToCheck = ports.filter { !preListeningPorts.contains($0) }

        if portsToCheck.isEmpty {
            // No new ports to check — fall back to process-alive check
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                guard let self, self.process?.isRunning == true else { return }
                self.retryCount = 0
                FileLogger.shared.log("Connected (process alive after 3s)", tunnel: self.tunnelName)
                self.notifyState(.connected)
            }
            return
        }

        var checks = 0
        let maxChecks = 20

        func poll() {
            guard self.process?.isRunning == true, !self.manualStop else { return }

            if portsToCheck.allSatisfy({ SSHCommand.isPortListening($0) }) {
                self.retryCount = 0
                FileLogger.shared.log("Connected (ports \(portsToCheck) listening)", tunnel: self.tunnelName)
                self.notifyState(.connected)
                return
            }

            checks += 1
            if checks >= maxChecks {
                self.retryCount = 0
                FileLogger.shared.log("Connected (timeout, assuming OK)", tunnel: self.tunnelName)
                self.notifyState(.connected)
                return
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { poll() }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { poll() }
    }

    private func handleTermination(exitCode: Int32) {
        stderrPipe?.fileHandleForReading.readabilityHandler = nil
        process = nil

        let uptime = launchTime.map { Date().timeIntervalSince($0) } ?? 0
        let isQuickFail = uptime < Self.quickFailThreshold

        FileLogger.shared.log(
            "Process exited: code=\(exitCode), uptime=\(String(format: "%.1f", uptime))s, quickFail=\(isQuickFail)",
            tunnel: tunnelName
        )

        guard !manualStop else {
            notifyState(.disconnected)
            return
        }

        retryCount += 1

        if retryCount >= maxRetries {
            let reason = "已达到最大重连次数 (\(maxRetries))"
            FileLogger.shared.log(reason, tunnel: tunnelName)
            notifyState(.failed(reason: reason))
            return
        }

        scheduleReconnect(quickFail: isQuickFail)
    }

    private func scheduleReconnect(quickFail: Bool) {
        var delay = ReconnectPolicy.delay(forAttempt: retryCount)

        // Quick failure: enforce minimum delay to avoid tight loops
        if quickFail {
            delay = max(delay, Self.quickFailMinDelay)
        }

        FileLogger.shared.log(
            "Reconnecting in \(String(format: "%.1f", delay))s (attempt \(retryCount))",
            tunnel: tunnelName
        )

        notifyState(.reconnecting(attempt: retryCount))

        let task = DispatchWorkItem { [weak self] in
            self?.launchProcess()
        }
        self.reconnectTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: task)
    }

    private func appendLog(_ text: String) {
        let lines = text.components(separatedBy: .newlines).filter { !$0.isEmpty }
        recentLogs.append(contentsOf: lines)
        if recentLogs.count > 50 {
            recentLogs = Array(recentLogs.suffix(50))
        }
        // Also write to file log
        for line in lines {
            FileLogger.shared.log("stderr: \(line)", tunnel: tunnelName)
        }
    }

    private func notifyState(_ status: TunnelStatus) {
        let state = TunnelState(status: status, retryCount: retryCount, recentLogs: recentLogs)
        onStateChange?(state)
    }
}
