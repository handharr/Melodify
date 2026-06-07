import Foundation

// Hashable for NSDiffableDataSourceSnapshot.
// ContentKind mirrors MessageContent — exhaustive switch in the cell factory
// is the compile-time guarantee that every content type has a cell.
struct ChatUIModel: Hashable {
    let id: String
    let senderName: String
    let isOutgoing: Bool
    let timestamp: String
    let status: String
    let content: ContentKind

    enum ContentKind: Hashable {
        case text(String)
        case image(url: URL, aspectRatio: CGFloat)
        case audio(duration: String, url: URL)
        case deleted
    }
}

enum ChatUIModelMapper {
    static func map(_ message: Message, currentUserId: String, senderName: String) -> ChatUIModel {
        ChatUIModel(
            id: message.id,
            senderName: senderName,
            isOutgoing: message.senderId == currentUserId,
            timestamp: formatTime(message.createdAt),
            status: statusLabel(message.status),
            content: mapContent(message.content)
        )
    }

    static func pendingText(_ text: String, clientId: String) -> ChatUIModel {
        ChatUIModel(
            id: clientId,
            senderName: "You",
            isOutgoing: true,
            timestamp: "Sending…",
            status: "pending",
            content: .text(text)
        )
    }

    private static func mapContent(_ content: MessageContent) -> ChatUIModel.ContentKind {
        switch content {
        case .text(let t):
            return .text(t)
        case .image(let url, let ratio):
            return .image(url: url, aspectRatio: ratio)
        case .audio(let duration, let url):
            return .audio(duration: formatDuration(duration), url: url)
        case .deleted:
            return .deleted
        }
    }

    private static func formatTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.timeStyle = .short
        f.dateStyle = .none
        return f.string(from: date)
    }

    private static func formatDuration(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    private static func statusLabel(_ status: MessageStatus) -> String {
        switch status {
        case .pending:   return "Pending"
        case .sent:      return "Sent"
        case .delivered: return "Delivered"
        case .read:      return "Read"
        }
    }
}
