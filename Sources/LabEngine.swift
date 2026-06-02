import Foundation
import LiteRTLM

struct BackendInitResult: Sendable {
    let activeBackend: String
    let didFallback: Bool
}

enum LabEngineError: LocalizedError {
    case notInitialized
    case bothBackendsFailed(String)
    case cancelled

    var errorDescription: String? {
        switch self {
        case .notInitialized:
            return "Load a model before running the matrix."
        case .bothBackendsFailed(let message):
            return message
        case .cancelled:
            return "Matrix run was cancelled."
        }
    }
}

@MainActor
final class LabEngine {
    private var engine: Engine?
    private var conversation: Conversation?
    private var activeSamplerConfig: SamplerConfig?
    private var activeInferenceTask: Task<Void, Never>?
    private var loadedModelPath: String?
    private var loadedUsesGPU: Bool?

    private(set) var lastBenchmarkInfo: BenchmarkInfo?
    private(set) var lastTokenLatenciesMs: [Double] = []
    private(set) var lastThermalStart: ThermalLevel = .nominal
    private(set) var lastThermalEnd: ThermalLevel = .nominal
    private(set) var lastMemoryDeltaMB: Double = 0
    private(set) var lastMemoryStartMB: Double = 0
    private(set) var lastMemoryEndMB: Double = 0
    private(set) var lastStreamedTokenCount: Int = 0

    var isReady: Bool { conversation != nil }

    func ensureLoaded(
        path: String,
        preferGPU: Bool,
        forceCPU: Bool,
        samplerConfig: SamplerConfig?
    ) async throws -> BackendInitResult {
        try Task.checkCancellation()

        ExperimentalFlags.optIntoExperimentalAPIs()
        ExperimentalFlags.enableBenchmark = true

        let targetGPU = forceCPU ? false : preferGPU

        if let loadedModelPath,
           loadedModelPath == path,
           let loadedUsesGPU,
           loadedUsesGPU == targetGPU,
           engine != nil
        {
            try await applySampler(samplerConfig)
            return BackendInitResult(
                activeBackend: targetGPU ? "gpu" : "cpu",
                didFallback: false
            )
        }

        let result = try await loadModel(
            path: path,
            preferGPU: preferGPU,
            forceCPU: forceCPU,
            samplerConfig: samplerConfig
        )
        loadedModelPath = path
        loadedUsesGPU = targetGPU
        return result
    }

    func loadModel(
        path: String,
        preferGPU: Bool,
        forceCPU: Bool,
        samplerConfig: SamplerConfig?
    ) async throws -> BackendInitResult {
        await shutdown()
        loadedModelPath = nil
        loadedUsesGPU = nil

        activeSamplerConfig = samplerConfig
        let cacheDir = try makeCacheDirectory(for: path)
        let tryGPUFirst = forceCPU ? false : preferGPU

        do {
            try await initializeEngine(path: path, useGPU: tryGPUFirst, cacheDir: cacheDir, sampler: samplerConfig)
            loadedModelPath = path
            loadedUsesGPU = tryGPUFirst
            return BackendInitResult(
                activeBackend: tryGPUFirst ? "gpu" : "cpu",
                didFallback: false
            )
        } catch {
            let primaryError = error.localizedDescription
            let fallbackGPU = !tryGPUFirst
            do {
                try await initializeEngine(path: path, useGPU: fallbackGPU, cacheDir: cacheDir, sampler: samplerConfig)
                loadedModelPath = path
                loadedUsesGPU = fallbackGPU
                return BackendInitResult(
                    activeBackend: fallbackGPU ? "gpu" : "cpu",
                    didFallback: true
                )
            } catch {
                throw LabEngineError.bothBackendsFailed(
                    "GPU/CPU init failed. Primary: \(primaryError). Fallback: \(error.localizedDescription)"
                )
            }
        }
    }

    func applySampler(_ samplerConfig: SamplerConfig?) async throws {
        activeSamplerConfig = samplerConfig
        try await resetConversation()
    }

    func resetConversation() async throws {
        guard let engine else { throw LabEngineError.notInitialized }

        await finishActiveInferenceTask()

        autoreleasepool {
            withExtendedLifetime(engine) {
                conversation = nil
            }
        }
        lastBenchmarkInfo = nil
        lastTokenLatenciesMs = []
        lastStreamedTokenCount = 0

        let config = ConversationConfig(samplerConfig: activeSamplerConfig)
        conversation = try await engine.createConversation(with: config)
    }

    func warmup() async throws {
        for try await _ in streamMessage("Hi", maxTokens: 8, onToken: nil) {}
    }

