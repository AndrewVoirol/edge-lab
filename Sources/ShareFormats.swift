import Foundation
import UIKit

enum ShareExportKind: String, CaseIterable, Identifiable {
    case json
    case markdown
    case csv
    case tweet
    case copySummary

    var id: String { rawValue }

    var title: String {
        switch self {
        case .json: return "JSON manifest"
        case .markdown: return "Markdown report"
        case .csv: return "CSV (spreadsheet)"
        case .tweet: return "Tweet text"
        case .copySummary: return "Copy summary"
        }
    }
}

enum ShareFormats {
    static func jsonData(manifest: MatrixManifest) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(manifest)
    }

    static func markdownReport(manifest: MatrixManifest) -> String {
        var lines: [String] = [
            "# Edge Lab Matrix Run",
            "",
            "- **Device:** \(manifest.device.marketingName) (`\(manifest.device.modelIdentifier)`)",
            "- **OS:** \(manifest.device.osVersion)",
            "- **Model:** `\(manifest.model.filename)`",
            "- **LiteRT-LM:** \(manifest.litertLmVersion)",
            "- **Decode cap:** \(manifest.decodeCap)",
            "- **Created:** \(manifest.createdAt)",
            "",
            "| Preset | Backend | Decode tok/s | Prefill tok/s | TTFT | Wall | Thermal |",
            "|--------|---------|--------------|---------------|------|------|---------|",
        ]

        for entry in manifest.matrix {
            if let m = entry.metrics {
                lines.append(
                    "| \(entry.presetLabel) | \(entry.backend) | \(String(format: "%.1f", m.decodeTokensPerSecond)) | \(String(format: "%.1f", m.prefillTokensPerSecond)) | \(String(format: "%.2f", m.ttftSeconds))s | \(String(format: "%.0f", m.wallClockSeconds))s | \(m.thermalEnd) |"
                )
            } else {
                lines.append("| \(entry.presetLabel) | — | *failed* | — | — | — | — |")
            }
        }

        lines.append("")
        lines.append("Generated with [Edge Lab](https://github.com/andrewvoirol/edge-lab) · [ableandrew.com](https://ableandrew.com)")
        return lines.joined(separator: "\n")
    }

    static func csvReport(manifest: MatrixManifest) -> String {
        var rows = [
            "preset_id,preset_label,backend,decode_tok_s,prefill_tok_s,ttft_s,init_s,prefill_tokens,decode_tokens,wall_clock_s,median_token_latency_ms,thermal_end,memory_delta_mb",
        ]
        for entry in manifest.matrix {
            guard let m = entry.metrics else { continue }
            rows.append(
                [
                    entry.presetId,
                    entry.presetLabel,
                    entry.backend,
                    String(format: "%.2f", m.decodeTokensPerSecond),
                    String(format: "%.2f", m.prefillTokensPerSecond),
                    String(format: "%.3f", m.ttftSeconds),
                    String(format: "%.2f", m.initTimeSeconds),
                    String(m.prefillTokenCount),
                    String(m.decodeTokens),
                    String(format: "%.1f", m.wallClockSeconds),
                    String(format: "%.2f", m.medianTokenLatencyMs),
                    m.thermalEnd,
                    String(format: "%.1f", m.memoryDeltaMB),
                ].joined(separator: ",")
            )
        }
        return rows.joined(separator: "\n")
    }

    static func tweetText(manifest: MatrixManifest) -> String {
        let ranked = manifest.matrix.compactMap { entry -> (String, Double)? in
            guard let m = entry.metrics else { return nil }
            return (entry.presetLabel, m.decodeTokensPerSecond)
        }
        let best = ranked.max(by: { $0.1 < $1.1 })
        let bestLine: String
        if let best {
            bestLine = "Peak decode \(String(format: "%.1f", best.1)) tok/s (\(best.0))."
        } else {
            bestLine = "4-preset on-device matrix."
        }

        let model = manifest.model.filename
        return """
        Edge Lab: \(bestLine) \(manifest.device.marketingName), \(model), fully local BYOM .litertlm — no cloud. JSON + report in 🧵

        https://github.com/andrewvoirol/edge-lab · https://ableandrew.com
        """
    }

    static func shortSummary(manifest: MatrixManifest) -> String {
        markdownReport(manifest: manifest)
    }

    static func writeTempFile(manifest: MatrixManifest, kind: ShareExportKind) throws -> URL {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let stamp = formatter.string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let temp = FileManager.default.temporaryDirectory

        switch kind {
        case .json:
            let url = temp.appendingPathComponent("edge-lab-\(stamp).json")
            try jsonData(manifest: manifest).write(to: url)
            return url
        case .markdown:
            let url = temp.appendingPathComponent("edge-lab-\(stamp).md")
            try markdownReport(manifest: manifest).write(to: url, atomically: true, encoding: .utf8)
            return url
        case .csv:
            let url = temp.appendingPathComponent("edge-lab-\(stamp).csv")
            try csvReport(manifest: manifest).write(to: url, atomically: true, encoding: .utf8)
            return url
        case .tweet:
            let url = temp.appendingPathComponent("edge-lab-\(stamp)-tweet.txt")
            try tweetText(manifest: manifest).write(to: url, atomically: true, encoding: .utf8)
            return url
        case .copySummary:
            let url = temp.appendingPathComponent("edge-lab-\(stamp)-summary.md")
            try shortSummary(manifest: manifest).write(to: url, atomically: true, encoding: .utf8)
            return url
        }
    }

    static func copyToPasteboard(_ text: String) {
        UIPasteboard.general.string = text
    }
}