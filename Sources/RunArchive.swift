import Foundation

struct RunArchiveBundle: Sendable {
    let jsonURL: URL
    let markdownURL: URL
    let csvURL: URL

    func url(for kind: ShareExportKind) -> URL? {
        switch kind {
        case .json: return jsonURL
        case .markdown: return markdownURL
        case .csv: return csvURL
        case .tweet, .tweetThread, .copySummary: return nil
        }
    }

    func urls(for kinds: [ShareExportKind]) -> [URL] {
        kinds.compactMap { url(for: $0) }
    }
}

/// Saves manifests to Documents for easy sharing and contributor uploads.
enum RunArchive {
    static func save(manifest: MatrixManifest, data: Data) throws -> RunArchiveBundle {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let runsDir = docs.appendingPathComponent("EdgeLabRuns", isDirectory: true)
        try FileManager.default.createDirectory(at: runsDir, withIntermediateDirectories: true)

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let stamp = formatter.string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
        let base = "edge-lab-\(stamp)"
        let jsonURL = runsDir.appendingPathComponent("\(base).json")
        try data.write(to: jsonURL, options: .atomic)

        let mdURL = runsDir.appendingPathComponent("\(base).md")
        try ShareFormats.markdownReport(manifest: manifest).write(to: mdURL, atomically: true, encoding: .utf8)

        let csvURL = runsDir.appendingPathComponent("\(base).csv")
        try ShareFormats.csvReport(manifest: manifest).write(to: csvURL, atomically: true, encoding: .utf8)

        return RunArchiveBundle(jsonURL: jsonURL, markdownURL: mdURL, csvURL: csvURL)
    }

    static var runsDirectoryURL: URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?
            .appendingPathComponent("EdgeLabRuns", isDirectory: true)
    }
}