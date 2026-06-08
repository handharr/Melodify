import Foundation

struct Story: Sendable, Identifiable {
    let id: Int
    let photoURL: URL
    let profilePicURL: URL
    let authorName: String
    let createdAt: Date
    let expireAt: Date
}
