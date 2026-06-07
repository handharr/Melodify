import Foundation

public enum APIError: Error, Sendable {
    case invalidURL
    case notFound
    case decodingFailed(Error)
    case networkError(Error)
    case conflict
}

public protocol APIClientProtocol: Sendable {
    func get<T: Decodable>(_ url: URL) async throws -> T
    func post<Body: Encodable & Sendable, T: Decodable>(_ url: URL, body: Body) async throws -> T
    func put<Body: Encodable & Sendable, T: Decodable>(_ url: URL, body: Body) async throws -> T
    func patch<Body: Encodable & Sendable, T: Decodable>(_ url: URL, body: Body) async throws -> T
    func delete<T: Decodable>(_ url: URL) async throws -> T
}

public struct APIClient: APIClientProtocol {
    private let session: URLSession
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func get<T: Decodable>(_ url: URL) async throws -> T {
        try await perform(URLRequest(url: url))
    }

    public func post<Body: Encodable & Sendable, T: Decodable>(_ url: URL, body: Body) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = try encoder.encode(body)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return try await perform(request)
    }

    public func put<Body: Encodable & Sendable, T: Decodable>(_ url: URL, body: Body) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.httpBody = try encoder.encode(body)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return try await perform(request)
    }

    public func patch<Body: Encodable & Sendable, T: Decodable>(_ url: URL, body: Body) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.httpBody = try encoder.encode(body)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return try await perform(request)
    }

    public func delete<T: Decodable>(_ url: URL) async throws -> T {
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        return try await perform(request)
    }

    private func perform<T: Decodable>(_ request: URLRequest) async throws -> T {
        do {
            let (data, response) = try await session.data(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode == 409 {
                throw APIError.conflict
            }
            return try decoder.decode(T.self, from: data)
        } catch let error as APIError {
            throw error
        } catch let error as DecodingError {
            throw APIError.decodingFailed(error)
        } catch {
            throw APIError.networkError(error)
        }
    }
}
