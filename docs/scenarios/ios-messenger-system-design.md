# iOS Messenger App — System Design

**Source:** Mock Mobile System Design Interview — Andrey Tech (ex-Meta)

> Scenario extension of [`docs/ios-app-system-design-philosophy.md`](../ios-app-system-design-philosophy.md).
> Read the delta below first.

---

## Delta — What This Scenario Adds

### Same as generic architecture
- Clean Architecture + MVVM + UIKit
- DTO → Mapper → Domain Model (Mapper is the only type that knows both)
- `FetchPolicy` (.fresh / .cached / .strict) on all Repository reads
- Typed `Param` structs on every UseCase
- `@MainActor` on ViewModel — all state mutations on main thread
- `defer { isLoading = false }` — guaranteed cleanup on success and failure
- `[weak self]` in all closures to avoid retain cycles
- Coordinator-based navigation, DI via manual init injection
- Mock-the-layer-below testing strategy
- `async/await` for I/O; Combine for reactive binding to `@Published` state
- `ThirdPartyDataSource` facade pattern — wraps third-party SDKs; app calls protocol, never SDK directly
- Idempotency keys on mutations — client-generated UUID at `Param` call site for any retryable mutation
- HTTP `409 ≠ 5xx` — concurrency conflicts and transient server errors must never share a code path
- Infrastructure layer (`Gateway` suffix) — Gateway trigger is cross-layer span, not SDK imports; single-layer SDKs wrap in their natural layer (DataSource or Service); **this scenario has no Gateway** — WebSocket is networking-transport only (no Presentation footprint) and wraps as `WebSocketClient` in Data, not as a Gateway
- External layer (outermost ring) — actual SDKs and OS frameworks; UIKit / SwiftUI / Combine need no wrapper (reactive/UI primitives used directly); all other SDKs always wrapped; wrapper placement scope-based: single-layer SDK → DataSource or Service, cross-layer SDK → Gateway in Infrastructure

### What this scenario adds

| Concept | Generic | This Scenario |
|---|---|---|
| Real-time data | Not covered | `MessageStreamService` Domain Service — calls `MessageStreamDataSourceProtocol`; `MessageStreamDataSource` wraps `WebSocketClient` in Data, exposes `AnyPublisher<Message, Never>` per chat |
| Offline write queue | Not covered | `MessageSyncService` Domain Service — queues `isSent = false` messages, flushes on app foreground |
| Three-tier API strategy | `FetchPolicy` covers read intent | Initial load / cursor pagination / delta sync by `sequenceId` — three distinct endpoints per list screen |
| Local DB as SSOT | `LocalDataSource` for cache | Realm via `LocalDataSource` — renders immediately from cache, syncs in background; WebSocket frames upsert into same store |
| File/attachment storage | Not in generic | `AttachmentFileDataSource` — stores media binaries; only URL stored in `MessageLocalDataSource` |
| Message status lifecycle | Not covered | `sentTime` / `receivedTime` / `readTime` + `isSent: Bool` for local delivery tracking |

### Key decisions unique to this scenario

- **`MessageStreamService` must be app-scoped.** If owned by `ChatThreadViewModel`, the WebSocket closes when the screen pops — incoming messages are silently missed.
- **`MessageSyncService` triggers on app lifecycle, not a timer.** Fires on `sceneDidBecomeActive` / `applicationDidBecomeActive`, not on a polling interval.
- **Local DB is the single source of truth.** ViewModels never read from the network. Network writes flow into `MessageLocalDataSource` (upsert by `id`); the LocalDataSource stream drives the ViewModel.
- **Three-tier REST is required alongside FetchPolicy.** FetchPolicy (`.fresh` / `.cached`) covers read intent but doesn't model delta sync — fetching only records changed since a known `sequenceId` is a separate concern.
- **Upsert by `message.id`, never append.** A message can arrive via both WebSocket and a delta REST sync. Appending would duplicate it; upserting by `id` is idempotent.

