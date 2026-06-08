import Foundation

// Actor isolation makes all queue mutations thread-safe without locks.
// Messages survive app restarts — persisted to Documents/pending_messages.json.
actor PendingMessageQueue {
    private var items: [PendingMessageDTO] = []
    private let storageURL: URL

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        storageURL = docs.appendingPathComponent("pending_messages.json")
        items = Self.load(from: storageURL)
    }

    func enqueue(_ dto: PendingMessageDTO) {
        guard !items.contains(where: { $0.id == dto.id }) else { return }
        items.append(dto)
        persist()
    }

    func dequeue(conversationId: String) -> [PendingMessageDTO] {
        let pending = items.filter { $0.conversationId == conversationId }
        items.removeAll { $0.conversationId == conversationId }
        persist()
        return pending
    }

    func remove(id: String) {
        items.removeAll { $0.id == id }
        persist()
    }

    func allPending() -> [PendingMessageDTO] { items }

    // O(pending conversations) — only conversations with queued messages are returned.
    // Flush iterates this list so conversations with zero pending are never touched.
    func pendingConversationIds() -> [String] {
        Array(Set(items.map { $0.conversationId }))
    }

    // MARK: - Persistence

    private func persist() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        try? data.write(to: storageURL, options: .atomic)
    }

    private static func load(from url: URL) -> [PendingMessageDTO] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([PendingMessageDTO].self, from: data)) ?? []
    }
}
