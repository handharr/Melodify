import Foundation

// Stateful Domain Service — holds seenStoryIDs across swipes and foreground/background cycles.
// Not a UseCase: stateful + consulted on every advance, not triggered by a single user action.
@MainActor
final class StoryOrderService {
    private var seenIDs: Set<Int> = []

    func ordered(stories: [Story]) -> [Story] {
        stories.sorted { a, b in
            let aUnseen = !seenIDs.contains(a.id)
            let bUnseen = !seenIDs.contains(b.id)
            if aUnseen != bUnseen { return aUnseen }
            return a.createdAt > b.createdAt
        }
    }

    func markAsSeen(id: Int) {
        seenIDs.insert(id)
    }

    func next(after currentID: Int, in stories: [Story]) -> Story? {
        guard let idx = stories.firstIndex(where: { $0.id == currentID }) else {
            return stories.first { !seenIDs.contains($0.id) } ?? stories.first
        }
        let nextIdx = (idx + 1) % stories.count
        return stories[nextIdx]
    }

    func previous(before currentID: Int, in stories: [Story]) -> Story? {
        guard let idx = stories.firstIndex(where: { $0.id == currentID }) else {
            return stories.first
        }
        let prevIdx = (idx - 1 + stories.count) % stories.count
        return stories[prevIdx]
    }
}
