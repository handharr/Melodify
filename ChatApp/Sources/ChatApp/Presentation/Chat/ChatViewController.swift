import UIKit
import Combine

public final class ChatViewController: UIViewController {
    private let viewModel: ChatViewModel
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Cell registrations

    // Exhaustive switch in the dataSource cell provider guarantees every
    // MessageContent case maps to a cell. Adding a new case without a cell → compiler error.
    private lazy var textRegistration = UICollectionView.CellRegistration<TextMessageCell, ChatUIModel> {
        cell, _, model in cell.configure(with: model)
    }

    private lazy var imageRegistration = UICollectionView.CellRegistration<ImageMessageCell, ChatUIModel> {
        cell, _, model in cell.configure(with: model)
    }

    private lazy var audioRegistration = UICollectionView.CellRegistration<AudioMessageCell, ChatUIModel> {
        cell, _, model in cell.configure(with: model)
    }

    private lazy var deletedRegistration = UICollectionView.CellRegistration<DeletedMessageCell, ChatUIModel> {
        cell, _, _ in _ = cell
    }

    // MARK: - Views

    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewCompositionalLayout { _, _ in
            let item = NSCollectionLayoutItem(
                layoutSize: .init(widthDimension: .fractionalWidth(1), heightDimension: .estimated(60))
            )
            let group = NSCollectionLayoutGroup.vertical(
                layoutSize: .init(widthDimension: .fractionalWidth(1), heightDimension: .estimated(60)),
                subitems: [item]
            )
            return NSCollectionLayoutSection(group: group)
        }
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.translatesAutoresizingMaskIntoConstraints = false
        cv.backgroundColor = .systemBackground
        cv.keyboardDismissMode = .interactive
        return cv
    }()

    private lazy var dataSource = UICollectionViewDiffableDataSource<Int, ChatUIModel>(
        collectionView: collectionView
    ) { [weak self] cv, indexPath, model in
        guard let self else { return UICollectionViewCell() }
        switch model.content {
        case .text:
            return cv.dequeueConfiguredReusableCell(using: self.textRegistration, for: indexPath, item: model)
        case .image:
            return cv.dequeueConfiguredReusableCell(using: self.imageRegistration, for: indexPath, item: model)
        case .audio:
            return cv.dequeueConfiguredReusableCell(using: self.audioRegistration, for: indexPath, item: model)
        case .deleted:
            return cv.dequeueConfiguredReusableCell(using: self.deletedRegistration, for: indexPath, item: model)
        }
    }

    private let inputBar: UIView = {
        let v = UIView()
        v.backgroundColor = .secondarySystemBackground
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    private let textField: UITextField = {
        let tf = UITextField()
        tf.placeholder = "Message"
        tf.borderStyle = .roundedRect
        tf.translatesAutoresizingMaskIntoConstraints = false
        return tf
    }()

    private let sendButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.title = "Send"
        config.cornerStyle = .capsule
        let btn = UIButton(configuration: config)
        btn.translatesAutoresizingMaskIntoConstraints = false
        return btn
    }()

    private var inputBarBottomConstraint: NSLayoutConstraint?

    // MARK: - Init

    init(viewModel: ChatViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Lifecycle

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground
        setupCollectionView()
        setupInputBar()
        setupKeyboardObservers()
        bindViewModel()
        sendButton.addTarget(self, action: #selector(didTapSend), for: .touchUpInside)
    }

    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        viewModel.viewDidAppear()
    }

    public override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        viewModel.viewDidDisappear()
    }

    // MARK: - Setup

    private func setupCollectionView() {
        view.addSubview(collectionView)
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: inputBar.topAnchor)
        ])
    }

    private func setupInputBar() {
        inputBar.addSubview(textField)
        inputBar.addSubview(sendButton)
        view.addSubview(inputBar)

        let bottom = inputBar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        inputBarBottomConstraint = bottom

        NSLayoutConstraint.activate([
            inputBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            inputBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottom,

            textField.topAnchor.constraint(equalTo: inputBar.topAnchor, constant: 8),
            textField.leadingAnchor.constraint(equalTo: inputBar.leadingAnchor, constant: 12),
            textField.trailingAnchor.constraint(equalTo: sendButton.leadingAnchor, constant: -8),
            textField.bottomAnchor.constraint(equalTo: inputBar.bottomAnchor, constant: -8),

            sendButton.centerYAnchor.constraint(equalTo: textField.centerYAnchor),
            sendButton.trailingAnchor.constraint(equalTo: inputBar.trailingAnchor, constant: -12)
        ])
    }

    private func setupKeyboardObservers() {
        NotificationCenter.default.addObserver(
            self, selector: #selector(keyboardWillShow(_:)),
            name: UIResponder.keyboardWillShowNotification, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(keyboardWillHide(_:)),
            name: UIResponder.keyboardWillHideNotification, object: nil
        )
    }

    private func bindViewModel() {
        viewModel.$messages
            .receive(on: RunLoop.main)
            .sink { [weak self] items in
                guard let self else { return }
                var snapshot = NSDiffableDataSourceSnapshot<Int, ChatUIModel>()
                snapshot.appendSections([0])
                snapshot.appendItems(items)
                dataSource.apply(snapshot, animatingDifferences: false)
                if !items.isEmpty {
                    let last = IndexPath(item: items.count - 1, section: 0)
                    collectionView.scrollToItem(at: last, at: .bottom, animated: true)
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Actions

    @objc private func didTapSend() {
        guard let text = textField.text, !text.isEmpty else { return }
        viewModel.send(text: text)
        textField.text = nil
    }

    @objc private func keyboardWillShow(_ notification: Notification) {
        guard let frame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
        inputBarBottomConstraint?.constant = -frame.height + view.safeAreaInsets.bottom
        UIView.animate(withDuration: 0.25) { self.view.layoutIfNeeded() }
    }

    @objc private func keyboardWillHide(_ notification: Notification) {
        inputBarBottomConstraint?.constant = 0
        UIView.animate(withDuration: 0.25) { self.view.layoutIfNeeded() }
    }
}
