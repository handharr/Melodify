import UIKit

extension UIImageView {
    // Facade over URLSession image loading — call site never references URLSession directly.
    // Swapping the loader touches only this file.
    func setImage(url: URL) {
        Task { [weak self] in
            guard let (data, _) = try? await URLSession.shared.data(from: url),
                  let image = UIImage(data: data) else { return }
            await MainActor.run { self?.image = image }
        }
    }
}
