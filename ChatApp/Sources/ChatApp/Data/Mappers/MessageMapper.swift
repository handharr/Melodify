import Foundation

enum MessageMapper {
    static func toDomain(_ dto: MessageDTO) -> Message? {
        guard
            let content = makeContent(from: dto),
            let status = MessageStatus(rawValue: dto.status),
            let date = ISO8601DateFormatter().date(from: dto.createdAt)
        else { return nil }

        return Message(
            id: dto.id,
            conversationId: dto.conversationId,
            senderId: dto.senderId,
            content: content,
            status: status,
            createdAt: date
        )
    }

    // Optionals in the DTO correspond to message type — the Mapper enforces
    // that only valid combinations produce a domain model, and nil otherwise.
    private static func makeContent(from dto: MessageDTO) -> MessageContent? {
        switch dto.type {
        case "text":
            guard let text = dto.text else { return nil }
            return .text(text)
        case "image":
            guard let urlString = dto.imageURL,
                  let url = URL(string: urlString),
                  let ratio = dto.aspectRatio else { return nil }
            return .image(url, aspectRatio: ratio)
        case "audio":
            guard let duration = dto.audioDuration,
                  let urlString = dto.audioURL,
                  let url = URL(string: urlString) else { return nil }
            return .audio(duration: duration, url: url)
        case "deleted":
            return .deleted
        default:
            return nil
        }
    }
}
