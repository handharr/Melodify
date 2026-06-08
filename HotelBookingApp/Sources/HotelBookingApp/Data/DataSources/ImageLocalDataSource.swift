// Data/DataSources/ImageLocalDataSource.swift

import Foundation

final class ImageLocalDataSource: ImageLocalDataSourceProtocol, @unchecked Sendable {
    private var store: [String: ImageMetadata] = [:]
    private let lock = NSLock()

    func saveMetadata(_ metadata: ImageMetadata) {
        lock.lock()
        defer { lock.unlock() }
        store[metadata.url.absoluteString] = metadata
    }

    func fetchMetadata(for url: URL) -> ImageMetadata? {
        lock.lock()
        defer { lock.unlock() }
        return store[url.absoluteString]
    }

    func deleteMetadata(for url: URL) {
        lock.lock()
        defer { lock.unlock() }
        store.removeValue(forKey: url.absoluteString)
    }

    func fetchExpired(ttl: TimeInterval) -> [ImageMetadata] {
        lock.lock()
        defer { lock.unlock() }
        let now = Date()
        return store.values.filter { now.timeIntervalSince($0.savedAt) > ttl }
    }
}