---

## Requirements

### Functional
- 1-to-1 chat messaging (no group chats for MVP)
- Chat List screen: avatar, name, message preview, timestamp — sorted by most recent activity
- Chat Thread screen: scrollable message history, send/receive messages
- Media sharing: image and file attachments with thumbnail and full-resolution variants
- Offline mode: view cached chat history; queue and deliver pending sends on reconnect

### Non-Functional
- **Offline-first:** render from local cache immediately on every screen open
- **Battery / bandwidth optimized:** delta sync (not full refresh), no polling
- **Real-time:** WebSocket after initial REST sync
- MVP excludes: push notifications, typing indicators

---

## API Design

### REST — Three-Tier Strategy

Every list screen has three endpoint tiers, each with a distinct job:

```
Chat List
  GET  /chat/all                         → { chats: [Chat], nextCursor: String? } — initial 15
  GET  /chat/all?cursor=<cursor>         → { chats: [Chat], nextCursor: String? } — next 15 (scroll)
  GET  /chat/all/delta?sequenceId=<id>  → only chats changed since sequenceId (background sync)

Chat Thread
  GET  /chat/{chat_id}/all                    → 50 most recent messages (initial load)
  GET  /chat/{chat_id}/all/before?timestamp=  → next 50 older messages (scroll up — append-only, timestamp is stable)
  GET  /chat/{chat_id}/all/after?timestamp=   → messages since timestamp (foreground sync)

Send (REST fallback — prefer WebSocket when socket is live)
  POST /chat/{chat_id}/message                → send a Message object

Real-time
  WS   /chat/{chat_id}                        → event stream after REST sync
```

**Why three tiers?** Each tier has a distinct job:
- Initial load: snappiness — populate the screen immediately
- Pagination: avoid large payloads — load older records only on demand
- Delta sync: battery efficiency — payload size proportional to change, not list size

### WebSocket Event Model

```swift
struct WSEvent<T: Decodable> {
    let type: WSEventType
    let payload: T
}

enum WSEventType {
    case messageSent
    case messageReceived
    // case typingIndicator  // future — additive, no breaking change
}
```

A strongly-typed envelope makes new event types additive. No stringly-typed `if eventType == "message_sent"` scattered across the codebase.

---

## Data Model

### Domain Models

```swift
struct Chat {
    let chatId: String
    let users: [User]           // array enables future group chat
    let status: ChatStatus      // .read | .unread
    let preview: String         // last message snippet for chat list
    let lastActivity: Date      // drives sort order — optimistically updated on send
}

enum ChatStatus { case read, unread }

struct User {
    let userId: String
    let imageThumbnail: URL     // low-res, used in chat list
    let imageFullRes: URL       // high-res, used in profile view
    let firstName: String
    let lastName: String
    let isActive: Bool          // online indicator
}

struct Message {
    let id: String              // dedup key — upsert, never append
    let text: String
    let attachments: [Attachment]
    let sentTime: Date
    let receivedTime: Date?
    let readTime: Date?
    let isSent: Bool            // local flag: has this been delivered to server?
    let isRead: Bool
}

struct Attachment {
    let type: AttachmentType    // .image | .video | .pdf
    let url: URL                // URL only — binary stored in AttachmentFileDataSource
}

enum AttachmentType { case image, video, pdf }
```

### DTOs (mirror API shape, Codable)

```swift
struct ChatDTO: Codable       { chat_id, users, status, preview, last_activity }
struct UserDTO: Codable       { user_id, image_thumbnail, image_fullres, first_name, last_name, is_active }
struct MessageDTO: Codable    { id, text, attachments, sent_time, received_time, read_time, is_sent, is_read }
struct AttachmentDTO: Codable { type, url }
```

Mappers (`ChatMapper`, `MessageMapper`) are the only types that know both DTO and Domain model.

---

## Architecture

### Layer Breakdown

