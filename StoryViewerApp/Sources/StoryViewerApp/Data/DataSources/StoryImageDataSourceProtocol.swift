import UIKit

protocol StoryImageDataSourceProtocol: AnyObject, Sendable {
    func loadImage(url: URL) async throws -> UIImage
    func prefetch(url: URL)
}
