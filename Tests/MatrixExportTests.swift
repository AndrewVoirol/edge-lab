import XCTest
import LiteRTLM
@testable import EdgeLab

final class MatrixExportTests: XCTestCase {
    func testManifestEncodesWithSnakeCaseKeys() throws {
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
            prefillTokenCount: 120,
            decodeTokens: 256,
            wallClockSeconds: 48.2,
            medianTokenLatencyMs: 12.5,
            memoryStartMB: 4096,
            memoryEndMB: 4083.5,
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
        let json = String(data: data, encoding: .utf8)!
        XCTAssertTrue(json.contains("\"schema_version\":\"1.1\""))
        XCTAssertTrue(json.contains("wall_clock_seconds"))
        let decoded = try JSONDecoder().decode(MatrixManifest.self, from: data)
        XCTAssertEqual(decoded.schemaVersion, "1.1")
        XCTAssertEqual(decoded.runMode, "full")
        XCTAssertEqual(decoded.matrix.count, 1)
        XCTAssertEqual(decoded.matrix[0].metrics?.decodeTokens, 256)
    }

    func testShareFormats() throws {
        let preset = MatrixPreset.all[1]
        let result = MatrixRunResult(
            id: preset.id,
            preset: preset,
            activeBackend: "gpu",
            didFallback: false,
            decodeTokensPerSecond: 30.0,
            prefillTokensPerSecond: 40.0,
            ttftSeconds: 0.3,
            initTimeSeconds: 2.0,
            prefillTokenCount: 100,
            decodeTokens: 256,
            wallClockSeconds: 60,
            medianTokenLatencyMs: 15,
            memoryStartMB: 4000,
            memoryEndMB: 3990,
            thermalStart: .nominal,
            thermalEnd: .nominal,
            memoryDeltaMB: -10,
            errorMessage: nil
        )
        let manifest = MatrixManifest.build(
            modelFilename: "test.litertlm",
            decodeCap: 256,
            results: [result]
        )
        XCTAssertFalse(ShareFormats.markdownReport(manifest: manifest).isEmpty)
        XCTAssertTrue(ShareFormats.csvReport(manifest: manifest).contains("preset_id"))
        XCTAssertTrue(ShareFormats.tweetText(manifest: manifest).contains("Edge Lab"))
    }

    func testPresetCount() {
        XCTAssertEqual(MatrixPreset.all.count, 4)
    }

    func testTextExtractionFromChannels() {
        let message = Message(contents: [], channels: ["default": "Hello"])
        XCTAssertEqual(LabEngine.text(from: message), "Hello")
    }
}