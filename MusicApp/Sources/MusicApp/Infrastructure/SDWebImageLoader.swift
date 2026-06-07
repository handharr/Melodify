import Foundation
import CoreKit
// import SDWebImage  ← add SDWebImage via SPM, then uncomment

// Production concrete. Conforms to both protocols — SDWebImage's internals
// handle memory + disk caching and batch prefetching transparently.
//
// final class SDWebImageLoader: ImageLoaderProtocol, ImagePrefetcherProtocol {
//
//     func load(url: URL) async throws -> Data {
//         try await withCheckedThrowingContinuation { continuation in
//             SDWebImageManager.shared.loadImage(with: url, options: [], progress: nil) { image, data, error, _, _, _ in
//                 if let data { continuation.resume(returning: data) }
//                 else { continuation.resume(throwing: error ?? URLError(.badServerResponse)) }
//             }
//         }
//     }
//
//     func prefetch(urls: [URL]) {
//         SDWebImagePrefetcher.shared.prefetchURLs(urls)
//     }
//
//     func cancelPrefetching(urls: [URL]) {
//         SDWebImagePrefetcher.shared.cancelPrefetching()
//     }
// }
