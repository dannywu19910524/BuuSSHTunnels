import Foundation

class FileLogger {
    static let shared = FileLogger()

    private let fileHandle: FileHandle?
    private let dateFormatter: DateFormatter
    let logFileURL: URL

    private init() {
        let dir = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first!.appendingPathComponent("Tunnel")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        logFileURL = dir.appendingPathComponent("tunnel.log")

        // Rotate if > 1MB
        if let attrs = try? FileManager.default.attributesOfItem(atPath: logFileURL.path),
           let size = attrs[.size] as? UInt64, size > 1_000_000 {
            let backup = dir.appendingPathComponent("tunnel.log.1")
            try? FileManager.default.removeItem(at: backup)
            try? FileManager.default.moveItem(at: logFileURL, to: backup)
        }

        FileManager.default.createFile(atPath: logFileURL.path, contents: nil)
        fileHandle = FileHandle(forWritingAtPath: logFileURL.path)
        fileHandle?.seekToEndOfFile()

        dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

        log("=== Tunnel App Started ===")
    }

    func log(_ message: String, tunnel: String? = nil) {
        let timestamp = dateFormatter.string(from: Date())
        let prefix = tunnel != nil ? "[\(tunnel!)] " : ""
        let line = "\(timestamp) \(prefix)\(message)\n"

        if let data = line.data(using: .utf8) {
            fileHandle?.write(data)
        }
    }

    deinit {
        fileHandle?.closeFile()
    }
}
