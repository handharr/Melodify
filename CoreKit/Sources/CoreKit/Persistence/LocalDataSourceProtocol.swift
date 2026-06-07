public protocol LocalDataSourceProtocol {
    associatedtype Request
    associatedtype DTO: Codable

    func load(request: Request) -> DTO?
    func save(_ dto: DTO, for request: Request)
}