    func streamMessage(
        _ text: String,
        maxTokens: Int,
        onToken: ((Int) -> Void)?
    ) -> AsyncThrowingStream<String, Error> {
        guard let conversation else {
            return AsyncThrowingStream { $0.finish(throwing: LabEngineError.notInitialized) }
        }

        let stream: AsyncThrowingStream<String, Error>
        var continuation: AsyncThrowingStream<String, Error>.Continuation!
        stream = AsyncThrowingStream { continuation = $0 }

        continuation.onTermination = { [weak self] _ in
            Task { @MainActor in
                try? self?.conversation?.cancel()
                self?.activeInferenceTask?.cancel()
            }
        }

        let task = Task { @MainActor [conversation] in
            defer { self.activeInferenceTask = nil }

            let start = DeviceContext.captureSnapshot()
            lastThermalStart = start.thermalLevel
            lastMemoryStartMB = start.availableMemoryMB
            var tokenTimestamps: [CFAbsoluteTime] = []
            let inferenceStart = CFAbsoluteTimeGetCurrent()
            var tokenCount = 0

            do {
                for try await chunk in conversation.sendMessageStream(Message(text)) {
                    try Task.checkCancellation()
                    if Task.isCancelled { break }

                    guard let piece = Self.text(from: chunk), !piece.isEmpty else { continue }

                    tokenTimestamps.append(CFAbsoluteTimeGetCurrent())
                    tokenCount += 1
                    lastStreamedTokenCount = tokenCount
                    onToken?(tokenCount)
                    continuation.yield(piece)
                    if tokenCount >= maxTokens { break }
                }

                let end = DeviceContext.captureSnapshot()
                lastThermalEnd = end.thermalLevel
                lastMemoryEndMB = end.availableMemoryMB
                lastMemoryDeltaMB = end.availableMemoryMB - start.availableMemoryMB

                var latencies: [Double] = []
                if let first = tokenTimestamps.first {
                    latencies.append((first - inferenceStart) * 1000)
                    for i in 1..<tokenTimestamps.count {
                        latencies.append((tokenTimestamps[i] - tokenTimestamps[i - 1]) * 1000)
                    }
                }
                lastTokenLatenciesMs = latencies

                if ExperimentalFlags.enableBenchmark {
                    do {
                        lastBenchmarkInfo = try conversation.getBenchmarkInfo()
                    } catch {
                        lastBenchmarkInfo = nil
                    }
                }
                continuation.finish()
            } catch {
                continuation.finish(throwing: error)
            }
        }
        activeInferenceTask = task
        return stream
    }

    /// Extracts streamable text from model chunks (content array or Gemma channels).
    nonisolated static func text(from message: Message) -> String? {
        var parts: [String] = []
        for content in message.contents {
            if case .text(let text) = content, !text.isEmpty {
                parts.append(text)
            }
        }
        if !parts.isEmpty {
            return parts.joined()
        }
        if !message.channels.isEmpty {
            let channelText = message.channels.values.filter { !$0.isEmpty }.joined(separator: " ")
            return channelText.isEmpty ? nil : channelText
        }
        return nil
    }

    var medianTokenLatencyMs: Double {
        guard !lastTokenLatenciesMs.isEmpty else { return 0 }
        let sorted = lastTokenLatenciesMs.sorted()
        let mid = sorted.count / 2
        if sorted.count.isMultiple(of: 2) {
            return (sorted[mid - 1] + sorted[mid]) / 2
        }
        return sorted[mid]
    }

    func shutdown() async {
        activeInferenceTask?.cancel()
        await finishActiveInferenceTask()
        if let engineRef = engine {
            withExtendedLifetime(engineRef) { conversation = nil }
        } else {
            conversation = nil
        }
        engine = nil
        loadedModelPath = nil
        loadedUsesGPU = nil
        lastBenchmarkInfo = nil
        activeSamplerConfig = nil
        lastStreamedTokenCount = 0
    }

    private func finishActiveInferenceTask() async {
        guard let task = activeInferenceTask else { return }
        _ = await task.result
        activeInferenceTask = nil
    }

    private func initializeEngine(
        path: String,
        useGPU: Bool,
        cacheDir: String,
        sampler: SamplerConfig?
    ) async throws {
        let config = try EngineConfig(
            modelPath: path,
            backend: useGPU ? .gpu : .cpu(),
            cacheDir: cacheDir
        )
        let newEngine = Engine(engineConfig: config)
        try await newEngine.initialize()
        engine = newEngine
        let convConfig = ConversationConfig(samplerConfig: sampler)
        conversation = try await newEngine.createConversation(with: convConfig)
    }

    private func makeCacheDirectory(for modelPath: String) throws -> String {
        let fileManager = FileManager.default
        guard let cacheBase = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            throw LabEngineError.notInitialized
        }
        let name = (modelPath as NSString).lastPathComponent
        let dir = cacheBase.appendingPathComponent("edge-lab-\(name)")
        if !fileManager.fileExists(atPath: dir.path) {
            try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir.path
    }
}