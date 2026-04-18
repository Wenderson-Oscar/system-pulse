import Foundation

struct HeavyFile: Identifiable, Hashable {
    var id: URL { url }
    var url: URL
    var sizeBytes: UInt64
}

final class FileScanner {
    /// Scans the given directories asynchronously and returns the top-N largest files.
    func scan(directories: [URL], limit: Int = 20) async -> [HeavyFile] {
        await withTaskGroup(of: [HeavyFile].self) { group in
            for dir in directories {
                group.addTask { Self.scanDirectory(dir) }
            }
            var all: [HeavyFile] = []
            for await partial in group { all.append(contentsOf: partial) }
            return Array(all.sorted { $0.sizeBytes > $1.sizeBytes }.prefix(limit))
        }
    }

    static func defaultDirectories() -> [URL] {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return [
            home.appendingPathComponent("Downloads"),
            home.appendingPathComponent("Desktop"),
            home.appendingPathComponent("Documents"),
            home.appendingPathComponent("Movies")
        ]
    }

    private static func scanDirectory(_ url: URL) -> [HeavyFile] {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return [] }

        var results: [HeavyFile] = []
        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]) else { continue }
            guard values.isRegularFile == true, let size = values.fileSize, size > 0 else { continue }
            results.append(HeavyFile(url: fileURL, sizeBytes: UInt64(size)))
        }
        return results
    }
}
