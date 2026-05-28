# iOS Messenger App — System Design

**Source:** Mock Mobile System Design Interview — Andrey Tech (ex-Meta)

> Scenario extension of [`docs/ios-app-system-design-philosophy.md`](../ios-app-system-design-philosophy.md).
> Read the delta below first.

---

## Delta — What This Scenario Adds

### Same as generic architecture

All standard Clean Architecture + MVVM patterns as per the philosophy doc — not repeated here.

- Coordinator-based navigation, DI via manual init injection
- Idempotency keys on mutations — client-generated UUID at `Param` call site for any retryable mutation
- HTTP `409 ≠ 5xx` — concurrency conflicts and transient server errors must never share a code path
- Infrastructure layer (`Gateway` suffix) — Gateway trigger is cross-layer span, not SDK imports; single-layer SDKs wrap in their natural layer (DataSource or Service); **this scenario has no Gateway** — WebSocket is networking-transport only (no Presentation footprint) and wraps as `WebSocketClient` in Data, not as a Gateway
- External layer (outermost ring) — actual SDKs and OS frameworks; UIKit / SwiftUI / Combine need no wrapper (reactive/UI primitives used directly); all other SDKs always wrapped; wrapper placement scope-based: single-layer SDK → DataSource or Service, cross-layer SDK → Gateway in Infrastructure

### What this scenario adds

| Concept | Generic | This Scenario |
|---|---|---|
| Real-time data | Not covered | `MessageStreamService` Domain Service — calls `MessageStreamDataSourceProtocol`; `MessageStreamDataSource` wraps `WebSocketClient` in Data, exposes `AnyPublisher<Message, Never>` per chat |
| Offline write queue | Not covered | `MessageSyncService` Domain Service — queues `isSent = false` messages, flushes on app foreground; calls `MessageRepositoryProtocol.fetchPending()` |
| Three-tier API strategy | `FetchPolicy` covers read intent | Initial load / cursor pagination / delta sync by `sequenceId` — three distinct endpoints per list screen |
| Local DB as SSOT | `LocalDataSource` for cache | Realm via `LocalDataSource` — `ObserveMessagesUseCase` / `ObserveChatsUseCase` expose live query publishers; all state flows through DB writes |
| Optimistic send | Not covered | `StageMessageUseCase` (sync DB write → instant UI) + `SendMessageUseCase` (async network → confirmation write) |
| File/attachment storage | Not in generic | `AttachmentLocalFileDataSource` — stores media binaries; only URL stored in `MessageLocalDataSource` |
| Message status lifecycle | Not covered | `sentTime` / `receivedTime` / `readTime` + `isSent: Bool` for local delivery tracking |

### Key decisions unique to this scenario

- **`MessageStreamService` must be app-scoped.** If owned by `ChatThreadViewModel`, the WebSocket closes when the screen pops — incoming messages are silently missed.
- **`MessageSyncService` triggers on app lifecycle, not a timer.** Fires on `sceneDidBecomeActive` / `applicationDidBecomeActive`, not on a polling interval. Calls `messageRepository.fetchPending()` — never `MessageLocalDataSource` directly.
- **ViewModels map `Message` → `MessageUIModel`** (flat display struct); raw `Message` domain models are never passed to the View.
- **Local DB is the single source of truth.** ViewModels subscribe to `ObserveMessagesUseCase` / `ObserveChatsUseCase` (publishers); all state updates flow through DB writes — ViewModels never manually set state from UseCase return values.
- **Send uses two UseCases.** `StageMessageUseCase` writes the optimistic message to DB synchronously (publisher fires → UI updates instantly with `isSent: false`). `SendMessageUseCase` fires the network call async; on success it upserts the confirmed message to DB (publisher fires again → `isSent: true`).
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
    let url: URL                // URL only — binary stored in AttachmentLocalFileDataSource
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
      ObserveChatsUseCase · FetchChatsUseCase
  ChatThreadViewController     → ChatThreadViewModel
      ObserveMessagesUseCase · FetchMessagesUseCase
      StageMessageUseCase · SendMessageUseCase · MarkReadUseCase
      MessageStreamService (same app-scoped instance) · MessageSyncService

