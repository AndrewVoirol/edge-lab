import Foundation
import UIKit

enum ShareExportKind: String, CaseIterable, Identifiable {
    case json
    case markdown
    case csv
    case tweet
    case tweetThread
    case copySummary

    var id: String { rawValue }

    var title: String {
        switch self {
        case .json: return "JSON manifest"
        case .markdown: return "Markdown report"
        case .csv: return "CSV (spreadsheet)"
        case .tweet: return "X post (no link)"
        case .tweetThread: return "X thread (3 tweets)"
        case .copySummary: return "Copy summary"
        }
    }
}

enum ShareFormats {
    private static let githubURL = "https://github.com/AndrewVoirol/edge-lab"
    private static let blogURL = "https://ableandrew.com"
    private static let twitterHandle = "@AI_Andrew"

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
            "| Preset | Config | Backend | Decode tok/s | TTFT | Wall |",
            "|--------|--------|---------|--------------|------|------|",
        ]

        for entry in manifest.matrix {
            let config = presetConfig(for: entry.presetId)
            if let m = entry.metrics {
                let backend = entry.didFallback ? "↺\(entry.backend)" : entry.backend
                lines.append(
                    "| \(entry.presetLabel) | \(config) | \(backend) | \(String(format: "%.1f", m.decodeTokensPerSecond)) | \(String(format: "%.2f", m.ttftSeconds))s | \(String(format: "%.0f", m.wallClockSeconds))s |"
                )
            } else {
                lines.append("| \(entry.presetLabel) | \(config) | — | *failed* | — | — |")
            }
        }

        lines.append("")
        lines.append("Generated with [Edge Lab](\(githubURL))")
        return lines.joined(separator: "\n")
    }

    static func csvReport(manifest: MatrixManifest) -> String {
        var rows = [
            "preset_id,preset_label,requested_backend,backend,did_fallback,decode_tok_s,prefill_tok_s,ttft_s,init_s,prefill_tokens,decode_tokens,wall_clock_s,median_token_latency_ms,thermal_end,memory_delta_mb",
        ]
        for entry in manifest.matrix {
            guard let m = entry.metrics else { continue }
            rows.append(
                [
                    entry.presetId,
                    entry.presetLabel,
                    entry.requestedBackend,
                    entry.backend,
                    entry.didFallback ? "true" : "false",
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

    /// Opening post only — no URLs (better reach on X). Links go in reply 2 of the thread.
    static func tweetPostText(manifest: MatrixManifest) -> String {
        let stats = tweetStatsLine(manifest: manifest)
        let model = manifest.model.filename
        let fallbackNote = manifest.matrix.contains(where: { $0.didFallback })
            ? "\n↺ = CPU preset ran on GPU (model has no CPU weights)."
            : ""

        return """
        Edge Lab — on-device Gemma matrix on \(manifest.device.marketingName)

        \(model)
        \(stats)

        BYOM .litertlm · fully local · no cloud · JSON manifest attached in replies.

        Run yours? Tag \(twitterHandle)\(fallbackNote)
        """
    }

    /// Full 3-tweet thread for paste into X (post + two replies).
    static func tweetThreadText(manifest: MatrixManifest) -> String {
        let post = tweetPostText(manifest: manifest)
        let breakdown = tweetPresetBreakdown(manifest: manifest)
        let links = """
        Repo + sample manifests:
        \(githubURL)

        Notes:
        \(blogURL)
        """

        return """
        ━━━ POST THIS (no link) ━━━
        \(post)

        ━━━ REPLY 1 ━━━
        \(breakdown)

        ━━━ REPLY 2 (links here) ━━━
        \(links)
        """
    }

    /// Backward-compatible alias.
    static func tweetText(manifest: MatrixManifest) -> String {
        tweetThreadText(manifest: manifest)
    }

    static func shortSummary(manifest: MatrixManifest) -> String {
        markdownReport(manifest: manifest)
    }

    private static func tweetStatsLine(manifest: MatrixManifest) -> String {
        var gpuBest: (String, Double)?
        var cpuBest: (String, Double)?

        for entry in manifest.matrix {
            guard let m = entry.metrics else { continue }
            if entry.requestedBackend == "gpu" {
                if gpuBest == nil || m.decodeTokensPerSecond > gpuBest!.1 {
                    gpuBest = (entry.presetLabel, m.decodeTokensPerSecond)
                }
            } else if entry.requestedBackend == "cpu", !entry.didFallback {
                if cpuBest == nil || m.decodeTokensPerSecond > cpuBest!.1 {
                    cpuBest = (entry.presetLabel, m.decodeTokensPerSecond)
                }
            }
        }

        var parts: [String] = []
        if let gpuBest {
            parts.append("GPU peak \(formatRate(gpuBest.1)) tok/s (\(gpuBest.0))")
        }
        if let cpuBest {
            parts.append("CPU peak \(formatRate(cpuBest.1)) tok/s (\(cpuBest.0))")
        }
        if parts.isEmpty, let any = manifest.matrix.compactMap({ e -> Double? in e.metrics?.decodeTokensPerSecond }).max() {
            return "Peak \(formatRate(any)) tok/s decode"
        }
        return parts.joined(separator: " · ")
    }

    private static func tweetPresetBreakdown(manifest: MatrixManifest) -> String {
        var lines = ["4 presets (all settings are in the JSON):"]
        for entry in manifest.matrix {
            let config = presetConfig(for: entry.presetId)
            guard let m = entry.metrics else {
                lines.append("• \(entry.presetLabel) — \(config) — failed")
                continue
            }
            let backend = entry.didFallback
                ? "requested \(entry.requestedBackend), ran \(entry.backend) ↺"
                : entry.requestedBackend
            lines.append(
                "• \(entry.presetLabel) (\(config)): \(formatRate(m.decodeTokensPerSecond)) tok/s decode, \(formatRate(m.wallClockSeconds))s wall, \(backend)"
            )
        }
        lines.append("")
        lines.append("Edge Lab is an open matrix runner — you don't need Google's closed Gallery app to interpret these numbers.")
        return lines.joined(separator: "\n")
    }

    private static func presetConfig(for presetId: String) -> String {
        MatrixPreset.all.first(where: { $0.id == presetId })?.subtitle
            ?? presetId
    }

    private static func formatRate(_ value: Double) -> String {
        String(format: "%.1f", value)
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
            let url = temp.appendingPathComponent("edge-lab-\(stamp)-x-post.txt")
            try tweetPostText(manifest: manifest).write(to: url, atomically: true, encoding: .utf8)
            return url
        case .tweetThread:
            let url = temp.appendingPathComponent("edge-lab-\(stamp)-x-thread.txt")
            try tweetThreadText(manifest: manifest).write(to: url, atomically: true, encoding: .utf8)
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