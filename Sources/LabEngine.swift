import Foundation
import LiteRTLM

struct BackendInitResult: Sendable {
    let activeBackend: String
    let didFallback: Bool
}

enum LabEngineError: LocalizedError {
    case notInitialized
    case bothBackendsFailed(String)

    var errorDescription: String? {
        switch self {
        case .notInitialized:
            return "Load a model before running the matrix."
        case .bothBackendsFailed(let message):
            return message
        }
    }
}

@MainActor
final class LabEngine {
    private var engine: Engine?
    private var conversation: Conversation?
    private var activeSamplerConfig: SamplerConfig?
    private var activeInferenceTask: Task<Void, Never>?

    private(set) var lastBenchmarkInfo: BenchmarkInfo?
    private(set) var lastThermalStart: ThermalLevel = .nominal
    private(set) var lastThermalEnd: ThermalLevel = .nominal
    private(set) var lastMemoryDeltaMB: Double = 0

    var isReady: Bool { conversation != nil }

    func loadModel(
        path: String,
        preferGPU: Bool,
        forceCPU: Bool,
        samplerConfig: SamplerConfig?
    ) async throws -> BackendInitResult {
        await shutdown()

        ExperimentalFlags.optIntoExperimentalAPIs()
        ExperimentalFlags.enableBenchmark = true

        activeSamplerConfig = samplerConfig
        let cacheDir = try makeCacheDirectory(for: path)

        let tryGPUFirst = forceCPU ? false : preferGPU
        do {
            try await initializeEngine(path: path, useGPU: tryGPUFirst, cacheDir: cacheDir, sampler: samplerConfig)
            return BackendInitResult(
                activeBackend: tryGPUFirst ? "gpu" : "cpu",
                didFallback: !preferGPU && tryGPUFirst
            )
        } catch {
            let primaryError = error.localizedDescription
            let fallbackGPU = !tryGPUFirst
            do {
                try await initializeEngine(path: path, useGPU: fallbackGPU, cacheDir: cacheDir, sampler: samplerConfig)
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

    func resetConversation() async throws {
        guard let engine else { throw LabEngineError.notInitialized }

        if let task = activeInferenceTask {
            await task.value
            activeInferenceTask = nil
        }

        autoreleasepool {
            withExtendedLifetime(engine) {
                conversation = nil
            }
        }
        lastBenchmarkInfo = nil

        let config = ConversationConfig(samplerConfig: activeSamplerConfig)
        conversation = try await engine.createConversation(with: config)
    }

    func warmup() async throws {
        for try await _ in streamMessage("Hi", maxTokens: 8) {}
    }

    func streamMessage(_ text: String, maxTokens: Int) -> AsyncThrowingStream<String, Error> {
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
            let start = DeviceContext.captureSnapshot()
            lastThermalStart = start.thermalLevel
            var tokenCount = 0

            do {
                for try await chunk in conversation.sendMessageStream(Message(text)) {
                    if Task.isCancelled { break }
                    if let first = chunk.contents.first, case .text(let text) = first {
                        continuation.yield(text)
                        tokenCount += 1
                        if tokenCount >= maxTokens { break }
                    }
                }

                let end = DeviceContext.captureSnapshot()
                lastThermalEnd = end.thermalLevel
                lastMemoryDeltaMB = end.availableMemoryMB - start.availableMemoryMB

                lastBenchmarkInfo = try? conversation.getBenchmarkInfo()
                continuation.finish()
            } catch {
                continuation.finish(throwing: error)
            }
        }
        activeInferenceTask = task
        return stream
    }

    func shutdown() async {
        activeInferenceTask?.cancel()
        if let task = activeInferenceTask {
            _ = await task.result
            activeInferenceTask = nil
        }
        if let engineRef = engine {
            withExtendedLifetime(engineRef) { conversation = nil }
        } else {
            conversation = nil
        }
        engine = nil
        lastBenchmarkInfo = nil
        activeSamplerConfig = nil
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