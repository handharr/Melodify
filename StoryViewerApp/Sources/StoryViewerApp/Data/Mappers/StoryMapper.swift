import Foundation

struct StoryMapper {
    static func toDomain(_ dto: StoryDTO) -> Story? {
        guard
            let photoURL = URL(string: dto.photoURL),
            let profilePicURL = URL(string: dto.profilePicURL)
        else { return nil }
        return Story(
            id: dto.photoID,
            photoURL: photoURL,
            profilePicURL: profilePicURL,
            authorName: dto.authorName,
            createdAt: Date(timeIntervalSince1970: TimeInterval(dto.createdAt)),
            expireAt: Date(timeIntervalSince1970: TimeInterval(dto.expireAt))
        )
    }
}
