import UIKit
import Combine

@MainActor
final class StoryViewModel {
    @Published private(set) var currentStory: StoryUIModel?
    @Published private(set) var currentImage: UIImage?
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private var orderedStories: [Story] = []
    private var currentIndex = 0

    private let fetchStories: FetchStoriesUseCase
    private let loadImage: LoadStoryImageUseCase
    private let prefetchImage: PrefetchStoryImageUseCase
    private let orderService: StoryOrderService

    init(
        fetchStories: FetchStoriesUseCase,
        loadImage: LoadStoryImageUseCase,
        prefetchImage: PrefetchStoryImageUseCase,
        orderService: StoryOrderService
    ) {
        self.fetchStories = fetchStories
        self.loadImage = loadImage
        self.prefetchImage = prefetchImage
        self.orderService = orderService
    }

    var latestKnownID: Int? { orderedStories.map(\.id).max() }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let stories = try await fetchStories.execute(
                FetchStoriesRequest(query: FetchStoriesQuery(cursor: nil), policy: .cached)
            )
            orderedStories = orderService.ordered(stories: stories)
            currentIndex = 0
            await showCurrent()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func refresh() async {
        do {
            let stories = try await fetchStories.execute(
                FetchStoriesRequest(query: FetchStoriesQuery(cursor: latestKnownID), policy: .cached)
            )
            orderedStories = orderService.ordered(stories: stories)
            await showCurrent()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func advanceToNext() async {
        guard !orderedStories.isEmpty else { return }
        if let current = orderedStories[safe: currentIndex] {
            orderService.markAsSeen(id: current.id)
        }
        currentIndex = (currentIndex + 1) % orderedStories.count
        await showCurrent()
    }

    func advanceToPrevious() async {
        guard !orderedStories.isEmpty else { return }
        currentIndex = (currentIndex - 1 + orderedStories.count) % orderedStories.count
        await showCurrent()
    }

    private func showCurrent() async {
        guard let story = orderedStories[safe: currentIndex] else { return }
        currentStory = map(story)
        currentImage = nil

        do {
            currentImage = try await loadImage.execute(url: story.photoURL)
        } catch {
            // currentImage stays nil — ViewController shows placeholder
        }

        prefetchNext()
    }

    private func prefetchNext() {
        let nextIndex = (currentIndex + 1) % orderedStories.count
        if let next = orderedStories[safe: nextIndex] {
            prefetchImage.execute(url: next.photoURL)
        }
    }

    private func map(_ story: Story) -> StoryUIModel {
        StoryUIModel(
            id: story.id,
            photoURL: story.photoURL,
            avatarURL: story.profilePicURL,
            authorName: story.authorName,
            timeAgo: relativeTime(from: story.createdAt)
        )
    }

    private func relativeTime(from date: Date) -> String {
        let secs = Int(Date().timeIntervalSince(date))
        switch secs {
        case ..<60:    return "just now"
        case ..<3600:  return "\(secs / 60) min ago"
        case ..<86400: return "\(secs / 3600) hr ago"
        default:       return "\(secs / 86400) d ago"
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