Domain
  UseCases (stateless):
    ObserveChatsUseCase        execute() → AnyPublisher<[Chat], Never>          → ChatRepositoryProtocol
    ObserveMessagesUseCase     execute(chatId:) → AnyPublisher<[Message], Never> → MessageRepositoryProtocol
    FetchChatsUseCase          execute(policy:param:) async throws → [Chat]      → ChatRepositoryProtocol
    FetchMessagesUseCase       execute(policy:param:) async throws → [Message]   → MessageRepositoryProtocol
    StageMessageUseCase        execute(param:) → Message                         → MessageRepositoryProtocol
    SendMessageUseCase         execute(param:) async throws → Message            → MessageRepositoryProtocol
    MarkReadUseCase            execute(param:) async throws                      → MessageRepositoryProtocol

  Domain Services (stateful / app-scoped):
    MessageStreamService       connect/disconnect · subscribe(chatId:) → AnyPublisher<Message, Never>
                               calls MessageStreamDataSourceProtocol — never touches WebSocket library directly
    MessageSyncService         syncPending() on foreground — flushes isSent=false messages
                               calls messageRepository.fetchPending() → [Message], then SendMessageUseCase per message

  Models:   Chat, Message, User, Attachment, ChatStatus, AttachmentType
  Params:   ChatListParam(), ChatParam(chatId:), StageMessageParam(chatId:, text:, localId:),
            SendMessageParam(chatId:, localId:), MarkReadParam(chatId:, messageIds:)

Data
  MessageRepository   : MessageRepositoryProtocol
    └─ MessageRemoteDataSource  → APIClient (three-tier REST endpoints)
    └─ MessageLocalDataSource   → Realm (SSOT — upsert by message.id)
    └─ MessageMapper

  ChatRepository      : ChatRepositoryProtocol
    └─ ChatRemoteDataSource     → APIClient (GET /chat/all with cursor)
    └─ ChatLocalDataSource      → Realm (live query exposed via ObserveChatsUseCase)
    └─ ChatMapper

  MessageStreamDataSource : MessageStreamDataSourceProtocol
    └─ WebSocketClient (connect / receive() → AsyncStream<Data> / disconnect)
    └─ decodes raw frames → MessageDTO; MessageStreamService calls via protocol, never the SDK directly

  WebSocketClient
    └─ wraps URLSessionWebSocketTask (or Starscream)
    └─ connect(to:) / send(_:) / receive() → AsyncStream<Data> / disconnect()
    └─ persistent-connection peer to APIClient — networking transport only, no Presentation footprint

  AttachmentLocalFileDataSource — binary files on disk; only URL stored in MessageLocalDataSource

Infrastructure
  None

External
  URLSessionWebSocketTask / Starscream
  Realm
  URLSession

Application
  AppCoordinator + ChatCoordinator (navigation only) + DI via manual init injection
  App-scoped singletons registered in AppCoordinator (or AppDelegate):
    - MessageStreamService — receives MessageStreamDataSource via init injection
    - MessageSyncService   — receives Realm-backed DataSources via init injection
  Neither service is owned by any ViewController or feature coordinator.
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
| `File Storage` | `AttachmentLocalFileDataSource` | Data |

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

