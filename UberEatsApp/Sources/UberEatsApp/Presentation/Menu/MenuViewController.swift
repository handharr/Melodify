import UIKit
import Combine
import MelodifyDesignSystem

final class MenuViewController: UIViewController {
    private let viewModel: MenuViewModel
    private var cancellables = Set<AnyCancellable>()

    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        let width = (UIScreen.main.bounds.width - 48) / 2
        layout.itemSize = CGSize(width: width, height: width * 1.4)
        layout.minimumInteritemSpacing = 16
        layout.minimumLineSpacing = 16
        layout.sectionInset = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.register(DishCell.self, forCellWithReuseIdentifier: DishCell.reuseID)
        cv.backgroundColor = MDSColor.surface
        cv.translatesAutoresizingMaskIntoConstraints = false
        return cv
    }()

    private let loadingView: MDSLoadingView = {
        let v = MDSLoadingView()
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    init(viewModel: MenuViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = MDSColor.surface
        setupLayout()
        collectionView.dataSource = self
        bindViewModel()
        viewModel.load()
    }

    private func setupLayout() {
        view.addSubview(collectionView)
        view.addSubview(loadingView)

        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            loadingView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            loadingView.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    private func bindViewModel() {
        viewModel.$dishes
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.collectionView.reloadData() }
            .store(in: &cancellables)

        viewModel.$isLoading
            .receive(on: DispatchQueue.main)
            .sink { [weak self] loading in
                self?.loadingView.isHidden = !loading
                if loading { self?.loadingView.configure(with: MDSLoadingConfiguration()) }
            }
            .store(in: &cancellables)
    }
}

extension MenuViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        viewModel.dishes.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: DishCell.reuseID, for: indexPath) as! DishCell
        let model = viewModel.dishes[indexPath.item]
        cell.configure(with: model)
        cell.onAdd = { [weak self] in self?.viewModel.addDish(model) }
        return cell
    }
}
