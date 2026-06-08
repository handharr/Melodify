import Foundation

// In-memory cache backed by bundled mock JSON.
// The observer pattern (observe → yield on every save/delete) mirrors what
// NSFetchedResultsController.controllerDidChangeContent does in the Core Data path.
// Swapping this actor for a Core Data-backed implementation is a one-file change.
actor MessageLocalDataSource: MessageLocalDataSourceProtocol {
    private var cache: [String: [MessageDTO]] = [:]
    private var observers: [String: [UUID: AsyncStream<[MessageDTO]>.Continuation]] = [:]
    private let decoder = JSONDecoder()

    // MARK: - MessageLocalDataSourceProtocol

    nonisolated func observe(conversationId: String) -> AsyncStream<[MessageDTO]> {
        let observerId = UUID()
        return AsyncStream { [weak self] continuation in
            guard let self else { return }
            Task {
                let initial = await self._register(
                    observerId: observerId,
                    conversationId: conversationId,
                    continuation: continuation
                )
                continuation.yield(initial)
            }
            continuation.onTermination = { [weak self] _ in
                Task { [weak self] in
                    await self?._unregister(observerId: observerId, conversationId: conversationId)
                }
            }
        }
    }

    nonisolated func save(_ dto: MessageDTO) async {
        await _save(dto)
    }

    nonisolated func delete(id: String) async {
        await _delete(id: id)
    }

    nonisolated func updateStatus(id: String, status: String) async {
        await _updateStatus(id: id, status: status)
    }

    // MARK: - Actor-isolated internals

    private func _register(
        observerId: UUID,
        conversationId: String,
        continuation: AsyncStream<[MessageDTO]>.Continuation
    ) -> [MessageDTO] {
        if observers[conversationId] == nil { observers[conversationId] = [:] }
        observers[conversationId]?[observerId] = continuation
        return _messages(conversationId: conversationId)
    }

    private func _unregister(observerId: UUID, conversationId: String) {
        observers[conversationId]?[observerId] = nil
    }

    private func _messages(conversationId: String) -> [MessageDTO] {
        if let cached = cache[conversationId] { return cached }
        let loaded = loadFromBundle(conversationId: conversationId)
        cache[conversationId] = loaded
        return loaded
    }

    private func _save(_ dto: MessageDTO) {
        var msgs = cache[dto.conversationId] ?? loadFromBundle(conversationId: dto.conversationId)
        if let idx = msgs.firstIndex(where: { $0.id == dto.id }) {
            msgs[idx] = dto
        } else {
            msgs.append(dto)
        }
        cache[dto.conversationId] = msgs
        _notifyObservers(conversationId: dto.conversationId, messages: msgs)
    }

    private func _delete(id: String) {
        for (convId, msgs) in cache {
            guard let idx = msgs.firstIndex(where: { $0.id == id }) else { continue }
            var updated = msgs
            updated.remove(at: idx)
            cache[convId] = updated
            _notifyObservers(conversationId: convId, messages: updated)
            return
        }
    }

    private func _updateStatus(id: String, status: String) {
        for (convId, msgs) in cache {
            guard let idx = msgs.firstIndex(where: { $0.id == id }) else { continue }
            let old = msgs[idx]
            let updated = MessageDTO(
                id: old.id,
                conversationId: old.conversationId,
                senderId: old.senderId,
                sequence: old.sequence,
                type: old.type,
                text: old.text,
                imageURL: old.imageURL,
                aspectRatio: old.aspectRatio,
                audioDuration: old.audioDuration,
                audioURL: old.audioURL,
                createdAt: old.createdAt,
                status: status
            )
            var updatedMsgs = msgs
            updatedMsgs[idx] = updated
            cache[convId] = updatedMsgs
            _notifyObservers(conversationId: convId, messages: updatedMsgs)
            return
        }
    }

    private func _notifyObservers(conversationId: String, messages: [MessageDTO]) {
        observers[conversationId]?.values.forEach { $0.yield(messages) }
    }

    private func loadFromBundle(conversationId: String) -> [MessageDTO] {
        let resource = "messages-\(conversationId)"
        guard let url = Bundle.module.url(forResource: resource, withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return [] }
        return (try? decoder.decode([MessageDTO].self, from: data)) ?? []
    }
}
