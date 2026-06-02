import Foundation
import Observation
import UIKit
import UniformTypeIdentifiers

@Observable
@MainActor
final class LabViewModel {
    var discoveredModels: [DiscoveredModel] = []
    var selectedModel: DiscoveredModel?
    var statusMessage = "Add a .litertlm model to get started."
    var isFilePickerPresented = false

    var matrixResults: [MatrixRunResult] = []
    var isRunningMatrix = false
    var matrixProgressDetail: MatrixProgressUpdate?
    var matrixProgressLine: String = ""
    var lastManifest: MatrixManifest?
    var lastArchivedRunURL: URL?
    var copiedToast: String?

    let engine = LabEngine()

    private var matrixTask: Task<Void, Never>?

    func refreshModels() {
        discoveredModels = ModelDiscovery.discoverModels()
        if selectedModel == nil, let first = discoveredModels.first {
            selectedModel = first
        }
        if discoveredModels.isEmpty {
            statusMessage = "No models found. Import a .litertlm file or copy one via Files."
        } else {
            statusMessage = "\(discoveredModels.count) model\(discoveredModels.count == 1 ? "" : "s") available."
        }
    }

    func selectModel(_ model: DiscoveredModel) {
        selectedModel = model
        statusMessage = "Selected \(model.filename)"
    }

    func handleImport(_ url: URL) {
        ModelDiscovery.bookmarkImportedModel(url)
        refreshModels()
        if let match = discoveredModels.first(where: { $0.filename == url.lastPathComponent }) {
            selectedModel = match
        }
    }

    func runMatrix() {
        guard let model = selectedModel else {
            statusMessage = "Select a model first."
            return
        }
        guard !isRunningMatrix else { return }

        matrixTask?.cancel()
        matrixTask = Task {
            await performMatrix(model: model)
        }
    }

    func cancelMatrix() {
        matrixTask?.cancel()
        matrixTask = nil
        isRunningMatrix = false
        matrixProgressDetail = nil
        matrixProgressLine = ""
        UIApplication.shared.isIdleTimerDisabled = false
        statusMessage = "Matrix cancelled."
        Task { await engine.shutdown() }
    }

    private func performMatrix(model: DiscoveredModel) async {
        isRunningMatrix = true
        matrixResults = []
        matrixProgressDetail = nil
        matrixProgressLine = "Starting…"
        lastArchivedRunURL = nil
        statusMessage = "Running experiment matrix…"
        UIApplication.shared.isIdleTimerDisabled = true

        defer {
            isRunningMatrix = false
            matrixProgressDetail = nil
            matrixProgressLine = ""
            UIApplication.shared.isIdleTimerDisabled = false
            matrixTask = nil
        }

        do {
            let results = try await MatrixRunner.runMatrix(
                modelPath: model.url.path,
                modelFilename: model.filename,
                engine: engine,
                onProgress: { update in
                    self.matrixProgressDetail = update
                    self.matrixProgressLine = Self.progressLine(for: update)
                },
                onResult: { result in
                    self.matrixResults.append(result)
                }
            )

            let manifest = MatrixManifest.build(
                modelFilename: model.filename,
                decodeCap: MatrixBenchmark.decodeCap,
                results: results
            )
            lastManifest = manifest

            let data = try ShareFormats.jsonData(manifest: manifest)
            lastArchivedRunURL = try RunArchive.save(manifest: manifest, data: data)

            let successes = results.filter(\.succeeded).count
            if lastArchivedRunURL != nil {
                statusMessage = "Matrix complete: \(successes)/\(results.count). Saved to Files → EdgeLabRuns."
            } else {
                statusMessage = "Matrix complete: \(successes)/\(results.count) succeeded."
            }
        } catch is CancellationError {
            statusMessage = "Matrix cancelled."
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private static func progressLine(for update: MatrixProgressUpdate) -> String {
        let elapsed = formatDuration(update.elapsedSeconds)
        let tokenLine: String
        if update.phase == .benchmark {
            tokenLine = " · \(update.tokensGenerated)/\(update.decodeCap) tokens"
        } else {
            tokenLine = ""
        }
        return "Run \(update.runIndex)/\(update.totalRuns) · \(update.backendGroup) · \(update.presetLabel) · \(update.phase.rawValue)\(tokenLine) · \(elapsed)"
    }

    private static func formatDuration(_ seconds: TimeInterval) -> String {
        let total = Int(seconds)
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
    }

    func exportManifestData() throws -> Data {
        guard let manifest = lastManifest else {
            throw NSError(domain: "EdgeLab", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Run the matrix first to generate a manifest.",
            ])
        }
        return try ShareFormats.jsonData(manifest: manifest)
    }

    func shareURLs(for kinds: [ShareExportKind]) throws -> [URL] {
        guard let manifest = lastManifest else {
            throw NSError(domain: "EdgeLab", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Run the matrix first.",
            ])
        }
        return try kinds.map { try ShareFormats.writeTempFile(manifest: manifest, kind: $0) }
    }

    func copyExport(_ kind: ShareExportKind) {
        guard let manifest = lastManifest else { return }
        switch kind {
        case .json:
            if let data = try? ShareFormats.jsonData(manifest: manifest),
               let text = String(data: data, encoding: .utf8) {
                ShareFormats.copyToPasteboard(text)
            }
        case .markdown:
            ShareFormats.copyToPasteboard(ShareFormats.markdownReport(manifest: manifest))
        case .csv:
            ShareFormats.copyToPasteboard(ShareFormats.csvReport(manifest: manifest))
        case .tweet:
            ShareFormats.copyToPasteboard(ShareFormats.tweetText(manifest: manifest))
        case .copySummary:
            ShareFormats.copyToPasteboard(ShareFormats.shortSummary(manifest: manifest))
        }
        copiedToast = "\(kind.title) copied"
    }
}