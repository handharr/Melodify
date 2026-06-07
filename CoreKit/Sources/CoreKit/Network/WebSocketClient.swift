import Foundation

public enum WebSocketError: Error, Sendable {
    case notConnected
    case encodingFailed
    case transportError(Error)
}

// Envelope that routes a raw JSON payload to a named channel.
public struct WebSocketEnvelope: Codable, Sendable {
    public let channel: String
    public let payload: String // JSON-encoded by the sender

    public init(channel: String, payload: String) {
        self.channel = channel
        self.payload = payload
    }
}

public protocol WebSocketClientProtocol: Sendable {
    func connect(to url: URL) async throws
    func disconnect() async
    func subscribe(channel: String) -> AsyncStream<String>
    func send(payload: String, channel: String) async throws
}

// One shared connection. Actor isolation guarantees task mutation is
// thread-safe without @unchecked Sendable. Subscribers call subscribe(channel:)
// to get an AsyncStream scoped to their channel. Unrecognised channels are dropped.
public actor WebSocketClient: WebSocketClientProtocol {
    private var task: URLSessionWebSocketTask?
    private let session: URLSession
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let router = ChannelRouter()

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func connect(to url: URL) async throws {
        guard task == nil else { return } // double-connect guard
        let newTask = session.webSocketTask(with: url)
        task = newTask
        newTask.resume()
        receiveLoop(task: newTask)
    }

    public func disconnect() async {
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
        await router.cancelAll()
    }

    // nonisolated: defers all state access to Tasks — no actor hop required at call site.
    public nonisolated func subscribe(channel: String) -> AsyncStream<String> {
        AsyncStream { continuation in
            Task { await router.add(continuation, for: channel) }
            continuation.onTermination = { _ in
                Task { await self.router.remove(channel: channel) }
            }
        }
    }

    public func send(payload: String, channel: String) async throws {
        guard let task else { throw WebSocketError.notConnected }
        let envelope = WebSocketEnvelope(channel: channel, payload: payload)
        guard let data = try? encoder.encode(envelope),
              let text = String(data: data, encoding: .utf8) else {
            throw WebSocketError.encodingFailed
        }
        try await task.send(.string(text))
    }

    // MARK: - Private

    // Captures the task directly — loop survives disconnect() setting self.task = nil,
    // and avoids a repeated actor hop on every receive iteration.
    private func receiveLoop(task: URLSessionWebSocketTask) {
        Task {
            do {
                while true {
                    let message = try await task.receive()
                    if case .string(let text) = message,
                       let data = text.data(using: .utf8),
                       let envelope = try? decoder.decode(WebSocketEnvelope.self, from: data) {
                        await router.yield(envelope.payload, to: envelope.channel)
                    }
                }
            } catch {
                await router.cancelAll()
            }
        }
    }
}

// Actor that owns the channel → continuation map, making mutations thread-safe.
private actor ChannelRouter {
    private var continuations: [String: AsyncStream<String>.Continuation] = [:]

    func add(_ continuation: AsyncStream<String>.Continuation, for channel: String) {
        continuations[channel] = continuation
    }

    func remove(channel: String) {
        continuations.removeValue(forKey: channel)
    }

    func yield(_ value: String, to channel: String) {
        continuations[channel]?.yield(value)
    }

    func cancelAll() {
        continuations.values.forEach { $0.finish() }
        continuations.removeAll()
    }
}
