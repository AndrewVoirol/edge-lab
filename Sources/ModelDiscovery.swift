import Foundation

struct DiscoveredModel: Identifiable, Sendable, Hashable {
    var id: String { url.absoluteString }

    let url: URL
    let sizeInBytes: Int64
    let source: Source

    enum Source: String, Sendable {
        case local = "Local"
        case imported = "Imported"
        case gallery = "From Gallery"
    }

    var filename: String { url.lastPathComponent }

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: sizeInBytes, countStyle: .file)
    }
}

enum ModelDiscovery {
    private static let bookmarksKey = "edge_lab_model_bookmarks"

    static func discoverModels() -> [DiscoveredModel] {
        var models: [DiscoveredModel] = []
        var seen = Set<String>()

        if let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            for model in scanDirectory(docs, source: .local) where seen.insert(model.filename).inserted {
                models.append(model)
            }
        }

        for model in loadBookmarkedModels() where seen.insert(model.filename).inserted {
            models.append(model)
        }

        return models.sorted { $0.filename < $1.filename }
    }

    static func bookmarkImportedModel(_ url: URL) {
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }

        guard let data = try? url.bookmarkData(
            options: .minimalBookmark,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) else { return }

        var bookmarks = loadBookmarkDataArray()
        let filename = url.lastPathComponent
        bookmarks.removeAll { entry in
            guard let (savedURL, _) = resolveBookmark(entry) else { return true }
            return savedURL.lastPathComponent == filename
        }
        bookmarks.append(data)
        UserDefaults.standard.set(bookmarks, forKey: bookmarksKey)
    }

    private static func scanDirectory(_ directory: URL, source: DiscoveredModel.Source) -> [DiscoveredModel] {
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        return contents.compactMap { url -> DiscoveredModel? in
            guard url.pathExtension.lowercased() == "litertlm" else { return nil }
            let values = try? url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
            guard values?.isRegularFile == true else { return nil }
            return DiscoveredModel(
                url: url,
                sizeInBytes: Int64(values?.fileSize ?? 0),
                source: source
            )
        }
    }

    private static func loadBookmarkedModels() -> [DiscoveredModel] {
        loadBookmarkDataArray().compactMap { data -> DiscoveredModel? in
            guard let (url, isStale) = resolveBookmark(data), !isStale else { return nil }
            guard url.startAccessingSecurityScopedResource() else { return nil }
            defer { url.stopAccessingSecurityScopedResource() }
            let values = try? url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
            guard values?.isRegularFile == true else { return nil }
            let source: DiscoveredModel.Source = url.path.contains("Edge Gallery") ? .gallery : .imported
            return DiscoveredModel(
                url: url,
                sizeInBytes: Int64(values?.fileSize ?? 0),
                source: source
            )
        }
    }

    private static func loadBookmarkDataArray() -> [Data] {
        UserDefaults.standard.array(forKey: bookmarksKey) as? [Data] ?? []
    }

    private static func resolveBookmark(_ data: Data) -> (URL, Bool)? {
        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: data,
            options: [],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else { return nil }
        return (url, isStale)
    }
}