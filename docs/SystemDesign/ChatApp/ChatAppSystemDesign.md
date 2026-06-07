# ChatApp — System Design

## 1. Requirements

### Functional
- List all conversations with avatar (initials), last message preview, timestamp, and unread badge
- Open a conversation and view full message history (paginated in a real system; mock-data here)
- Send text messages via HTTP POST (not WebSocket — outbound is intentionally HTTP)
- Receive real-time messages via WebSocket, multiplexed by conversation channel
- Offline send queue: if a send fails due to network loss, persist the message locally; retry automatically on next app foreground
- Heterogeneous message types: `text`, `image`, `audio`, `deleted` — exhaustive handling at compile time via enum

### Non-Functional
- One shared `WebSocketClient` connection (CoreKit); per-conversation channels via `subscribe(channel: "conv-{id}")` — O(1) connections per user, not O(conversations)
- WebSocket is receive-only for inbound events; HTTP POST is the outbound path
- Idempotency key (`clientId` UUID) on every send — safe retry without duplicates
- `PendingMessageQueue`: Swift actor, persisted to `Documents/pending_messages.json` across app restarts
- Flush triggered by `UIApplication.didBecomeActiveNotification` in `ChatCoordinator` — not in any ViewController
- `@MainActor` on all ViewModels; `defer { isLoading = false }` on every async path

---

## 2. API Design

### WebSocket (inbound events only)

**Connection:** `wss://<server>/ws`  
**Channel subscription:** `"conv-{conversationId}"` (e.g. `"conv-abc-123"`)

The outer envelope is handled by `CoreKit.WebSocketClient`:

```json
{
  "channel": "conv-abc-123",
  "payload": "<JSON-encoded ChatEventDTO>"
}
```

**ChatEventDTO** (inner payload after channel routing)

```json
{
  "type": "message.new",
  "message": { /* MessageDTO */ }
}
```

| Event type | Meaning |
|---|---|
| `message.new` | New message received — append to list |
| `message.updated` | Message content changed (edit, status update) |
| `message.deleted` | Message removed — remove from list |

### HTTP (outbound send + history fetch)

| Action | Method | Endpoint | Body | Implementation status |
|---|---|---|---|---|
| Fetch message history | GET | `/api/v1/conversations/{id}/messages` | — | **Stub** — returns `[]`; local mock JSON covers the demo |
| Send message | POST | `/api/v1/conversations/{id}/messages` | see below | **Stub** — synthesises a local response; no live server |

**Send message request body** (current implementation — text-only)

```json
{
  "client_id": "uuid-v4",
  "type": "text",
  "text": "Hello there"
}
```

`client_id` is the idempotency key — if the server already has a message with this UUID it returns the existing record rather than creating a duplicate.

**Full production body** (target shape when image/audio sending is implemented)

```json
{
  "client_id": "uuid-v4",
  "type": "text | image | audio",
  "text": "Hello there",
  "image_url": "https://...",
  "audio_url": "https://...",
  "audio_duration": 12.5,
  "aspect_ratio": 1.78
}
```

**Send message response** — server returns the confirmed `MessageDTO` with `status: "sent"`.

> `MessageRemoteDataSource` currently synthesises a local response (no live server). The struct types and interface contract match exactly what a real server would expect. Fetch history also returns `[]` — message history is loaded from bundled mock JSON via `MessageLocalDataSource`.

---

## 3. Data Model Design

### Domain Models

```swift
struct Conversation: Sendable, Equatable {
    let id: String
    let participantIds: [String]
    let participantNames: [String: String]   // userId → display name
    let lastMessage: String
    let lastMessageAt: Date
    let unreadCount: Int
}

struct Message: Sendable, Equatable {
    let id: String
    let conversationId: String
    let senderId: String
    let content: MessageContent
    let status: MessageStatus
    let createdAt: Date
}

// No optionals for content type.
// An optional `text: String?` creates invalid states at the type level — a message
// with no text and no image is legal Swift but illegal in the domain.
enum MessageContent: Sendable, Equatable {
    case text(String)
    case image(URL, aspectRatio: CGFloat)
    case audio(duration: TimeInterval, url: URL)
    case deleted
}

enum MessageStatus: String, Codable, Sendable, Equatable {
    case pending    // locally queued, not yet sent
    case sent       // server acknowledged
    case delivered  // delivered to recipient device
    case read       // recipient opened the conversation
}
```

