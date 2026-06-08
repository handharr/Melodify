// Data/DataSources/ImageDiskDataSource.swift

import Foundation

final class ImageDiskDataSource: ImageDiskDataSourceProtocol, @unchecked Sendable {
    private let fileManager: FileManager
    private let cacheDirectory: URL

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        let caches = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        self.cacheDirectory = caches.appendingPathComponent("HotelBookingImages", isDirectory: true)
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }

    func filePath(for url: URL) -> String {
        let hash = abs(url.absoluteString.hashValue)
        let filename = "\(url.lastPathComponent)_\(hash)"
        return cacheDirectory.appendingPathComponent(filename).path
    }

    func loadImage(for url: URL) -> Data? {
        let path = filePath(for: url)
        return fileManager.contents(atPath: path)
    }

    func saveImage(_ data: Data, for url: URL) {
        let path = filePath(for: url)
        fileManager.createFile(atPath: path, contents: data)
    }

    func evictExpired(ttl: TimeInterval) {
        guard let contents = try? fileManager.contentsOfDirectory(
            at: cacheDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: .skipsHiddenFiles
        ) else { return }

        let now = Date()
        for fileURL in contents {
            guard let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path),
                  let modDate = attributes[.modificationDate] as? Date else { continue }
            if now.timeIntervalSince(modDate) > ttl {
                try? fileManager.removeItem(at: fileURL)
            }
        }
    }
}
