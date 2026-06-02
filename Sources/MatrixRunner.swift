import Foundation
import LiteRTLM

@MainActor
enum MatrixRunner {
    typealias ProgressHandler = (MatrixProgressUpdate) -> Void
    typealias ResultHandler = (MatrixRunResult) -> Void

    static func runMatrix(
        modelPath: String,
        modelFilename: String,
        engine: LabEngine,
        onProgress: @escaping ProgressHandler,
        onResult: @escaping ResultHandler
    ) async throws -> [MatrixRunResult] {
        let matrixStart = CFAbsoluteTimeGetCurrent()
        var allResults: [MatrixRunResult] = []

        let gpuPresets = MatrixPreset.all.filter { !$0.forceCPU }
        let cpuPresets = MatrixPreset.all.filter { $0.forceCPU }

        try await runPresetGroup(
            presets: gpuPresets,
            modelPath: modelPath,
            engine: engine,
            backendGroup: "GPU",
            matrixStart: matrixStart,
            runOffset: 0,
            totalRuns: MatrixPreset.all.count,
            onProgress: onProgress,
            onResult: { result in
                allResults.append(result)
                onResult(result)
            }
        )

        try await runPresetGroup(
            presets: cpuPresets,
            modelPath: modelPath,
            engine: engine,
            backendGroup: "CPU",
            matrixStart: matrixStart,
            runOffset: gpuPresets.count,
            totalRuns: MatrixPreset.all.count,
            onProgress: onProgress,
            onResult: { result in
                allResults.append(result)
                onResult(result)
            }
        )

        return allResults
    }

