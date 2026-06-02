import Foundation
import Observation
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
    var matrixProgress: String = ""
    var lastManifest: MatrixManifest?

    let engine = LabEngine()

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

    func runMatrix() async {
        guard let model = selectedModel else {
            statusMessage = "Select a model first."
            return
        }

        isRunningMatrix = true
        matrixResults = []
        matrixProgress = "Starting…"
        statusMessage = "Running experiment matrix…"

        let results = await MatrixRunner.runMatrix(
            modelPath: model.url.path,
            modelFilename: model.filename,
            engine: engine
        ) { current, total, label in
            self.matrixProgress = "Run \(current)/\(total) — \(label)"
        }

        matrixResults = results
        lastManifest = MatrixManifest.build(
            modelFilename: model.filename,
            decodeCap: MatrixBenchmark.decodeCap,
            results: results
        )
        isRunningMatrix = false
        matrixProgress = ""

        let successes = results.filter(\.succeeded).count
        statusMessage = "Matrix complete: \(successes)/\(results.count) succeeded."
    }

    func exportManifestData() throws -> Data {
        guard let manifest = lastManifest else {
            throw NSError(domain: "EdgeLab", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Run the matrix first to generate a manifest.",
            ])
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(manifest)
    }
}