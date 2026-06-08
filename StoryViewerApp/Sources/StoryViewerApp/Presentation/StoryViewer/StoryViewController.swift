import UIKit
import Combine

// Three recycled UIImageViews give O(1) layout per swipe and seamless infinite loop.
// UICollectionView / UIPageViewController can't wrap last → first without hacks.
@MainActor
final class StoryViewController: UIViewController {

    // MARK: - Three recycled image views (left / center / right)
    // On each swipe the references rotate so no new views are ever allocated.
    private var leftView:   UIImageView
    private var centerView: UIImageView
    private var rightView:  UIImageView

    private let authorLabel   = UILabel()
    private let timeLabel     = UILabel()
    private let avatarView    = UIImageView()
    private let progressBar   = UIView()
    private let progressTrack = UIView()

    private var autoAdvanceTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    private let viewModel: StoryViewModel

    init(viewModel: StoryViewModel) {
        self.viewModel = viewModel
        let makeImageView: () -> UIImageView = {
            let iv = UIImageView()
            iv.contentMode = .scaleAspectFill
            iv.clipsToBounds = true
            iv.backgroundColor = .black
            return iv
        }
        leftView   = makeImageView()
        centerView = makeImageView()
        rightView  = makeImageView()
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupImageViews()
        setupOverlay()
        setupGestures()
        bindViewModel()
        observeForeground()

        Task { await viewModel.load() }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        layoutImageViews()
        layoutOverlay()
    }

    // MARK: - Setup

    private func setupImageViews() {
        [leftView, centerView, rightView].forEach { view.addSubview($0) }
    }

    private func setupOverlay() {
        progressTrack.backgroundColor = UIColor.white.withAlphaComponent(0.3)
        progressTrack.layer.cornerRadius = 2

        progressBar.backgroundColor = .white
        progressBar.layer.cornerRadius = 2

        avatarView.layer.cornerRadius = 16
        avatarView.clipsToBounds = true
        avatarView.backgroundColor = UIColor.white.withAlphaComponent(0.2)

        authorLabel.textColor = .white
        authorLabel.font = .boldSystemFont(ofSize: 13)
        authorLabel.numberOfLines = 1

        timeLabel.textColor = UIColor.white.withAlphaComponent(0.75)
        timeLabel.font = .systemFont(ofSize: 11)
        timeLabel.numberOfLines = 1

        [progressTrack, progressBar, avatarView, authorLabel, timeLabel].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }

        NSLayoutConstraint.activate([
            progressTrack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            progressTrack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            progressTrack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),
            progressTrack.heightAnchor.constraint(equalToConstant: 3),

            progressBar.topAnchor.constraint(equalTo: progressTrack.topAnchor),
            progressBar.leadingAnchor.constraint(equalTo: progressTrack.leadingAnchor),
            progressBar.heightAnchor.constraint(equalToConstant: 3),
            progressBar.widthAnchor.constraint(equalToConstant: 0),

            avatarView.topAnchor.constraint(equalTo: progressTrack.bottomAnchor, constant: 10),
            avatarView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            avatarView.widthAnchor.constraint(equalToConstant: 32),
            avatarView.heightAnchor.constraint(equalToConstant: 32),

            authorLabel.centerYAnchor.constraint(equalTo: avatarView.centerYAnchor, constant: -7),
            authorLabel.leadingAnchor.constraint(equalTo: avatarView.trailingAnchor, constant: 8),
            authorLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -12),

            timeLabel.topAnchor.constraint(equalTo: authorLabel.bottomAnchor, constant: 2),
            timeLabel.leadingAnchor.constraint(equalTo: authorLabel.leadingAnchor),
        ])
    }

    private func setupGestures() {
        let swipeLeft  = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe(_:)))
        swipeLeft.direction  = .left
        let swipeRight = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipe(_:)))
        swipeRight.direction = .right
        view.addGestureRecognizer(swipeLeft)
        view.addGestureRecognizer(swipeRight)
    }

    private func observeForeground() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in await self?.viewModel.refresh() }
        }
    }

    // MARK: - Layout

    private func layoutImageViews() {
        let w = view.bounds.width
        let h = view.bounds.height
        leftView.frame   = CGRect(x: -w, y: 0, width: w, height: h)
        centerView.frame = CGRect(x:  0, y: 0, width: w, height: h)
        rightView.frame  = CGRect(x:  w, y: 0, width: w, height: h)
    }

    private func layoutOverlay() {
        view.bringSubviewToFront(progressTrack)
        view.bringSubviewToFront(progressBar)
        view.bringSubviewToFront(avatarView)
        view.bringSubviewToFront(authorLabel)
        view.bringSubviewToFront(timeLabel)
    }

    // MARK: - Binding

    private func bindViewModel() {
        viewModel.$currentStory
            .receive(on: RunLoop.main)
            .compactMap { $0 }
            .sink { [weak self] story in
                self?.authorLabel.text = story.authorName
                self?.timeLabel.text   = story.timeAgo
            }
            .store(in: &cancellables)

        // Timer starts only after image is ready — not on swipe.
        // This guarantees a full 10 seconds of visible content.
        viewModel.$currentImage
            .receive(on: RunLoop.main)
            .sink { [weak self] image in
                self?.centerView.image = image
                if image != nil { self?.startAutoAdvanceTimer() }
            }
            .store(in: &cancellables)
    }

    // MARK: - Gestures

    @objc private func handleSwipe(_ gesture: UISwipeGestureRecognizer) {
        stopAutoAdvanceTimer()
        if gesture.direction == .left {
            advanceForward()
        } else {
            advanceBackward()
        }
    }

    // MARK: - Three-UIImageView recycling

    // Swipe → (next story): leftView is recycled to become the new right slot.
    // No new views allocated — O(1) layout work per swipe.
    private func advanceForward() {
        let recycled = leftView
        leftView   = centerView
        centerView = rightView
        rightView  = recycled
        rightView.image = nil
        relayoutImageViews()
        Task { await viewModel.advanceToNext() }
    }

    // Swipe ← (previous story): rightView is recycled to become the new left slot.
    private func advanceBackward() {
        let recycled = rightView
        rightView  = centerView
        centerView = leftView
        leftView   = recycled
        leftView.image = nil
        relayoutImageViews()
        Task { await viewModel.advanceToPrevious() }
    }

    private func relayoutImageViews() {
        let w = view.bounds.width
        let h = view.bounds.height
        UIView.animate(withDuration: 0.25) {
            self.leftView.frame   = CGRect(x: -w, y: 0, width: w, height: h)
            self.centerView.frame = CGRect(x:  0, y: 0, width: w, height: h)
            self.rightView.frame  = CGRect(x:  w, y: 0, width: w, height: h)
        }
    }

    // MARK: - Auto-advance timer

    private func startAutoAdvanceTimer() {
        stopAutoAdvanceTimer()
        resetProgressBar()
        animateProgressBar()
        autoAdvanceTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in self?.advanceForward() }
        }
    }

    private func stopAutoAdvanceTimer() {
        autoAdvanceTimer?.invalidate()
        autoAdvanceTimer = nil
        progressBar.layer.removeAllAnimations()
    }

    private func resetProgressBar() {
        progressBar.constraints.first { $0.firstAttribute == .width }?.constant = 0
        view.layoutIfNeeded()
    }

    private func animateProgressBar() {
        let trackWidth = progressTrack.bounds.width
        UIView.animate(withDuration: 10, delay: 0, options: .curveLinear) {
            self.progressBar.constraints.first { $0.firstAttribute == .width }?.constant = trackWidth
            self.view.layoutIfNeeded()
        }
    }
}
