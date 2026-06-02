import Foundation

struct MatrixProgressUpdate: Sendable {
    enum Phase: String, Sendable {
        case loadingModel = "Loading model"
        case warmup = "Warmup"
        case benchmark = "Benchmark"
        case saving = "Saving"
        case cooldown = "Cooldown"
    }

    let runIndex: Int
    let totalRuns: Int
    let presetLabel: String
    let phase: Phase
    let tokensGenerated: Int
    let decodeCap: Int
    let elapsedSeconds: TimeInterval
    let backendGroup: String
}