```
Presentation
  ChatListViewController       → ChatListViewModel
      FetchChatsUseCase · MessageStreamService.subscribe()
  ChatThreadViewController     → ChatThreadViewModel
      FetchMessagesUseCase · SendMessageUseCase · MarkReadUseCase
      MessageStreamService (same app-scoped instance) · MessageSyncService

Domain
  UseCases (stateless):
    FetchChatsUseCase          execute(policy:param:) → [Chat]      → ChatRepositoryProtocol
    FetchMessagesUseCase       execute(policy:param:) → [Message]   → MessageRepositoryProtocol
    SendMessageUseCase         execute(param:)                      → MessageRepositoryProtocol
    MarkReadUseCase            execute(param:)                      → MessageRepositoryProtocol

  Domain Services (stateful / app-scoped):
    MessageStreamService       connect/disconnect · subscribe(chatId:) → AnyPublisher<Message, Never>
                               calls MessageStreamDataSourceProtocol — never touches WebSocket library directly
    MessageSyncService         syncPending() on foreground — flushes isSent=false messages
                               calls SendMessageUseCase for retries

  Models:   Chat, Message, User, Attachment, ChatStatus, AttachmentType
  Params:   ChatListParam(), ChatParam(chatId:), SendMessageParam(chatId:, message:),
            MarkReadParam(chatId:, messageIds:)

Data
  MessageRepository   : MessageRepositoryProtocol
    └─ MessageRemoteDataSource  → APIClient (three-tier REST endpoints)
    └─ MessageLocalDataSource   → Realm (SSOT — upsert by message.id)
    └─ MessageMapper

  ChatRepository      : ChatRepositoryProtocol
    └─ ChatRemoteDataSource     → APIClient (GET /chat/all with cursor)
    └─ ChatLocalDataSource      → Realm (live query drives ChatListViewModel)
    └─ ChatMapper

  MessageStreamDataSource : MessageStreamDataSourceProtocol
    └─ WebSocketClient (connect / receive() → AsyncStream<Data> / disconnect)
    └─ decodes raw frames → MessageDTO; MessageStreamService calls via protocol, never the SDK directly

  WebSocketClient
    └─ wraps URLSessionWebSocketTask (or Starscream)
    └─ connect(to:) / send(_:) / receive() → AsyncStream<Data> / disconnect()
    └─ persistent-connection peer to APIClient — networking transport only, no Presentation footprint

  AttachmentFileDataSource — binary files on disk; only URL stored in MessageLocalDataSource

Infrastructure
  None — no SDK in this scenario spans multiple layers; WebSocket is Data-only

External
  URLSessionWebSocketTask / Starscream  →  WebSocketClient (Data)
  Realm                                 →  MessageLocalDataSource · ChatLocalDataSource (Data)
  URLSession                            →  APIClient (Data)

Application
  AppCoordinator + ChatCoordinator (navigation only) + DI via manual init injection
```

### Vocabulary Translation

| Interview term | Generic arch equivalent | Layer |
|---|---|---|
| `ChatThreadCoordinator` (data orchestrator) | `FetchMessagesUseCase` + `MessageStreamService` | Domain |
| `ChatListCoordinator` (data orchestrator) | `FetchChatsUseCase` + `MessageStreamService` | Domain |
| `ChatThreadRepo` | `MessageRepository: MessageRepositoryProtocol` | Data |
| `ChatListRepo` | `ChatRepository: ChatRepositoryProtocol` | Data |
| `APIClient` (held by Coordinator) | `MessageRemoteDataSource` wrapping `APIClient` | Data |
| `WebSocket` (held by Coordinator) | `MessageStreamService` Domain Service | Domain |
| `StateManager` | `ViewState<T>` enum + `@Published var state` on ViewModel | Presentation |
| `OfflineSyncManager` | `MessageSyncService` Domain Service | Domain |
| `Local DB (Realm)` | `MessageLocalDataSource` (Realm as backend) | Data |
| `File Storage` | `AttachmentFileDataSource` | Data |

