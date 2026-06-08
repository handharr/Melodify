import Foundation

// Transport-only peer to APIClient. Wraps URLSession persistent GET with text/event-stream.
// Parses SSE lines into raw data payloads; callers decode the payload.
final class SSEClient: Sendable {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func stream<T: Decodable & Sendable>(url: URL, as type: T.Type) -> AsyncStream<T> {
        AsyncStream { continuation in
            let task = Task {
                var request = URLRequest(url: url)
                request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
                request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")

                do {
                    let (bytes, _) = try await session.bytes(for: request)
                    for try await line in bytes.lines {
                        guard !Task.isCancelled else { break }
                        guard line.hasPrefix("data: ") else { continue }
                        let payload = String(line.dropFirst(6))
                        guard let data = payload.data(using: .utf8),
                              let decoded = try? JSONDecoder().decode(T.self, from: data) else { continue }
                        continuation.yield(decoded)
                    }
                } catch {
                    // Stream ended or connection dropped — finish cleanly.
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
