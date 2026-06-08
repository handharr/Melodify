// Data/DataSources/ImageLocalDataSourceProtocol.swift

import Foundation

protocol ImageLocalDataSourceProtocol {
    func fetchMetadata(for url: URL) -> ImageMetadata?
    func saveMetadata(_ metadata: ImageMetadata)
    func deleteMetadata(for url: URL)
    func fetchExpired(ttl: TimeInterval) -> [ImageMetadata]
}
