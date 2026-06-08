import Foundation

protocol StoryLocalDataSourceProtocol: Sendable {
    func read() async -> [StoryDTO]
    func write(_ dtos: [StoryDTO]) async
    func lastFetchedAt() async -> Date?
    func setLastFetchedAt(_ date: Date) async
}

// Actor-based in-memory store. A real implementation would write to disk via
// CoreData or Codable JSON + FileManager; the protocol contract stays identical.
actor StoryLocalDataSource: StoryLocalDataSourceProtocol {
    private var stored: [StoryDTO] = []
    private var lastFetched: Date?

    func read() async -> [StoryDTO] { stored }

    func write(_ dtos: [StoryDTO]) async {
        var byID = Dictionary(uniqueKeysWithValues: stored.map { ($0.photoID, $0) })
        dtos.forEach { byID[$0.photoID] = $0 }
        stored = byID.values.sorted { $0.photoID > $1.photoID }
    }

    func lastFetchedAt() async -> Date? { lastFetched }

    func setLastFetchedAt(_ date: Date) async { lastFetched = date }

    func seedFromBundle() async {
        guard
            let url = Bundle.module.url(forResource: "stories", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            var dtos = try? JSONDecoder().decode([StoryDTO].self, from: data)
        else { return }

        // Adjust timestamps relative to now so demo stories never expire.
        let now = Int(Date().timeIntervalSince1970)
        dtos = dtos.enumerated().map { i, dto in
            let createdAt = now - (i * 3600 + 1800)
            return StoryDTO(
                photoID: dto.photoID,
                photoURL: dto.photoURL,
                profilePicURL: dto.profilePicURL,
                authorName: dto.authorName,
                createdAt: createdAt,
                expireAt: createdAt + 86400
            )
        }
        stored = dtos
        lastFetched = Date()
    }
}
