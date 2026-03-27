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

    var isRunning: Bool { process?.isRunning ?? false }
    var onStateChange: ((TunnelState) -> Void)?

    init(tunnelId: UUID, command: String, maxRetries: Int) {
        self.tunnelId = tunnelId
        self.command = command
        self.maxRetries = maxRetries
    }

    func start() {
        manualStop = false
        retryCount = 0
        recentLogs = []
        launchProcess()
    }

    func stop() {
        manualStop = true
        reconnectTask?.cancel()
        reconnectTask = nil
        if let proc = process, proc.isRunning {
            proc.terminate()
        }
    }

    func updateMaxRetries(_ value: Int) {
        maxRetries = value
    }

    // MARK: - Private

    private func launchProcess() {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/sh")
        proc.arguments = ["-c", SSHCommand.buildFullCommand(from: command)]

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
        notifyState(.connecting)

        do {
            try proc.run()
            checkConnection()
        } catch {
            appendLog("Failed to start: \(error.localizedDescription)")
            notifyState(.failed(reason: error.localizedDescription))
        }
    }

    private func checkConnection() {
        let ports = SSHCommand.parseLocalPorts(from: command)

        if ports.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                guard let self, self.process?.isRunning == true else { return }
                self.retryCount = 0
                self.notifyState(.connected)
            }
            return
        }

        var checks = 0
        let maxChecks = 20

        func poll() {
            guard self.process?.isRunning == true, !self.manualStop else { return }

            if ports.allSatisfy({ SSHCommand.isPortListening($0) }) {
                self.retryCount = 0
                self.notifyState(.connected)
                return
            }

            checks += 1
            if checks >= maxChecks {
                self.retryCount = 0
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

        guard !manualStop else {
            notifyState(.disconnected)
            return
        }

        retryCount += 1

        if retryCount >= maxRetries {
            notifyState(.failed(reason: "已达到最大重连次数 (\(maxRetries))"))
            return
        }

        scheduleReconnect()
    }

    private func scheduleReconnect() {
        let delay = ReconnectPolicy.delay(forAttempt: retryCount)
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
    }

    private func notifyState(_ status: TunnelStatus) {
        let state = TunnelState(status: status, retryCount: retryCount, recentLogs: recentLogs)
        onStateChange?(state)
    }
}
