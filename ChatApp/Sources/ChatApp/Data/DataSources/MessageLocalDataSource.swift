import Foundation

// In-memory cache backed by bundled mock JSON. Mutable cache allows
// optimistic updates and WebSocket-received messages to persist for the session.
actor MessageLocalDataSource: MessageLocalDataSourceProtocol {
    private var cache: [String: [MessageDTO]] = [:]
    private let decoder = JSONDecoder()

    nonisolated func messages(conversationId: String) async -> [MessageDTO] {
        await _messages(conversationId: conversationId)
    }

    nonisolated func save(_ dto: MessageDTO) async {
        await _save(dto)
    }

    nonisolated func updateStatus(id: String, status: String) async {
        await _updateStatus(id: id, status: status)
    }

    private func _messages(conversationId: String) -> [MessageDTO] {
        if let cached = cache[conversationId] { return cached }
        let loaded = loadFromBundle(conversationId: conversationId)
        cache[conversationId] = loaded
        return loaded
    }

    private func _save(_ dto: MessageDTO) {
        var msgs = cache[dto.conversationId] ?? []
        if let idx = msgs.firstIndex(where: { $0.id == dto.id }) {
            msgs[idx] = dto
        } else {
            msgs.append(dto)
        }
        cache[dto.conversationId] = msgs
    }

    private func _updateStatus(id: String, status: String) {
        for (convId, msgs) in cache {
            if let idx = msgs.firstIndex(where: { $0.id == id }) {
                let old = msgs[idx]
                let updated = MessageDTO(
                    id: old.id, conversationId: old.conversationId, senderId: old.senderId,
                    type: old.type, text: old.text, imageURL: old.imageURL,
                    aspectRatio: old.aspectRatio, audioDuration: old.audioDuration,
                    audioURL: old.audioURL, createdAt: old.createdAt, status: status
                )
                var updated_msgs = msgs
                updated_msgs[idx] = updated
                cache[convId] = updated_msgs
                return
            }
        }
    }

    private func loadFromBundle(conversationId: String) -> [MessageDTO] {
        let resource = "messages-\(conversationId)"
        guard let url = Bundle.module.url(forResource: resource, withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return [] }
        return (try? decoder.decode([MessageDTO].self, from: data)) ?? []
    }
}