### DTOs (Codable, mirror wire format)

```swift
// Wire format optionals reflect API shape — Mapper decides what's valid
struct MessageDTO: Codable, Sendable {
    let id: String
    let conversationId: String      // "conversation_id"
    let senderId: String            // "sender_id"
    let type: String                // "text" | "image" | "audio" | "deleted"
    let text: String?
    let imageURL: String?           // "image_url"
    let aspectRatio: CGFloat?       // "aspect_ratio"
    let audioDuration: TimeInterval? // "audio_duration"
    let audioURL: String?           // "audio_url"
    let createdAt: String           // "created_at" — ISO8601
    let status: String              // "pending" | "sent" | "delivered" | "read"
}

struct ConversationDTO: Codable, Sendable {
    let id: String
    let participantIds: [String]        // "participant_ids"
    let participantNames: [String: String] // "participant_names"
    let lastMessage: String             // "last_message"
    let lastMessageAt: String           // "last_message_at" — ISO8601
    let unreadCount: Int                // "unread_count"
}

// Inner payload after WebSocket channel routing
struct ChatEventDTO: Codable, Sendable {
    let type: String
    let message: MessageDTO?
}
```

### Request types (Domain inputs — `Request<Query, Path>`)

```swift
// query.userId scopes the list to the current user's conversations
struct FetchConversationsQuery: Sendable, Equatable { let userId: String }
typealias FetchConversationsRequest = Request<FetchConversationsQuery, Void>

// path.conversationId identifies which conversation's history to load
struct FetchMessagesPath: Sendable, Equatable { let conversationId: String }
typealias FetchMessagesRequest = Request<Void, FetchMessagesPath>

// Not a Request<Query,Path> — send is a mutation; FetchPolicy doesn't apply.
// clientId (idempotency key) is generated inside init, not at the call site.
struct SendMessageRequest: Sendable {
    let conversationId: String
    let content: MessageContent
    let clientId: String   // UUID().uuidString — generated in init
}
```

### PendingMessageDTO (offline queue persistence)

```swift
// Persisted offline queue entry — structurally mirrors MessageDTO content fields
struct PendingMessageDTO: Codable, Sendable {
    let id: String           // clientId — doubles as idempotency key on retry
    let conversationId: String
    let type: String
    let text: String?
    let imageURL: String?
    let aspectRatio: CGFloat?
    let audioDuration: TimeInterval?
    let audioURL: String?
    let queuedAt: String     // ISO8601
}
```

---

## 4. High-Level Design

```
┌─────────────────────────────────────────────────────────────────────┐
│  Presentation (UIKit + Combine)                                     │
│  ConversationListViewController / ConversationListViewModel         │
│  ChatViewController / ChatViewModel                                 │
│  Cells: TextMessageCell, AudioMessageCell,                          │
│         ImageMessageCell, DeletedMessageCell                        │
│  (UICollectionView with heterogeneous registration)                 │
└────────────────────────────┬────────────────────────────────────────┘
                             │
┌────────────────────────────▼────────────────────────────────────────┐
│  Domain                                                             │
│  FetchConversationsUseCase  → ConversationRepositoryProtocol        │
│  FetchMessagesUseCase       → MessageRepositoryProtocol             │
│  StreamMessagesUseCase      → MessageRepositoryProtocol             │
│  SendMessageUseCase         → MessageRepositoryProtocol             │
│  FlushPendingMessagesUseCase → MessageRepositoryProtocol            │
└────────────────────────────┬────────────────────────────────────────┘
                             │
┌────────────────────────────▼────────────────────────────────────────┐
│  Data                                                               │
│  ConversationRepository  → ConversationLocalDataSource (JSON mock)  │
│  MessageRepository       → MessageRemoteDataSource (HTTP POST/GET)  │
│                          → MessageLocalDataSource (actor, in-memory)│
│                          → WebSocketClientProtocol (CoreKit)        │
│                          → PendingMessageQueue (actor, disk-backed) │
│  Mappers: ConversationMapper, MessageMapper                         │
└────────────────────────────┬────────────────────────────────────────┘
                             │ imports
┌────────────────────────────▼────────────────────────────────────────┐
│  CoreKit                                                            │
│  WebSocketClient (actor, URLSessionWebSocketTask, ChannelRouter)    │
│  APIClient (URLSession-based HTTP)                                  │
└─────────────────────────────────────────────────────────────────────┘
```