The interview used "Coordinator" for both navigation and data orchestration. In this architecture those are two separate concerns: `ChatCoordinator` handles navigation (Application layer); `FetchMessagesUseCase` handles data access (Domain); `MessageStreamService` owns the WebSocket (Domain Service, app-scoped).

### Component Graph

```
AppCoordinator
  └── ChatCoordinator (navigation only)
         ├── ChatListViewController + ChatListViewModel
         │       FetchChatsUseCase → ChatRepository → ChatRemoteDataSource (APIClient)
         │                                          → ChatLocalDataSource (Realm)
         │       MessageStreamService.subscribe(chatId:) → AnyPublisher<Message, Never>
         │
         └── ChatThreadViewController + ChatThreadViewModel
                 FetchMessagesUseCase → MessageRepository → MessageRemoteDataSource (APIClient)
                                                          → MessageLocalDataSource (Realm)
                 MessageStreamService (same app-scoped instance)
                     └── MessageStreamDataSource → WebSocketClient (URLSessionWebSocketTask)
                 MessageSyncService (app-scoped — flushes isSent=false on foreground)

AttachmentFileDataSource — stores attachment binaries, referenced by URL in Message model
```

---

## Data Flow

### Load Chat Thread (offline-first)

Pattern A — two awaits in the ViewModel. `async/await` returns once; a single `execute()` cannot update state twice.

```
ChatThreadViewController.viewDidLoad()
  → ChatThreadViewModel.load()
      state = .loading

      // Phase 1 — cache (instant)
      if let cached = try? await FetchMessagesUseCase.execute(policy: .strict, param: ChatParam(chatId:))
          → MessageRepository checks MessageLocalDataSource only — throws on miss
          → ViewModel maps [Message] → UIModel
          → state = .success(cached)                    // renders immediately from cache

      // Phase 2 — network (background)
      let fresh = try await FetchMessagesUseCase.execute(policy: .fresh, param: ChatParam(chatId:))
          → MessageRepository fetches MessageRemoteDataSource → [MessageDTO] → MessageMapper → [Message]
          → MessageLocalDataSource.upsert(dtos)          // upsert by message.id
          → ViewModel maps merged [Message] → UIModel
          → state = .success(fresh)                      // view refreshes with latest

      defer: isLoading = false

      → MessageStreamService.subscribe(chatId: chatId) → AnyPublisher<Message, Never>
          → each incoming Message: MessageLocalDataSource.upsert(dto) → state updated
```

### Send Message (with offline queue)

```
User taps send
  → ChatThreadViewModel.send(text:)
      → MessageLocalDataSource.upsert(MessageDTO(id: UUID(), text: text, isSent: false))
      → state updated optimistically (message appears as "pending")
      → SendMessageUseCase.execute(param: SendMessageParam(chatId:, message:))
          → MessageRepository.send()
              → MessageRemoteDataSource.post(/chat/{chat_id}/message)
              → on success: MessageLocalDataSource.update(id:, isSent: true)
              → on failure: isSent remains false → MessageSyncService will retry
```

### Background Sync (MessageSyncService)

```
sceneDidBecomeActive / applicationDidBecomeActive
  → MessageSyncService.syncPending()
      → MessageLocalDataSource.fetch(where: isSent == false) → [MessageDTO]
      → for each: SendMessageUseCase.execute(param:)
          → on success: MessageLocalDataSource.update(id:, isSent: true)
          → on failure: leave for next foreground event
```

### Load Chat List (offline-first)

Pattern A — two awaits in the ViewModel.

