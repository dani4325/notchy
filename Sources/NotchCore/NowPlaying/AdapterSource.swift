import Foundation
import os

struct AdapterPaths: Sendable {
    let script: URL
    let framework: URL
    let testClient: URL

    static func inBundle(_ bundle: Bundle = .main) -> AdapterPaths? {
        guard let script = bundle.url(forResource: "mediaremote-adapter", withExtension: "pl"),
              let framework = bundle.privateFrameworksURL?.appendingPathComponent("MediaRemoteAdapter.framework"),
              let testClient = bundle.url(forAuxiliaryExecutable: "MediaRemoteAdapterTestClient"),
              FileManager.default.fileExists(atPath: framework.path)
        else { return nil }
        return AdapterPaths(script: script, framework: framework, testClient: testClient)
    }

    func arguments(_ command: [String]) -> [String] {
        [script.path, framework.path, testClient.path] + command
    }
}

@MainActor
final class AdapterSource: NowPlayingSource {
    private nonisolated static let perl = URL(fileURLWithPath: "/usr/bin/perl")
    private nonisolated static let selfTestTimeout: TimeInterval = 5
    private static let maxRestarts = 3
    private nonisolated static let logger = Logger(subsystem: "com.danirubio.notchy", category: "adapter")

    var onUpdate: ((NowPlayingInfo?) -> Void)?
    var onFailure: (() -> Void)?

    private let paths: AdapterPaths
    private var process: Process?
    private var fields: [String: Any] = [:]
    private var restarts = 0
    private var isStopping = false

    init(paths: AdapterPaths) {
        self.paths = paths
    }

    nonisolated static func selfTest(paths: AdapterPaths) async -> Bool {
        let process = Process()
        process.executableURL = perl
        process.arguments = paths.arguments(["test"])
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        return await withCheckedContinuation { continuation in
            process.terminationHandler = { finished in
                continuation.resume(returning: finished.terminationReason == .exit && finished.terminationStatus == 0)
            }
            do {
                try process.run()
            } catch {
                logger.error("self-test launch failed: \(error.localizedDescription, privacy: .public)")
                process.terminationHandler = nil
                continuation.resume(returning: false)
                return
            }
            DispatchQueue.global().asyncAfter(deadline: .now() + selfTestTimeout) {
                if process.isRunning { process.terminate() }
            }
        }
    }

    func start() {
        isStopping = false
        launchStream()
    }

    func stop() {
        isStopping = true
        process?.terminationHandler = nil
        (process?.standardOutput as? Pipe)?.fileHandleForReading.readabilityHandler = nil
        process?.terminate()
        process = nil
    }

    func send(_ command: MediaCommand) {
        let sender = Process()
        sender.executableURL = Self.perl
        sender.arguments = paths.arguments(["send", String(command.adapterID)])
        sender.standardOutput = FileHandle.nullDevice
        sender.standardError = FileHandle.nullDevice
        do {
            try sender.run()
        } catch {
            Self.logger.error("send failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func launchStream() {
        let stream = Process()
        let pipe = Pipe()
        stream.executableURL = Self.perl
        stream.arguments = paths.arguments(["stream", "--micros", "--debounce=80"])
        stream.standardOutput = pipe
        stream.standardError = FileHandle.nullDevice

        let splitter = LineSplitter()
        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let chunk = handle.availableData
            if chunk.isEmpty {
                handle.readabilityHandler = nil
                return
            }
            let messages = splitter.feed(chunk).compactMap { AdapterPayload.parse(line: $0) }
            guard !messages.isEmpty else { return }
            let batch = AdapterMessages(items: messages)
            DispatchQueue.main.async { [weak self] in
                MainActor.assumeIsolated { self?.consume(batch) }
            }
        }
        stream.terminationHandler = { [weak self] finished in
            let status = finished.terminationStatus
            Task { @MainActor [weak self] in self?.streamEnded(status: status) }
        }

        do {
            try stream.run()
            process = stream
        } catch {
            Self.logger.error("stream launch failed: \(error.localizedDescription, privacy: .public)")
            onFailure?()
        }
    }

    private func consume(_ batch: AdapterMessages) {
        fields = batch.items.reduce(fields, AdapterPayload.merge)
        restarts = 0
        onUpdate?(AdapterPayload.info(from: fields, now: Date()))
    }

    private func streamEnded(status: Int32) {
        guard !isStopping else { return }
        Self.logger.error("stream ended with status \(status)")
        process = nil
        fields = [:]
        guard restarts < Self.maxRestarts else {
            onFailure?()
            return
        }
        restarts += 1
        launchStream()
    }
}

private struct AdapterMessages: @unchecked Sendable {
    let items: [[String: Any]]
}