    private static func runPresetGroup(
        presets: [MatrixPreset],
        modelPath: String,
        engine: LabEngine,
        backendGroup: String,
        matrixStart: CFAbsoluteTime,
        runOffset: Int,
        totalRuns: Int,
        onProgress: @escaping ProgressHandler,
        onResult: @escaping ResultHandler
    ) async throws {
        guard !presets.isEmpty else { return }

        for (index, preset) in presets.enumerated() {
            try Task.checkCancellation()
            let runIndex = runOffset + index + 1
            let presetStart = CFAbsoluteTimeGetCurrent()

            report(
                runIndex: runIndex,
                totalRuns: totalRuns,
                preset: preset.label,
                phase: .loadingModel,
                tokens: 0,
                matrixStart: matrixStart,
                backendGroup: backendGroup,
                onProgress: onProgress
            )

            var initResult: BackendInitResult?
            do {
                let loaded = try await engine.ensureLoaded(
                    path: modelPath,
                    preferGPU: preset.preferGPU,
                    forceCPU: preset.forceCPU,
                    samplerConfig: preset.samplerConfig
                )
                initResult = loaded

                report(
                    runIndex: runIndex,
                    totalRuns: totalRuns,
                    preset: preset.label,
                    phase: .warmup,
                    tokens: 0,
                    matrixStart: matrixStart,
                    backendGroup: backendGroup,
                    onProgress: onProgress
                )
                // Warmup is turn 1 (primes BenchmarkInfo). Benchmark must be turn 2 on the same session.
                try await engine.warmup()

                var tokenCount = 0
                report(
                    runIndex: runIndex,
                    totalRuns: totalRuns,
                    preset: preset.label,
                    phase: .benchmark,
                    tokens: 0,
                    matrixStart: matrixStart,
                    backendGroup: backendGroup,
                    onProgress: onProgress
                )

                for try await _ in engine.streamMessage(
                    MatrixBenchmark.prefillPrompt,
                    maxTokens: MatrixBenchmark.decodeCap,
                    onToken: { count in
                        tokenCount = count
                        report(
                            runIndex: runIndex,
                            totalRuns: totalRuns,
                            preset: preset.label,
                            phase: .benchmark,
                            tokens: count,
                            matrixStart: matrixStart,
                            backendGroup: backendGroup,
                            onProgress: onProgress
                        )
                    }
                ) {}

                let wallClock = CFAbsoluteTimeGetCurrent() - presetStart
                let backend = loaded.activeBackend
                let fallback = loaded.didFallback
                tokenCount = max(tokenCount, engine.lastStreamedTokenCount)

                guard let info = engine.lastBenchmarkInfo else {
                    let detail = engine.lastStreamedTokenCount > 0
                        ? "BenchmarkInfo unavailable after \(engine.lastStreamedTokenCount) streamed tokens."
                        : "BenchmarkInfo unavailable (no tokens streamed — check model/SDK)."
                    let failure = failureResult(
                        preset: preset,
                        backend: backend,
                        fallback: fallback,
                        wallClock: wallClock,
                        engine: engine,
                        message: detail
                    )
                    onResult(failure)
                    continue
                }

                let success = MatrixRunResult(
                    id: preset.id,
                    preset: preset,
                    activeBackend: backend,
                    didFallback: fallback,
                    decodeTokensPerSecond: info.lastDecodeTokensPerSecond,
                    prefillTokensPerSecond: info.lastPrefillTokensPerSecond,
                    ttftSeconds: info.timeToFirstTokenInSecond,
                    initTimeSeconds: info.initTimeInSecond,
                    prefillTokenCount: info.lastPrefillTokenCount,
                    decodeTokens: min(tokenCount, MatrixBenchmark.decodeCap),
                    wallClockSeconds: wallClock,
                    medianTokenLatencyMs: engine.medianTokenLatencyMs,
                    memoryStartMB: engine.lastMemoryStartMB,
                    memoryEndMB: engine.lastMemoryEndMB,
                    thermalStart: engine.lastThermalStart,
                    thermalEnd: engine.lastThermalEnd,
                    memoryDeltaMB: engine.lastMemoryDeltaMB,
                    errorMessage: nil
                )
                onResult(success)

                report(
                    runIndex: runIndex,
                    totalRuns: totalRuns,
                    preset: preset.label,
                    phase: .cooldown,
                    tokens: tokenCount,
                    matrixStart: matrixStart,
                    backendGroup: backendGroup,
                    onProgress: onProgress
                )
            } catch is CancellationError {
                throw LabEngineError.cancelled
            } catch {
                let wallClock = CFAbsoluteTimeGetCurrent() - presetStart
                onResult(
                    failureResult(
                        preset: preset,
                        backend: initResult?.activeBackend ?? "—",
                        fallback: initResult?.didFallback ?? false,
                        wallClock: wallClock,
                        engine: engine,
                        message: error.localizedDescription
                    )
                )
            }

            try await Task.sleep(nanoseconds: 1_000_000_000)
        }
    }

    private static func report(
        runIndex: Int,
        totalRuns: Int,
        preset: String,
        phase: MatrixProgressUpdate.Phase,
        tokens: Int,
        matrixStart: CFAbsoluteTime,
        backendGroup: String,
        onProgress: @escaping ProgressHandler
    ) {
        onProgress(
            MatrixProgressUpdate(
                runIndex: runIndex,
                totalRuns: totalRuns,
                presetLabel: preset,
                phase: phase,
                tokensGenerated: tokens,
                decodeCap: MatrixBenchmark.decodeCap,
                elapsedSeconds: CFAbsoluteTimeGetCurrent() - matrixStart,
                backendGroup: backendGroup
            )
        )
    }

    private static func failureResult(
        preset: MatrixPreset,
        backend: String,
        fallback: Bool,
        wallClock: Double,
        engine: LabEngine,
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
            prefillTokenCount: 0,
            decodeTokens: 0,
            wallClockSeconds: wallClock,
            medianTokenLatencyMs: 0,
            memoryStartMB: engine.lastMemoryStartMB,
            memoryEndMB: engine.lastMemoryEndMB,
            thermalStart: engine.lastThermalStart,
            thermalEnd: engine.lastThermalEnd,
            memoryDeltaMB: engine.lastMemoryDeltaMB,
            errorMessage: message
        )
    }
}