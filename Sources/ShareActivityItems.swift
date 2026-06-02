import LinkPresentation
import UniformTypeIdentifiers
import UIKit

/// Shares matrix exports as text (Messages, Mail, Copy) or typed data via NSItemProvider (AirDrop, Files).
final class ManifestShareItem: NSObject, UIActivityItemSource {
    private let title: String
    private let text: String
    private let data: Data
    private let contentType: UTType
    private let filename: String

    init(title: String, text: String, data: Data, contentType: UTType, filename: String) {
        self.title = title
        self.text = text
        self.data = data
        self.contentType = contentType
        self.filename = filename
    }

    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        text
    }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        itemForActivityType activityType: UIActivity.ActivityType?
    ) -> Any? {
        guard let activityType else { return text }

        if activityType == .copyToPasteboard
            || activityType == .message
            || activityType == .mail
            || activityType == .postToTwitter
        {
            return text
        }

        let provider = NSItemProvider()
        provider.suggestedName = filename
        provider.registerDataRepresentation(
            forTypeIdentifier: contentType.identifier,
            visibility: .all
        ) { completion in
            completion(self.data, nil)
            return nil
        }
        return provider
    }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        subjectForActivityType activityType: UIActivity.ActivityType?
    ) -> String {
        title
    }

    func activityViewControllerLinkMetadata(_ activityViewController: UIActivityViewController) -> LPLinkMetadata? {
        let metadata = LPLinkMetadata()
        metadata.title = filename
        metadata.originalURL = URL(fileURLWithPath: filename)
        return metadata
    }
}

enum MatrixShareBuilder {
    static func activityItems(
        manifest: MatrixManifest,
        kinds: [ShareExportKind],
        archive: RunArchiveBundle?
    ) throws -> [Any] {
        var items: [Any] = []

        for kind in kinds {
            switch kind {
            case .json:
                let data = try ShareFormats.jsonData(manifest: manifest)
                let text = String(data: data, encoding: .utf8) ?? ""
                items.append(
                    ManifestShareItem(
                        title: "Edge Lab matrix manifest",
                        text: text,
                        data: data,
                        contentType: .json,
                        filename: archive?.jsonURL.lastPathComponent ?? "edge-lab-matrix.json"
                    )
                )
            case .markdown:
                let text = ShareFormats.markdownReport(manifest: manifest)
                let data = Data(text.utf8)
                items.append(
                    ManifestShareItem(
                        title: "Edge Lab matrix report",
                        text: text,
                        data: data,
                        contentType: .plainText,
                        filename: archive?.markdownURL.lastPathComponent ?? "edge-lab-matrix.md"
                    )
                )
            case .csv:
                let text = ShareFormats.csvReport(manifest: manifest)
                let data = Data(text.utf8)
                items.append(
                    ManifestShareItem(
                        title: "Edge Lab matrix CSV",
                        text: text,
                        data: data,
                        contentType: .commaSeparatedText,
                        filename: archive?.csvURL.lastPathComponent ?? "edge-lab-matrix.csv"
                    )
                )
            case .tweet:
                items.append(ShareFormats.tweetText(manifest: manifest))
            case .copySummary:
                items.append(ShareFormats.shortSummary(manifest: manifest))
            }
        }

        return items
    }
}