```
ChatListViewController.viewDidLoad()
  → ChatListViewModel.load()
      state = .loading

      // Phase 1 — cache (instant)
      if let cached = try? await FetchChatsUseCase.execute(policy: .strict, param: ChatListParam())
          → ChatRepository checks ChatLocalDataSource only — throws on miss
          → ViewModel maps [Chat] → UIModel
          → state = .success(cached)                  // renders immediately from cache

      // Phase 2 — network (background)
      let response = try await FetchChatsUseCase.execute(policy: .fresh, param: ChatListParam())
          → ChatRemoteDataSource.fetch()              // GET /chat/all
          → PagedChatsResponse { chats: [ChatDTO], nextCursor: String? }
          → ChatLocalDataSource.upsert(dtos)          // upsert by chatId
          → nextCursor stored in ChatListViewModel
          → state = .success(merged chats, sorted by lastActivity)

      defer: isLoading = false
```

### Chat List Scroll Pagination (cursor-based)

```
User scrolls to bottom of chat list
  → ChatListViewModel.loadNextPage()
      guard let cursor = nextCursor else { return }   // nil = no more pages
      → FetchChatsUseCase.execute(policy: .fresh, param: ChatListParam(cursor: cursor))
          → ChatRemoteDataSource.fetch()               // GET /chat/all?cursor=<cursor>
          → PagedChatsResponse { chats: [ChatDTO], nextCursor: String? }
          → ChatLocalDataSource.upsert(dtos)
          → nextCursor updated (nil = end of list reached)
          → state appended with next page of chats
```

### Receive Message via WebSocket (foreground, cross-screen)

```
WebSocket receives WSEvent { type: .messageReceived, payload: MessageDTO }
  → MessageStreamDataSource decodes raw frame → MessageDTO
  → MessageStreamService receives MessageDTO:
      1. calls MessageRepository.receiveMessage(dto:)    // upsert into local DB before publishing
             → MessageLocalDataSource.upsert(dto)        // upsert by message.id
               → Realm live query fires
               → ChatThreadViewModel.state updated (if this thread is open)
             → ChatLocalDataSource.upsert(ChatDTO(
                   chatId: dto.chatId,
                   preview: dto.text,
                   lastActivity: dto.sentTime))
               → Realm live query fires
               → ChatListViewModel.state re-sorted (chat bubbles to top, preview updated)
      2. publishes Message (Domain model) via AnyPublisher<Message, Never>
         → ViewModel subscribers receive domain model; no second upsert needed

Key: MessageStreamService writes to local DB first (via MessageRepository), then publishes.
     ViewModels observe their own Realm DataSource and the publisher independently —
     neither knows about the other.
```

### App Foreground — Gap Recovery

```
sceneDidBecomeActive / applicationDidBecomeActive
  → AppCoordinator.handleForeground():

      1. MessageStreamService.connect()
         → WebSocket reopened

      2. For each open / recently-visited chatId:
         FetchMessagesUseCase.execute(policy: .fresh,
             param: MessageParam(chatId:, after: lastKnownTimestamp))
         → GET /chat/{id}/all/after?timestamp=lastKnown
         → MessageLocalDataSource.upsert(dtos)        // fill gap from background period
         → state updated with missed messages

      3. MessageSyncService.syncPending()
         → fetch isSent == false → retry sends

Order matters: fill the REST gap before relying on WebSocket.
Messages that arrived during the background period are fetched by REST.
WebSocket handles only new messages from reconnect forward.
```

### Chat Thread Scroll Pagination (scroll up for older messages)

```
User scrolls to top of message thread
  → ChatThreadViewModel.loadOlderMessages()
      guard let oldestTimestamp = messages.first?.sentTime else { return }
      → FetchMessagesUseCase.execute(policy: .fresh,
             param: MessageParam(chatId:, before: oldestTimestamp))
          → MessageRemoteDataSource.fetch()            // GET /chat/{id}/all/before?timestamp=
          → [MessageDTO] → MessageMapper.toDomain() → [Message]
          → MessageLocalDataSource.upsert(dtos)        // persist for future offline access
          → state prepended with older messages

Note: timestamp is stable here — message threads are append-only at the tail.
      New messages arrive at the bottom; older messages never reorder.
```