AttachmentLocalFileDataSource — stores attachment binaries, referenced by URL in Message model
```

---

## Data Flow

### Load Chat Thread (offline-first)

ViewModel subscribes to `ObserveMessagesUseCase` once — all state updates (cache, network, WebSocket) flow through this single reactive pipe via DB writes. `FetchMessagesUseCase` triggers the network call; its DB write fires the observer.

```
ChatThreadViewController.viewDidLoad()
  → ChatThreadViewModel.load()
      state = .loading

      // Subscribe once — single state update path for all sources
      ObserveMessagesUseCase.execute(chatId:) → AnyPublisher<[Message], Never>
          → MessageRepository.observe(chatId:) wraps Realm live query
          → emits immediately with cached messages if present → state = .success(cached)
          → re-emits on every subsequent DB write (network fetch, WebSocket upsert)
          → ViewModel maps [Message] → UIModel on each emission

      // Trigger network fetch — DB write fires the observer above
      Task:
        try await FetchMessagesUseCase.execute(policy: .fresh, param: ChatParam(chatId:))
            → MessageRepository.fetchMessages(policy: .fresh, chatId:)
                → MessageRemoteDataSource.fetch() → [MessageDTO] → MessageMapper → [Message]
                → MessageLocalDataSource.upsert(messages)    // DB write → observer emits → state updated

      defer: isLoading = false

      // WebSocket — each incoming frame also writes to DB → observer emits → state updated
      → MessageStreamService.subscribe(chatId:) → AnyPublisher<Message, Never>
          → MessageRepository.receiveMessage(dto:)
              → MessageLocalDataSource.upsert(dto)    // upsert by message.id
              → observer emits → state updated (same pipe as above)
```

### Send Message (with offline queue)

Two UseCases — stage is synchronous for instant UI; send is async for the network call. Both write to DB; the `ObserveMessagesUseCase` publisher drives all state updates.

```
User taps send
  → ChatThreadViewModel.send(text:)

      // UseCase 1 — sync, instant DB write → observer fires → UI shows isSent: false immediately
      StageMessageUseCase.execute(param: StageMessageParam(chatId:, text:, localId: UUID()))
          → MessageRepository.save(Message(id: localId, text: text, isSent: false, ...))
              → MessageLocalDataSource.upsert(...)    // DB write → observer emits → state updated

      // UseCase 2 — async, fires in background
      Task:
        try await SendMessageUseCase.execute(param: SendMessageParam(chatId:, localId:))
            → MessageRepository.sendMessage(param:)
                → MessageRemoteDataSource.post(/chat/{chat_id}/message)
                → on success: MessageLocalDataSource.upsert(confirmed)  // DB write → observer emits → isSent: true
                → on failure: isSent remains false → MessageSyncService will retry on next foreground
```

The ViewModel never manually sets state. `StageMessageUseCase` owns the optimistic DB write; `SendMessageUseCase` owns the network call and confirmation write — ViewModel never touches Repository or DataSource directly.

### Background Sync (MessageSyncService)

`MessageSyncService` is a Domain Service — it calls via `MessageRepositoryProtocol`, never `MessageLocalDataSource` directly.

```
sceneDidBecomeActive / applicationDidBecomeActive
  → MessageSyncService.syncPending()
      → MessageRepositoryProtocol.fetchPending() → [Message]  // isSent == false
      → for each: SendMessageUseCase.execute(param: SendMessageParam(chatId:, localId: message.id))
          → MessageRepository.sendMessage(param:)
              → MessageRemoteDataSource.post(...)
              → on success: MessageLocalDataSource.upsert(confirmed)  // DB write → observer emits → isSent: true
              → on failure: leave for next foreground event
```

### Load Chat List (offline-first)

Same pattern as Load Chat Thread — subscribe once, trigger fetch. Observer emits cached data immediately if present; network fetch DB write re-emits with fresh data.

```
ChatListViewController.viewDidLoad()
  → ChatListViewModel.load()
      state = .loading

      // Subscribe once — single state update path
      ObserveChatsUseCase.execute() → AnyPublisher<[Chat], Never>
          → ChatRepository.observe() wraps Realm live query
          → emits immediately with cached chats if present → state = .success(cached)
          → re-emits on every subsequent DB write, sorted by lastActivity
          → ViewModel maps [Chat] → UIModel on each emission

      // Trigger network fetch — DB write fires the observer above
      Task:
        let response = try await FetchChatsUseCase.execute(policy: .fresh, param: ChatListParam())
            → ChatRepository.fetchChats(policy: .fresh)
                → ChatRemoteDataSource.fetch()              // GET /chat/all
                → PagedChatsResponse { chats: [ChatDTO], nextCursor: String? }
                → ChatLocalDataSource.upsert(dtos)          // DB write → observer emits → state updated
            ← returns PagedChatsResponse
        → nextCursor = response.nextCursor

      defer: isLoading = false
