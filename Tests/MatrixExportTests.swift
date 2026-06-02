import XCTest
@testable import EdgeLab

final class MatrixExportTests: XCTestCase {
    func testManifestEncodes() throws {
        let preset = MatrixPreset.all[0]
        let result = MatrixRunResult(
            id: preset.id,
            preset: preset,
            activeBackend: "gpu",
            didFallback: false,
            decodeTokensPerSecond: 42.5,
            prefillTokensPerSecond: 55.0,
            ttftSeconds: 0.21,
            initTimeSeconds: 3.2,
            decodeTokens: 256,
            thermalStart: .nominal,
            thermalEnd: .fair,
            memoryDeltaMB: -12.5,
            errorMessage: nil
        )
        let manifest = MatrixManifest.build(
            modelFilename: "gemma-4-E2B-it.litertlm",
            decodeCap: 256,
            results: [result]
        )
        let data = try JSONEncoder().encode(manifest)
        XCTAssertFalse(data.isEmpty)
        let decoded = try JSONDecoder().decode(MatrixManifest.self, from: data)
        XCTAssertEqual(decoded.schemaVersion, "1.0")
        XCTAssertEqual(decoded.matrix.count, 1)
    }

    func testPresetCount() {
        XCTAssertEqual(MatrixPreset.all.count, 4)
    }
}