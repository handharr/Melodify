import Foundation
import CoreKit
// import SDWebImage  ← add via SPM, then uncomment

// Production concrete. Conforms to both protocols — SDWebImage handles
// memory + disk caching and batch prefetching transparently.
//
// public final class ImageLoader: ImageLoaderProtocol, ImagePrefetcherProtocol {
//
//     public init() {}
//
//     public func load(url: URL) async throws -> Data {
//         try await withCheckedThrowingContinuation { continuation in
//             SDWebImageManager.shared.loadImage(with: url, options: [], progress: nil) { _, data, error, _, _, _ in
//                 if let data { continuation.resume(returning: data) }
//                 else { continuation.resume(throwing: error ?? URLError(.badServerResponse)) }
//             }
//         }
//     }
//
//     public func prefetch(urls: [URL]) {
//         SDWebImagePrefetcher.shared.prefetchURLs(urls)
//     }
//
//     public func cancelPrefetching(urls: [URL]) {
//         SDWebImagePrefetcher.shared.cancelPrefetching()
//     }
// }