**Navigation (Coordinator pattern)**

```
ChatCoordinator (composition root + flush orchestrator)
  └── ConversationListViewController
        └── ChatViewController (pushed on conversation tap)
```

`ChatCoordinator` is injected with `WebSocketClientProtocol` by the host app. It observes `UIApplication.didBecomeActiveNotification` and calls `FlushPendingMessagesUseCase` — this logic lives in the Coordinator, not in any ViewController.

---

## 5. Data Flow

### Message streaming (open a conversation)

```
ChatViewController.viewDidLoad()
  → ChatViewModel.start()
      → StreamMessagesUseCase.execute(conversationId: "conv-abc")
          → MessageRepository.messages(conversationId: "conv-abc")
              [Phase 1 — cache, instant]
              → MessageLocalDataSource.messages(conversationId:) → [MessageDTO]
              → MessageMapper.toDomain → [Message]
              → continuation.yield([Message])   // View renders cached messages

              [Phase 2 — live, runs indefinitely]
              → WebSocketClient.subscribe(channel: "conv-abc")
                  for await payload in AsyncStream<String>:
                      decode ChatEventDTO
                      switch event.type:
                        "message.new"     → localDataSource.save(dto) → accumulated.append
                        "message.deleted" → accumulated.removeAll(id:)
                      continuation.yield([Message])   // View updates in real time
```

### Send message

```
User taps Send, enters "Hello there"
  → ChatViewModel.send(text: "Hello there")
      → SendMessageUseCase.execute(
            SendMessageRequest(conversationId: "conv-abc", content: .text("Hello there"))
            // clientId = UUID().uuidString generated inside SendMessageRequest.init
        )
          → MessageRepository.send(request:)
              // SendMessageAPIRequest maps only text content — current impl is text-only
              → SendMessageAPIRequest(from: request)   // { client_id, type: "text", text }
              → POST /api/v1/conversations/{id}/messages
              [success]
                  → MessageDTO (status: "sent") → localDataSource.save(dto)
                  → MessageMapper.toDomain → Message
                  → returns Message to ViewModel → View updates
              [failure — network loss]
                  → PendingMessageDTO(id: request.clientId, ...) → PendingMessageQueue.enqueue
                  → throw ChatError.messageQueued
      → ViewModel: catches .messageQueued → shows message with .pending status indicator
```

### Offline flush (on app foreground)

```
UIApplication.didBecomeActiveNotification
  → ChatCoordinator.flushAllPendingMessages()
      → FlushPendingMessagesUseCase.execute(conversationId:) for each active conversation
          → MessageRepository.flushPending(conversationId:)
              → PendingMessageQueue.dequeue(conversationId:) → [PendingMessageDTO]
              for each pending:
                  → SendMessageAPIRequest(from: pending) → POST (same idempotency key)
                  [success] → localDataSource.save(dto) → message shows as .sent
                  [failure] → PendingMessageQueue.enqueue(pending)  // will retry next foreground
```

### WebSocket multiplexing (why one socket is enough)

```
Single WebSocketClient (CoreKit actor)
  └── One URLSessionWebSocketTask to wss://<server>/ws
  └── ChannelRouter (private actor)
        ├── "conv-abc" → AsyncStream.Continuation → MessageRepository (conv-abc)
        ├── "conv-xyz" → AsyncStream.Continuation → MessageRepository (conv-xyz)
        └── ...

Incoming frame: { "channel": "conv-abc", "payload": "{...}" }
  → WebSocketClient.receiveLoop decodes WebSocketEnvelope
  → ChannelRouter.yield(payload, to: "conv-abc")
  → conv-abc subscriber's AsyncStream yields the raw payload string
```