### Mark as Read

```
User opens ChatThread (or scrolls to bottom, viewing latest messages)
  → ChatThreadViewModel.markAsRead(visibleMessageIds: [...])
      → MessageLocalDataSource.update(ids:, readTime: Date())   // optimistic update
      → state updated immediately (read tick appears)
      → MarkReadUseCase.execute(param: MarkReadParam(chatId:, messageIds:))
          → MessageRemoteDataSource.post(PATCH /chat/{chat_id}/read)
          → on success: server confirmed — local state already correct
          → on failure: readTime remains set locally; reconcile on next delta sync

      → ChatLocalDataSource.update(chatId:, status: .read)
         → Realm live query fires
         → ChatListViewModel.state updated             // unread indicator clears on chat list
```

---

## Deep Dives

### WebSocket Lifecycle

`MessageStreamService` is a Domain Service (app-scoped singleton):

```swift
class MessageStreamService {
    private let streamDataSource: MessageStreamDataSourceProtocol   // Data — injected via DI

    func connect()
    func subscribe(to chatId: String) -> AnyPublisher<Message, Never>
    func disconnect()
}
```

Lifecycle:
1. App foreground → `AppCoordinator` calls `messageStreamService.connect()`
2. View appears → ViewModel calls `messageStreamService.subscribe(to: chatId)`, cancels on `viewWillDisappear`
3. App backgrounds → `messageStreamService.disconnect()` (socket closed to save battery)
4. App foregrounds → `connect()`, then `FetchMessagesUseCase` with delta endpoint to catch messages missed during the background gap

The ViewModel subscribes to both `FetchMessagesUseCase` and `MessageStreamService` — both feed the same `@Published var state: ViewState<[Message]>`.

### Three-Tier REST vs FetchPolicy

`FetchPolicy` covers read intent (.fresh / .cached / .strict) but doesn't model delta sync. Three-tier maps onto FetchPolicy as:

| Tier | Endpoint | FetchPolicy analog |
|---|---|---|
| Initial load | `GET /chat/{id}/all` | `.cached` → show local, then `.fresh` in background |
| Cursor pagination | `GET .../before?timestamp=` | `.fresh` — always hits network for older pages |
| Delta sync | `GET .../delta/after?sequenceId=` | No analog — payload is change-proportional, not list-proportional |

Delta sync is the battery-efficiency win: instead of re-fetching 50 messages, fetch only the 3 that arrived while the app was in the background.

### Pagination Inconsistency (Interviewer-Flagged Weakness)

Timestamp-based pagination is fragile when new messages arrive mid-scroll:

```
Chat list, Page 1: [Chat_A (t=100), Chat_B (t=90), Chat_C (t=80)]
                             ↑
              New message arrives in Chat_D → Chat_D.last_activity = t=95

Page 2 request: after?timestamp=80
Server returns:  [Chat_E (t=70), ...]  ← Chat_D (t=95) was missed
```

Fix (applied in API design above): server-issued opaque cursor instead of client-supplied timestamp. The server anchors the page boundary at query time — new inserts don't shift the anchor. The client stores the cursor and echoes it; never parses it.

```swift
struct PagedChatsResponse: Decodable {
    let chats: [ChatDTO]
    let nextCursor: String?   // nil = no more pages
}

// ViewModel stores cursor between scroll events
@MainActor
class ChatListViewModel: ObservableObject {
    private var nextCursor: String? = nil

    func loadNextPage() {
        guard let cursor = nextCursor else { return }
        // FetchChatsUseCase.execute(policy: .fresh, param: ChatListParam(cursor: cursor))
    }
}
```

**Why thread scroll-up keeps `before?timestamp=`:** Message threads are append-only at the tail — new messages arrive at the bottom, not interspersed with older ones. Scrolling up to see older messages visits positions that never reorder, so timestamp is stable here. The inconsistency risk only applies to live-sorting lists (chat list, social feed).

### ViewState Machine

