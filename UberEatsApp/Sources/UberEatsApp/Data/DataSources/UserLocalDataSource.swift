import Foundation

final class UserLocalDataSource: UserLocalDataSourceProtocol, @unchecked Sendable {
    private let defaults: UserDefaults
    private let key = "ubereats.user"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func fetchUser() -> UserDTO? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(UserDTO.self, from: data)
    }

    func saveUser(_ dto: UserDTO) {
        defaults.set(try? JSONEncoder().encode(dto), forKey: key)
    }
}
