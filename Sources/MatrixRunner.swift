import Foundation
import LiteRTLM

@MainActor
enum MatrixRunner {
    static func runMatrix(
        modelPath: String,
        modelFilename: String,
        engine: LabEngine,
        onProgress: @escaping (Int, Int, String) -> Void
    ) async -> [MatrixRunResult] {
        var results: [MatrixRunResult] = []
        let presets = MatrixPreset.all
        let total = presets.count

        for (index, preset) in presets.enumerated() {
            onProgress(index + 1, total, preset.label)

            do {
                let initResult = try await engine.loadModel(
                    path: modelPath,
                    preferGPU: preset.preferGPU,
                    forceCPU: preset.forceCPU,
                    samplerConfig: preset.samplerConfig
                )

                try await engine.resetConversation()
                try await engine.warmup()
                try await engine.resetConversation()

                var tokenCount = 0
                for try await _ in engine.streamMessage(
                    MatrixBenchmark.prefillPrompt,
                    maxTokens: MatrixBenchmark.decodeCap
                ) {
                    tokenCount += 1
                }

                guard let info = engine.lastBenchmarkInfo else {
                    results.append(failureResult(
                        preset: preset,
                        backend: initResult.activeBackend,
                        fallback: initResult.didFallback,
                        message: "BenchmarkInfo unavailable after run."
                    ))
                    continue
                }

                results.append(
                    MatrixRunResult(
                        id: preset.id,
                        preset: preset,
                        activeBackend: initResult.activeBackend,
                        didFallback: initResult.didFallback,
                        decodeTokensPerSecond: info.lastDecodeTokensPerSecond,
                        prefillTokensPerSecond: info.lastPrefillTokensPerSecond,
                        ttftSeconds: info.timeToFirstTokenInSecond,
                        initTimeSeconds: info.initTimeInSecond,
                        decodeTokens: min(tokenCount, MatrixBenchmark.decodeCap),
                        thermalStart: engine.lastThermalStart,
                        thermalEnd: engine.lastThermalEnd,
                        memoryDeltaMB: engine.lastMemoryDeltaMB,
                        errorMessage: nil
                    )
                )
            } catch {
                results.append(failureResult(
                    preset: preset,
                    backend: "—",
                    fallback: false,
                    message: error.localizedDescription
                ))
            }

            try? await Task.sleep(nanoseconds: 1_500_000_000)
        }

        return results
    }

    private static func failureResult(
        preset: MatrixPreset,
        backend: String,
        fallback: Bool,
        message: String
    ) -> MatrixRunResult {
        MatrixRunResult(
            id: preset.id,
            preset: preset,
            activeBackend: backend,
            didFallback: fallback,
            decodeTokensPerSecond: 0,
            prefillTokensPerSecond: 0,
            ttftSeconds: 0,
            initTimeSeconds: 0,
            decodeTokens: 0,
            thermalStart: .nominal,
            thermalEnd: .nominal,
            memoryDeltaMB: 0,
            errorMessage: message
        )
    }
}