```

### Chat List Scroll Pagination (cursor-based)

```
User scrolls to bottom of chat list
  → ChatListViewModel.loadNextPage()
      guard let cursor = nextCursor else { return }   // nil = no more pages
      let response = try await FetchChatsUseCase.execute(policy: .fresh, param: ChatListParam(cursor: cursor))
          → ChatRepository.fetchChats(policy: .fresh, cursor: cursor)
              → ChatRemoteDataSource.fetch()               // GET /chat/all?cursor=<cursor>
              → PagedChatsResponse { chats: [ChatDTO], nextCursor: String? }
              → ChatLocalDataSource.upsert(dtos)
          ← returns PagedChatsResponse
      → nextCursor = response.nextCursor    // nil = end of list reached
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

      2. For each open / recently-visited chatId (use withThrowingTaskGroup for concurrent calls):
         withThrowingTaskGroup: one FetchMessagesUseCase call per chatId, all concurrent
         FetchMessagesUseCase.execute(policy: .fresh,
             param: MessageParam(chatId:, after: lastKnownTimestamp))
             → MessageRepository.fetchMessages(policy: .fresh, chatId:, after: lastKnownTimestamp)
                 → MessageRemoteDataSource.fetch()    // GET /chat/{id}/all/after?timestamp=lastKnown
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
          → MessageRepository.fetchMessages(policy: .fresh, chatId:, before: oldestTimestamp)
              → MessageRemoteDataSource.fetch()            // GET /chat/{id}/all/before?timestamp=
              → [MessageDTO] → MessageMapper.toDomain() → [Message]
              → MessageLocalDataSource.upsert(messages)        // persist for future offline access
          ← returns [Message]
      → state prepended with older messages

Note: timestamp is stable here — message threads are append-only at the tail.
      New messages arrive at the bottom; older messages never reorder.
```

### Mark as Read

`MarkReadUseCase` owns the full flow — optimistic DB write and network call. ViewModel calls one UseCase; state updates reactively through the observer.

```
User opens ChatThread (or scrolls to bottom, viewing latest messages)
  → ChatThreadViewModel.markAsRead(visibleMessageIds: [...])
      → MarkReadUseCase.execute(param: MarkReadParam(chatId:, messageIds:))
          → MessageRepository.markRead(param:)
              // Optimistic — DB write → MessageLocalDataSource observer emits → read tick appears instantly
              → MessageLocalDataSource.update(ids:, readTime: Date())
              // Network
              → MessageRemoteDataSource.patch(/chat/{chat_id}/read)
              → on success: server confirmed — local state already correct
              → on failure: readTime remains set locally; reconcile on next delta sync
          → ChatRepository.updateStatus(chatId:, status: .read)
              // DB write → ChatLocalDataSource observer emits → unread indicator clears
              → ChatLocalDataSource.update(chatId:, status: .read)
```

---

## Deep Dives

### WebSocket Lifecycle

`MessageStreamService` is a Domain Service (app-scoped singleton):

```swift
class MessageStreamService {
    private let streamDataSource: MessageStreamDataSourceProtocol   // Data — injected via DI
    private let messageRepository: MessageRepositoryProtocol        // Domain protocol — not the concrete MessageRepository

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

The ViewModel subscribes to both `ObserveMessagesUseCase` and `MessageStreamService` — both feed the same `@Published var state: ViewState<[Message]>`.

### Three-Tier REST vs FetchPolicy

`FetchPolicy` covers read intent (.fresh / .cached / .strict) but doesn't model delta sync. Three-tier maps onto FetchPolicy as:

| Tier | Endpoint | FetchPolicy analog |
|---|---|---|
| Initial load | `GET /chat/{id}/all` | `.strict` (phase 1, cache-only, throws on miss) + `.fresh` (phase 2, always network) |
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
- **On tap:** Push notification tap → `NotificationCenter.post(.handleDeepLink, object: chatId)` → `AppCoordinator.handle(link:)` → selects tab, delegates to `ChatCoordinator` → creates `ChatThreadViewModel + ChatThreadViewController` and pushes
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
