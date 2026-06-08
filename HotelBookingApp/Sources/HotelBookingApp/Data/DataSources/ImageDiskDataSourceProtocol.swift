// Data/DataSources/ImageDiskDataSourceProtocol.swift

import Foundation

protocol ImageDiskDataSourceProtocol: Sendable {
    func loadImage(for url: URL) -> Data?
    func saveImage(_ data: Data, for url: URL)
    func filePath(for url: URL) -> String
    func evictExpired(ttl: TimeInterval)
}