**Why HTTP POST for outbound, not WebSocket?**  
Outbound messages need HTTP semantics: guaranteed delivery confirmation, status codes (409 conflict, 5xx retry), and idempotency keys. WebSocket fire-and-forget has none of these. HTTP POST for send + WebSocket for receive is the correct split.

---

## 6. Technical Deep-dive

### Why HTTP POST for outbound, not WebSocket?

WebSocket is a transport — it has no delivery semantics. If you send a message over WebSocket and the frame is dropped, you get no error. HTTP POST gives you: a status code (200 sent, 409 conflict, 5xx retry), a request body you can log and replay, and a confirmed response with the server-assigned message ID. The idempotency key (`clientId`) only works over a request/response protocol. The split is intentional: WebSocket for inbound real-time events, HTTP for outbound actions that need a result.

### Why one WebSocket connection instead of one per conversation?

One socket per conversation is O(conversations) connections per user. A user with 50 open conversations would hold 50 persistent TCP connections — unsustainable on server and mobile battery. One shared `WebSocketClient` with channel multiplexing is O(1) per user. The `ChannelRouter` actor maps channel strings to continuations; subscribing to a new conversation adds one entry to the router's dictionary, not a new socket.

### Why `MessageContent` enum instead of optional fields?

Optional fields (`text: String?`, `imageURL: URL?`) make invalid states representable at the type level. A `MessageDTO` with no text and no image URL is syntactically valid Swift but semantically illegal in the domain. The `MessageContent` enum makes illegal states unrepresentable: every `Message` has exactly one content case. The switch in the cell factory is exhaustive at compile time — adding a new message type without handling it is a build error, not a runtime crash.

### Why `clientId` (idempotency key) generated in `SendMessageRequest.init`?

If generated at the ViewModel call site, the same action (e.g. a button tap that retries) would produce different UUIDs each time — defeating idempotency. If generated in the Repository or DataSource, the key is not accessible to the offline queue. Generating it in `SendMessageRequest.init` means: the same `Request` object always carries the same `clientId`, the queue can persist it, and retries (whether from queue flush or network retry) re-use the same key. The server deduplicates on `client_id` — safe to call twice with the same UUID.

### Why `PendingMessageQueue` is a Swift actor?

The queue is accessed from multiple concurrency contexts: the send path (ViewModel → UseCase → Repository), the flush path (Coordinator on app foreground), and potentially background retry logic. A class with a lock would work but requires manual locking discipline. An actor serialises all access automatically — no lock, no data race, compiler-enforced.

### Why flush is triggered in `ChatCoordinator`, not in a ViewController?

`UIApplication.didBecomeActiveNotification` fires app-wide — it doesn't belong to any one screen. If the `ConversationListViewController` owned the flush, it would miss events while another screen is active. `ChatCoordinator` is app-scoped for the chat feature; it lives as long as the chat module is active and is the correct owner of cross-screen infrastructure concerns.

### Why `MessageLocalDataSource` is in-memory (actor) rather than disk-backed?

Message history for the current session is loaded from bundled mock JSON via the local data source. In a production app it would be backed by Core Data or SQLite. The actor boundary is already in place — swapping the storage backend is a one-file change inside `MessageLocalDataSource` without touching any caller.

### Interview Q&A

| Question | Answer |
|---|---|
| Why WebSocket for inbound but HTTP for outbound? | HTTP gives you delivery confirmation, status codes, and idempotency. WebSocket fire-and-forget has none of those guarantees. The direction of the data determines the protocol. |
| Why one socket? | O(1) connections per user. O(conversations) is unsustainable. Channel multiplexing handles any number of conversations on one TCP connection. |
| Why enum for message type, not optionals? | Illegal states become unrepresentable. The cell factory switch is exhaustive at compile time — adding a new type without handling it is a build error, not a runtime crash. |
| What happens if a send fails while offline? | `PendingMessageQueue.enqueue(PendingMessageDTO)` persists it to disk. On next app foreground, `ChatCoordinator` triggers `FlushPendingMessagesUseCase` which re-sends with the same `clientId` — server deduplicates. |
| Why is `clientId` generated in `SendMessageRequest.init`? | So the same request object always carries the same key. Retries and queue flushes re-use it automatically — no caller needs to track the UUID. |
