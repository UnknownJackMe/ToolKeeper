import Foundation

@Observable
@MainActor
final class CommandRunner {

    // MARK: - Observable Properties

    var stdoutLines: [String] = []
    var stderrLines: [String] = []
    var isRunning: Bool = false
    var exitCode: Int? = nil
    var durationMs: Int? = nil

    // MARK: - Private State

    private var process: Process?
    private var stdoutPipe: Pipe?
    private var stderrPipe: Pipe?
    private var stdoutFileHandle: FileHandle?
    private var stderrFileHandle: FileHandle?
    private var stdoutLogURL: URL?
    private var stderrLogURL: URL?
    private var timeoutTimer: Timer?
    private var startTime: Date?

    private let maxLinesInMemory = 1000

    // MARK: - Public API

    func run(
        command: String,
        workingDirectory: String?,
        shell: String = "/bin/zsh",
        timeout: Int = 120,
        onCompletion: ((Int?) -> Void)? = nil
    ) {
        guard !isRunning else { return }

        // Reset state
        stdoutLines = []
        stderrLines = []
        exitCode = nil
        durationMs = nil
        isRunning = true
        startTime = Date()

        let timestamp = Self.dateFormatter.string(from: Date())
        let logsDir = AppPaths.logs
        AppPaths.ensureDirectories()

        let stdoutPath = (logsDir as NSString).appendingPathComponent("\(timestamp)_stdout.log")
        let stderrPath = (logsDir as NSString).appendingPathComponent("\(timestamp)_stderr.log")

        stdoutLogURL = URL(fileURLWithPath: stdoutPath)
        stderrLogURL = URL(fileURLWithPath: stderrPath)

        FileManager.default.createFile(atPath: stdoutPath, contents: nil)
        FileManager.default.createFile(atPath: stderrPath, contents: nil)

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: shell)
        proc.arguments = ["-lc", command]

        if let cwd = workingDirectory {
            proc.currentDirectoryURL = URL(fileURLWithPath: cwd)
        }

        let outPipe = Pipe()
        let errPipe = Pipe()
        proc.standardOutput = outPipe
        proc.standardError = errPipe

        stdoutPipe = outPipe
        stderrPipe = errPipe
        stdoutFileHandle = outPipe.fileHandleForReading
        stderrFileHandle = errPipe.fileHandleForReading
        process = proc

        // Async output reading via DispatchSource
        let stdoutSource = DispatchSource.makeReadSource(
            fileDescriptor: outPipe.fileHandleForReading.fileDescriptor,
            queue: .global()
        )
        let stderrSource = DispatchSource.makeReadSource(
            fileDescriptor: errPipe.fileHandleForReading.fileDescriptor,
            queue: .global()
        )

        stdoutSource.setEventHandler { [weak self] in
            self?.handlePipeRead(
                fileDescriptor: outPipe.fileHandleForReading.fileDescriptor,
                logURL: URL(fileURLWithPath: stdoutPath),
                isError: false
            )
        }

        stderrSource.setEventHandler { [weak self] in
            self?.handlePipeRead(
                fileDescriptor: errPipe.fileHandleForReading.fileDescriptor,
                logURL: URL(fileURLWithPath: stderrPath),
                isError: true
            )
        }

        stdoutSource.setCancelHandler {}
        stderrSource.setCancelHandler {}

        proc.terminationHandler = { [weak self] finishedProcess in
            let code = finishedProcess.terminationStatus
            let capturedStdoutSource = stdoutSource
            let capturedStderrSource = stderrSource

            Task { @MainActor [weak self] in
                guard let self else { return }
                capturedStdoutSource.cancel()
                capturedStderrSource.cancel()

                self.isRunning = false
                self.exitCode = Int(code)
                if let start = self.startTime {
                    self.durationMs = Int(Date().timeIntervalSince(start) * 1000)
                }
                self.timeoutTimer?.invalidate()
                self.timeoutTimer = nil
                onCompletion?(Int(code))
            }
        }

        // Timeout
        if timeout > 0 {
            timeoutTimer = Timer.scheduledTimer(withTimeInterval: TimeInterval(timeout), repeats: false) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self, self.isRunning else { return }
                    self.process?.terminate()
                }
            }
        }

        do {
            stdoutSource.resume()
            stderrSource.resume()
            try proc.run()
        } catch {
            isRunning = false
            stderrLines.append("Failed to launch: \(error.localizedDescription)")
            onCompletion?(nil)
        }
    }

    func stop() {
        guard isRunning, let proc = process else { return }
        proc.terminate()
    }

    func clear() {
        stdoutLines = []
        stderrLines = []
        exitCode = nil
    }

    // MARK: - Private Helpers

    private nonisolated func handlePipeRead(fileDescriptor: Int32, logURL: URL, isError: Bool) {
        let bufferSize = 4096
        var buffer = [UInt8](repeating: 0, count: bufferSize)
        let bytesRead = read(fileDescriptor, &buffer, bufferSize)

        guard bytesRead > 0 else { return }

        let data = Data(bytes: buffer, count: bytesRead)

        // Append to log file
        if let handle = try? FileHandle(forWritingTo: logURL) {
            handle.seekToEndOfFile()
            handle.write(data)
            handle.closeFile()
        }

        // Parse lines and append to in-memory arrays
        guard let chunk = String(data: data, encoding: .utf8) else { return }
        let newLines = chunk.components(separatedBy: .newlines).filter { !$0.isEmpty }

        Task { @MainActor [weak self] in
            guard let self else { return }
            if isError {
                self.stderrLines.append(contentsOf: newLines)
                if self.stderrLines.count > self.maxLinesInMemory {
                    self.stderrLines = Array(self.stderrLines.suffix(self.maxLinesInMemory))
                }
            } else {
                self.stdoutLines.append(contentsOf: newLines)
                if self.stdoutLines.count > self.maxLinesInMemory {
                    self.stdoutLines = Array(self.stdoutLines.suffix(self.maxLinesInMemory))
                }
            }
        }
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd_HHmmss"
        return f
    }()
}
