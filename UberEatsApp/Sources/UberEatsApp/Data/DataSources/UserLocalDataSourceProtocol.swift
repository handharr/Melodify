import Foundation

protocol UserLocalDataSourceProtocol: Sendable {
    func fetchUser() -> UserDTO?
    func saveUser(_ dto: UserDTO)
}
