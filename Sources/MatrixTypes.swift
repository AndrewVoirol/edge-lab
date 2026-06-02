import Foundation
import LiteRTLM

// MARK: - Matrix presets

struct MatrixPreset: Identifiable, Sendable {
    let id: String
    let label: String
    let preferGPU: Bool
    let forceCPU: Bool
    let topK: Int
    let topP: Float
    let temperature: Float

    static let all: [MatrixPreset] = [
        MatrixPreset(
            id: "gallery_greedy_gpu",
            label: "Gallery greedy",
            preferGPU: true,
            forceCPU: false,
            topK: 1,
            topP: 1.0,
            temperature: 1.0
        ),
        MatrixPreset(
            id: "sdk_default_gpu",
            label: "SDK default",
            preferGPU: true,
            forceCPU: false,
            topK: 64,
            topP: 0.95,
            temperature: 1.0
        ),
        MatrixPreset(
            id: "cpu_greedy",
            label: "CPU baseline",
            preferGPU: false,
            forceCPU: true,
            topK: 1,
            topP: 1.0,
            temperature: 1.0
        ),
        MatrixPreset(
            id: "cpu_sampled",
            label: "CPU sampled",
            preferGPU: false,
            forceCPU: true,
            topK: 64,
            topP: 0.95,
            temperature: 1.0
        ),
    ]

    var samplerConfig: SamplerConfig? {
        try? SamplerConfig(topK: topK, topP: topP, temperature: temperature)
    }
}

// MARK: - Run results

struct MatrixRunResult: Identifiable, Sendable {
    let id: String
    let preset: MatrixPreset
    let activeBackend: String
    let didFallback: Bool
    let decodeTokensPerSecond: Double
    let prefillTokensPerSecond: Double
    let ttftSeconds: Double
    let initTimeSeconds: Double
    let decodeTokens: Int
    let thermalStart: ThermalLevel
    let thermalEnd: ThermalLevel
    let memoryDeltaMB: Double
    let errorMessage: String?

    var succeeded: Bool { errorMessage == nil }
}

// MARK: - Export manifest

struct MatrixManifest: Codable, Sendable {
    let schemaVersion: String
    let app: String
    let appVersion: String
    let createdAt: String
    let device: DeviceInfo
    let model: ModelInfo
    let litertLmVersion: String
    let decodeCap: Int
    let matrix: [MatrixEntry]

    struct DeviceInfo: Codable, Sendable {
        let modelIdentifier: String
        let marketingName: String
        let osVersion: String
    }

    struct ModelInfo: Codable, Sendable {
        let filename: String
    }

    struct MatrixEntry: Codable, Sendable {
        let presetId: String
        let presetLabel: String
        let backend: String
        let didFallback: Bool
        let sampler: SamplerInfo
        let metrics: MetricsInfo?

        struct SamplerInfo: Codable, Sendable {
            let topK: Int
            let topP: Float
            let temperature: Float
        }

        struct MetricsInfo: Codable, Sendable {
            let decodeTokensPerSecond: Double
            let prefillTokensPerSecond: Double
            let ttftSeconds: Double
            let initTimeSeconds: Double
            let decodeTokens: Int
            let thermalStart: String
            let thermalEnd: String
            let memoryDeltaMB: Double
        }
    }
}

extension MatrixManifest {
    static func build(
        modelFilename: String,
        decodeCap: Int,
        results: [MatrixRunResult]
    ) -> MatrixManifest {
        let formatter = ISO8601DateFormatter()
        return MatrixManifest(
            schemaVersion: "1.0",
            app: "edge-lab",
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0",
            createdAt: formatter.string(from: Date()),
            device: DeviceInfo(
                modelIdentifier: DeviceContext.machineIdentifier,
                marketingName: DeviceContext.marketingName,
                osVersion: ProcessInfo.processInfo.operatingSystemVersionString
            ),
            model: ModelInfo(filename: modelFilename),
            litertLmVersion: "0.12.0",
            decodeCap: decodeCap,
            matrix: results.map { run in
                MatrixEntry(
                    presetId: run.preset.id,
                    presetLabel: run.preset.label,
                    backend: run.activeBackend,
                    didFallback: run.didFallback,
                    sampler: MatrixEntry.SamplerInfo(
                        topK: run.preset.topK,
                        topP: run.preset.topP,
                        temperature: run.preset.temperature
                    ),
                    metrics: run.succeeded
                        ? MatrixEntry.MetricsInfo(
                            decodeTokensPerSecond: run.decodeTokensPerSecond,
                            prefillTokensPerSecond: run.prefillTokensPerSecond,
                            ttftSeconds: run.ttftSeconds,
                            initTimeSeconds: run.initTimeSeconds,
                            decodeTokens: run.decodeTokens,
                            thermalStart: run.thermalStart.rawValue,
                            thermalEnd: run.thermalEnd.rawValue,
                            memoryDeltaMB: run.memoryDeltaMB
                        )
                        : nil
                )
            }
        )
    }
}

enum MatrixBenchmark {
    static let decodeCap = 256

    static let prefillPrompt = """
    You are a helpful assistant. Provide a detailed explanation of on-device large language models on mobile phones. \
    Cover model quantization, KV cache memory, GPU and CPU backends, thermal throttling, time-to-first-token, \
    decode tokens per second, and how frameworks like LiteRT-LM enable private inference without cloud connectivity. \
    Discuss Gemma family models, experiment reproducibility, and why open benchmark manifests matter for edge AI research. \
    Include practical notes for iPhone hardware, memory limits, and comparing greedy versus sampled decoding configurations.
    """
}