Not a separate component — embedded in ViewModel:

```swift
enum ViewState<T> {
    case loading
    case success(T)
    case error(Error)
}

// ViewModel
@MainActor
class ChatThreadViewModel: ObservableObject {
    @Published var state: ViewState<[Message]> = .loading

    func load() {
        state = .loading                           // before UseCase call
        // ... UseCase call ...
        state = .success(messages)                 // on data received
        // on error:
        state = .error(error)
    }
}
```

The transition sequence: set `.loading` before calling UseCase → set `.success(data)` or `.error` after. All views in the app enforce this same lifecycle — no ad-hoc `isLoading: Bool` scattered per-screen.

---

## MVP Exclusions — Extension Notes

Features scoped out of MVP, with the minimal delta needed to add each.

### Push Notifications

- **New component:** `NotificationService` (app-scoped Domain Service) — registers APNS device token at login, stores token server-side
- **On tap:** `AppCoordinator` receives `chatId` from notification payload → pushes `ChatThreadViewController` directly, bypassing the chat list
- **Gap fill on cold launch:** tapping a PN may cold-launch the app — `MessageSyncService.syncPending()` + delta fetch must run before the thread renders
- **Scoping rule:** same as `MessageStreamService` — register at app startup, not inside a ViewController; if owned by a ViewModel it deallocates on screen pop and notifications go silent

### Typing Indicators

- **No data model change:** ephemeral — never persisted to `MessageLocalDataSource` or `ChatLocalDataSource`
- **Already reserved:** `WSEventType.typingIndicator` is commented out in the WebSocket event model — adding it is additive, no breaking change to existing clients
- **ViewModel state:** `@Published var isTypingVisible: Bool` — set `true` on incoming event, auto-clear after ~3 s via a cancellable `Task.sleep`
- **Sending:** debounce keypress in `ChatThreadViewModel` — fire WS event at most once per ~1 s to avoid flooding the socket with every keystroke

### Group Chats

- **Data model:** `Chat.users: [User]` already supports it — the array was intentional. No field change needed on `Chat`.
- **Read receipts:** `Message.readTime: Date?` becomes `Message.readReceipts: [ReadReceipt]` where `ReadReceipt = { userId, readTime }` — one entry per participant instead of a single timestamp
- **Send path:** unchanged on the client — `SendMessageUseCase` posts to the same endpoint; server handles fan-out to all group members
- **Pagination:** same three-tier strategy; endpoints gain a `groupId` param alongside (or replacing) `chatId`

---

## Interviewer Feedback

### Rating Pillars (4/5 across all)

**Problem Breakdown (4/5):** Strong requirements gathering. Defined scope clearly (1-to-1, offline-first, no push for MVP). Systematic plan of attack before drawing.

**System Architecture (4/5):**
- ✅ Layered approach (Presentation / Domain / Data)
- ✅ Repository pattern with local DB as SSOT
- ✅ Offline-first with `isSent` flag and background sync
- ❌ Did not address pagination inconsistency when new messages arrive during scroll
- ❌ Suggested POST for sends alongside WebSocket — redundant; prefer WebSocket-first

**Technical Proficiency (4/5):** Strong SwiftUI + Combine command. Clean `AnyPublisher` boundary between data layer and ViewModel. StateManager pattern is sound.

**Communication (4/5):** Discussed trade-offs clearly. Offered multiple options with pros/cons when challenged.

### Key Takeaways

- "Data orchestrator Coordinator" is an anti-pattern — Coordinator = navigation only. Split data orchestration into UseCase + Domain Service.
- The three-tier API strategy (initial / pagination / delta) is the right answer for any offline-first + real-time app.
- Route message sends through WebSocket-first; fall back to POST only when the socket is unavailable.
- Timestamp cursors are fragile for live data — default to server-issued opaque cursors.
- `MessageStreamService` and `MessageSyncService` must be app-scoped Domain Services, not ViewModel-owned components.
