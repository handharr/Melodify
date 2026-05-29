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
| Image loading | Not covered | `ImageService` Domain Service — wraps `ImageDataSource` (SDWebImage); memory + disk two-level cache; lazy loaded per cell appearance, never eagerly on thread open |
| File/attachment download | Not covered | `FileService` Domain Service — `download(url:) async throws -> URL`; checks `AttachmentLocalFileDataSource` first, fetches via `AttachmentRemoteDataSource` on miss, stores to disk, returns local URL |

### Key decisions unique to this scenario

- **`MessageStreamService` must be app-scoped.** If owned by `ChatThreadViewModel`, the WebSocket closes when the screen pops — incoming messages are silently missed.
- **`MessageSyncService` triggers on app lifecycle, not a timer.** Fires on `sceneDidBecomeActive` / `applicationDidBecomeActive`, not on a polling interval. Calls `messageRepository.fetchPending()` — never `MessageLocalDataSource` directly.
- **ViewModels map `Message` → `MessageUIModel`** (flat display struct); raw `Message` domain models are never passed to the View.
- **Local DB is the single source of truth.** ViewModels subscribe to `ObserveMessagesUseCase` / `ObserveChatsUseCase` (publishers); all state updates flow through DB writes — ViewModels never manually set state from UseCase return values.
- **Send uses two UseCases.** `StageMessageUseCase` writes the optimistic message to DB synchronously (publisher fires → UI updates instantly with `isSent: false`). `SendMessageUseCase` fires the network call async; on success it upserts the confirmed message to DB (publisher fires again → `isSent: true`).
- **Three-tier REST is required alongside FetchPolicy.** FetchPolicy (`.fresh` / `.cached`) covers read intent but doesn't model delta sync — fetching only records changed since a known `sequenceId` is a separate concern.
- **Upsert by `message.id`, never append.** A message can arrive via both WebSocket and a delta REST sync. Appending would duplicate it; upserting by `id` is idempotent.
- **Single WebSocket connection for all chats.** `connect()` opens one socket to `WS /events`, then reads all known chatIds from `ChatRepositoryProtocol` (local Realm read — no network call) and sends a subscribe frame per chatId. `subscribe(chatId:)` returns a filtered publisher on the single stream — it never opens a new socket. On reconnect (app foreground), re-send subscribe frames for cached chatIds immediately (optimistic), then call `refreshSubscriptions()` after the delta sync completes to cover any newly discovered chats.
- **Images lazy loaded per cell, never eagerly on thread open.** `ImageService.load(url:, size:)` is called as each cell scrolls into viewport — not when the thread loads. `ImageDataSource` is the only caller of SDWebImage. Thumbnail shown inline; full-res loaded only on tap.
- **`FileService` checks disk before network.** `AttachmentLocalFileDataSource` is always the first lookup. Network fetch via `AttachmentRemoteDataSource` only on full cache miss. ViewModel receives a local `URL` — never a raw binary.
- **Delta sync on foreground, not full chat list refetch.** `GET /chat/all/delta?sequenceId=<lastKnown>` returns only chats changed since the last sync — payload is proportional to activity, not list size. `sequenceId` is persisted in `UserDefaults` after every successful sync. Full `GET /chat/all` (paginated) is used only on first cold launch when no `sequenceId` exists yet.

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

### Strategy Bridge

State the technical strategy for each requirement before drawing any boxes. This is how you pre-motivate every component in the architecture.

| Requirement | Strategy | Key terms |
|---|---|---|
| Offline-first | Local DB as SSOT — Realm **live queries** fire on every write; ViewModel subscribes once, never polls | live queries, observable, SSOT |
| Real-time | Single multiplexed WebSocket (`WS /events`) — **subscribe frames** per chatId on connect; `subscribe(chatId:)` returns a filtered publisher, never opens a new socket | single socket, subscribe frame, filtered publisher |
| Battery / bandwidth | **Delta sync** via `sequenceId` on foreground — payload proportional to activity, not list size; no polling timer | delta sync, sequenceId, proportional payload |
| Offline send queue | `isSent: Bool` **sync flag** on `Message` — staged optimistically by `StageMessageUseCase`, flushed by `MessageSyncService` on `sceneDidBecomeActive` | isSent flag, optimistic stage, foreground flush |
| Media — images | Two-level cache (memory → disk) via SDWebImage; **lazy loaded per cell**, never eagerly on thread open | two-level cache, lazy load, never eager |
| Media — files | **Disk-first** lookup — `AttachmentLocalFileDataSource` checked before any network call; ViewModel receives a local `URL`, never a raw binary | disk-first, local URL, cache miss fallback |

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
  WS   /events                                → single multiplexed stream; client sends subscribe frames per chatId after connect
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
    MessageStreamService       connect() opens WS /events + sends subscribe frames for all known chatIds (via ChatRepositoryProtocol)
                               subscribe(chatId:) → AnyPublisher<Message, Never> — filtered publisher, no new socket
                               disconnect() — calls MessageStreamDataSourceProtocol — never touches WebSocket library directly
    MessageSyncService         syncPending() on foreground — flushes isSent=false messages
                               calls messageRepository.fetchPending() → [Message], then SendMessageUseCase per message
    ImageService               load(url:, size: .thumbnail | .fullRes) → AnyPublisher<UIImage, Error>
                               calls ImageDataSource (wraps SDWebImage) — memory cache → disk cache → network fetch
                               lazy: called per cell appearance, never eagerly on thread open
    FileService                download(url:) async throws -> URL — returns local file URL
                               checks AttachmentLocalFileDataSource first; fetches via AttachmentRemoteDataSource on miss
                               stores binary to AttachmentLocalFileDataSource, returns local URL

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
  AttachmentRemoteDataSource    — fetches attachment binaries from network (used by FileService on cache miss)
  ImageDataSource               — wraps SDWebImage; exposes load(url:) → AnyPublisher<UIImage, Error>
                                  SDWebImage handles memory (NSCache) + disk cache internally

Infrastructure
  None

External
  URLSessionWebSocketTask / Starscream
  Realm
  URLSession
  SDWebImage

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

      // Images — lazy loaded per cell, never eagerly on thread open
      // Each cell calls ImageService as it scrolls into viewport:
      //   ImageService.load(url: message.attachment.url, size: .thumbnail)
      //       → ImageDataSource (SDWebImage): memory cache → disk cache → network fetch
      // Full-res loaded only on user tap, not on thread open.

      // WebSocket — each incoming frame also writes to DB → observer emits → state updated
      → MessageStreamService.subscribe(chatId:) → AnyPublisher<Message, Never>
          → MessageRepository.receiveMessage(dto:)
              → MessageLocalDataSource.upsert(dto)    // upsert by message.id
              → observer emits → state updated (same pipe as above)
```

### Send Message (with offline queue)

Two UseCases — stage is synchronous for instant UI; send is async. Send is **WebSocket-first**: goes over the socket when live, falls back to REST only when unavailable.

```
User taps send
  → ChatThreadViewModel.send(text:)

      // UseCase 1 — sync, instant DB write → observer fires → UI shows isSent: false immediately
      StageMessageUseCase.execute(param: StageMessageParam(chatId:, text:, localId: UUID()))
          → MessageRepository.save(Message(id: localId, text: text, isSent: false, ...))
              → MessageLocalDataSource.upsert(...)    // DB write → observer emits → state updated

      // UseCase 2 — async, WebSocket-first
      Task:
        try await SendMessageUseCase.execute(param: SendMessageParam(chatId:, localId:))
            → MessageRepository.sendMessage(param:)

                if socket is live:
                  MessageStreamDataSource.send(WSEvent<MessageSendDTO>)
                      → wire: { "type": "message_send", "payload": { chatId, text, localId } }
                  await confirmation frame { type: .messageSent, payload: confirmedMessageDTO }
                  MessageLocalDataSource.upsert(confirmed)   // localId → serverId, isSent: true

                if socket is unavailable:
                  MessageRemoteDataSource.post(/chat/{chat_id}/message)  // REST fallback
                  MessageLocalDataSource.upsert(confirmed)   // isSent: true

                on failure either way:
                  isSent remains false → MessageSyncService retries on next foreground
```

The ViewModel never manually sets state. `StageMessageUseCase` owns the optimistic DB write; `SendMessageUseCase` owns the send path and confirmation write.

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

**Why cursor here — not timestamp, not sequenceId.** The chat list is sorted by `last_activity` descending — a live-sorted list. Between page 1 and page 2, a new message in Chat_D moves it to the top. A `timestamp` anchor would skip it. A `sequenceId` is an event counter — it tracks global server writes, not your position in a ranked list. An opaque cursor, issued by the server at page 1 time, anchors the snapshot: page 2 always continues from where page 1 stopped, regardless of new arrivals.

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
         → opens WS /events
         → reads chatIds from ChatLocalDataSource (Realm, local-only — instant)
         → sends subscribe frames for all cached chatIds   // optimistic coverage

      // sequenceId here is NOT a pagination cursor.
      // It's an event counter: "give me everything that changed since server event N."
      // The question is not "where am I in a ranked list?" but "what happened while I was gone?"
      2. GET /chat/all/delta?sequenceId=<lastKnown>        // NOT full /chat/all — proportional to activity
         → FetchChatsUseCase.execute(policy: .fresh, param: ChatListParam(sequenceId: lastKnown))
             → ChatRemoteDataSource.fetch()
             → upserts new/changed chats into ChatLocalDataSource
             → persists new sequenceId to UserDefaults
         → MessageStreamService.refreshSubscriptions()
             → sends subscribe frames for any newly discovered chatIds

      3. withThrowingTaskGroup: one FetchMessagesUseCase call per chatId, all concurrent
         FetchMessagesUseCase.execute(policy: .fresh,
             param: MessageParam(chatId:, after: lastKnownTimestamp))
             → MessageRemoteDataSource.fetch()    // GET /chat/{id}/all/after?timestamp=lastKnown
             → MessageLocalDataSource.upsert(dtos)        // fill gap from background period

      4. MessageSyncService.syncPending()
         → fetch isSent == false → retry sends

Order matters: reconnect + subscribe → delta chat sync → message gap fill → pending sends.
Step 1 chatId reads are local-only (Realm). Full GET /chat/all is only used on first cold launch
when no sequenceId exists in UserDefaults yet.
```

### Chat Thread Scroll Pagination (scroll up for older messages)

**Why timestamp here — not cursor.** Message threads are append-only at the tail: new messages always arrive at the bottom. When scrolling up to see older messages, the oldest visible `sentTime` is a stable anchor — nothing will ever insert itself above it, so the "gap shift" problem that breaks timestamp pagination on the chat list simply cannot occur here. Cursor overhead is unnecessary for a sequence that never reorders.

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

### Load Image (lazy, per cell)

```
Cell scrolls into viewport
  → ChatThreadViewModel.loadImage(url:, size: .thumbnail)
      → ImageService.load(url:, size:) → AnyPublisher<UIImage, Error>
          → ImageDataSource (SDWebImage):
              1. memory cache (NSCache) hit → return immediately
              2. disk cache hit → return, promote to memory cache
              3. miss → network fetch → store to disk + memory → return
          → cell renders image on emission

User taps attachment to expand
  → ChatThreadViewModel.loadImage(url:, size: .fullRes)
      → same ImageService.load() call with .fullRes URL
```

### Download File Attachment

```
User taps file attachment (PDF, video)
  → ChatThreadViewModel.downloadAttachment(attachment:)
      → FileService.download(url: attachment.url) async throws -> URL
          1. AttachmentLocalFileDataSource.localURL(for: attachment.url)
             → file exists on disk → return local URL immediately
          2. miss → AttachmentRemoteDataSource.fetch(url:) → Data
             → AttachmentLocalFileDataSource.store(data:, for: attachment.url)
             → return local URL
      → ViewModel receives local URL → opens file (QuickLook / AVPlayer)
```

---

## Deep Dives

### Local DB as SSOT: Observe vs Fetch

The architecture has two kinds of UseCases and they serve completely different purposes. Mixing them up is the most common source of confusion.

| UseCase | Type | ViewModel's job |
|---|---|---|
| `ObserveMessagesUseCase` | Returns a persistent `AnyPublisher<[Message], Never>` — keeps emitting on every DB write | **Subscribe once in `viewDidLoad`. Hold the cancellable for the ViewModel's lifetime. Never call again.** |
| `FetchMessagesUseCase` | One-shot `async throws` — fetches from network, writes to DB, returns | **Call to trigger a refresh. Ignore the return value — the observer handles the state update.** |

The ViewModel never sets `state` from `FetchMessagesUseCase`'s return value. It triggers the fetch, the fetch writes to DB, the DB write fires the observer the ViewModel already subscribed to. State always arrives through the same single pipe.

#### Subscription chain

```
ViewModel
  └── subscribes once to ObserveMessagesUseCase.execute(chatId:)
           └── calls MessageRepository.observe(chatId:)
                    └── wraps MessageLocalDataSource — Realm notification token
                             └── fires on ANY write to matching Message objects
```

The publisher never completes. It keeps emitting a fresh `[Message]` every time anything writes to `MessageLocalDataSource` — regardless of which source triggered the write.

#### Every writer fires the same observer

```
REST fetch completes     → MessageLocalDataSource.upsert() → Realm fires → ObserveUseCase emits → state updated
WebSocket frame arrives  → MessageLocalDataSource.upsert() → Realm fires → ObserveUseCase emits → state updated
Optimistic send          → MessageLocalDataSource.upsert() → Realm fires → ObserveUseCase emits → state updated
Delta sync on foreground → MessageLocalDataSource.upsert() → Realm fires → ObserveUseCase emits → state updated
```

The ViewModel doesn't know which source triggered the emission. It just receives the latest `[Message]` and maps it to `[MessageUIModel]`.

#### The notification delivers data — not a signal

This is the key property of Realm live queries. When the token fires, the updated data is already inside the callback. There is no second fetch.

```swift
// Inside MessageLocalDataSource
func observe(chatId: String) -> AnyPublisher<[MessageObject], Never> {
    let realm = try! Realm()
    let results = realm.objects(MessageObject.self)
                       .filter("chatId == %@", chatId)  // live, auto-updating collection
                                                         // chatId filter is baked in here — never changes

    return Publishers.create { subscriber in
        let token = results.observe { changes in
            switch changes {
            case .initial(let objects):    // fires immediately with current DB state
                subscriber.send(Array(objects))
            case .update(let objects, ...):  // fires on every write — objects already updated
                subscriber.send(Array(objects))
            }
        }
        return AnyCancellable { token.invalidate() }
    }
}
```

`results` is a live collection — Realm updates it atomically when a write transaction commits, then fires the notification with the already-updated objects inside. The chatId filter is set once at query creation and never re-evaluated — Realm only fires the token when a `MessageObject` with that `chatId` changes. Writes to other chatIds are invisible to this subscriber.

#### Write-to-UI chain (one atomic step)

```
MessageLocalDataSource.upsert(message)         ← write transaction commits
  → Realm updates Results<MessageObject> in memory
  → notification token fires with updated objects already inside
  → publisher emits [MessageObject]
  → MessageMapper.toDomain() → [Message]
  → ViewModel .sink receives [MessageUIModel]
  → state = .success(uiModels)                 ← UI updates
```

No polling, no second query, no manual "now go load."

#### Concrete ViewModel

```swift
@MainActor
class ChatThreadViewModel: ObservableObject {
    @Published var state: ViewState<[MessageUIModel]> = .loading

    private var observeCancellable: AnyCancellable?

    func load(chatId: String) {
        state = .loading

        // Subscribe ONCE — lives until ViewModel deallocates
        observeCancellable = observeMessagesUseCase
            .execute(chatId: chatId)               // AnyPublisher<[Message], Never>
            .map { messages in messages.map(MessageUIModel.init) }
            .sink { [weak self] uiModels in
                self?.state = .success(uiModels)   // every DB write ends up here
            }

        // Trigger network fetch — its DB write fires the observer above
        Task {
            try? await fetchMessagesUseCase.execute(policy: .fresh, param: ChatParam(chatId: chatId))
            // return value intentionally ignored — observer handles state
        }
    }
}
```

`observeCancellable` is what's "subscribed." `FetchMessagesUseCase` is just a trigger — its only job is to write to the DB.

---

### WebSocket Lifecycle

#### WebSocket is bidirectional — both directions matter

WebSocket gives you a raw full-duplex byte stream. The app both sends and receives over the same connection.

| Direction | What | When |
|---|---|---|
| Client → Server | Subscribe frame | On every connect/reconnect — tells server which chatIds to fan out |
| Client → Server | Message send frame | Every send when socket is live (WebSocket-first) |
| Client → Server | Future: typing indicator | On keypress (debounced ~1s) |
| Server → Client | `messageReceived` | Incoming message from other user |
| Server → Client | `messageSent` confirmation | Ack after client sends a message frame |
| Server → Client | Future: `typingIndicator` | Other user is typing |

#### MessageStreamDataSourceProtocol — both directions

```swift
protocol MessageStreamDataSourceProtocol {
    func connect(to url: URL)
    func send(_ event: Encodable) async throws    // outgoing — subscribe frames + message sends
    func receive() -> AsyncStream<Data>           // incoming — all server-pushed events
    func disconnect()
}
```

`WebSocketClient` is not just a receiver — `send()` is how subscribe frames and message sends travel to the server.

#### MessageStreamService

```swift
class MessageStreamService {
    private let streamDataSource: MessageStreamDataSourceProtocol   // Data — injected via DI
    private let messageRepository: MessageRepositoryProtocol
    private let chatRepository: ChatRepositoryProtocol

    func connect()    // opens socket + sends subscribe frames for all known chatIds
    func send(_ event: Encodable) async throws   // routes outgoing frames (message sends, future typing)
    func subscribe(to chatId: String) -> AnyPublisher<Message, Never>  // filtered publisher — no new socket
    func disconnect()
}
```

#### Lifecycle

1. App foreground → `AppCoordinator` calls `messageStreamService.connect()`
2. `connect()` opens one socket to `WS /events`, reads all cached chatIds from `ChatLocalDataSource` (local Realm read, no network), **sends subscribe frames** — chat list gets real-time updates before any thread is opened
3. `GET /chat/all/delta?sequenceId=` completes → `refreshSubscriptions()` sends frames for any newly discovered chatIds
4. View appears → ViewModel calls `messageStreamService.subscribe(to: chatId)` — attaches a filtered `AnyPublisher` on the already-active stream; cancels on `viewWillDisappear`
5. User sends message → `SendMessageUseCase` calls `messageStreamService.send(WSEvent<MessageSendDTO>)` — awaits `messageSent` confirmation frame
6. App backgrounds → `messageStreamService.disconnect()` (socket closed to save battery)
7. App foregrounds → repeat from step 1

**Why not one socket per chat?** One `URLSessionWebSocketTask` per chat would multiply TCP connections by N — battery and socket overhead with no benefit. A single multiplexed connection carries all chats; the per-chatId filter in `subscribe(chatId:)` is just a publisher `.filter` on the client side.

---

### Typing Indicators — Low-Level WebSocket Detail

#### Wire frames

**Client → Server (user is typing):**
```json
{ "type": "typing_indicator", "payload": { "chatId": "abc123", "userId": "user456" } }
```

**Server → other participant:**
```json
{ "type": "typing_indicator", "payload": { "chatId": "abc123", "userId": "user456" } }
```

Server fans it out immediately. Never written to DB — ephemeral by design. No `MessageLocalDataSource` involved.

#### WebSocket frame anatomy (RFC 6455)

```
Byte 0:   FIN=1  RSV=0  opcode=0x1  (text frame — JSON payload)
Byte 1:   MASK=1  payload_len=N
Bytes 2-5: masking key (4 random bytes, client→server only)
Bytes 6+:  masked payload (each byte XOR'd with masking key)
```

Three rules to know:
- **Client→Server frames MUST be masked** — RFC 6455 requirement. `URLSessionWebSocketTask` handles this automatically.
- **Server→Client frames are NOT masked** — reverse direction, no masking.
- **Text (0x1) vs Binary (0x2)** — JSON uses text frames. Protobuf/MessagePack use binary — smaller payload, faster decode. Start with JSON, migrate to binary at scale.

`URLSessionWebSocketTask` exposes both cleanly:

```swift
// Sending
try await task.send(.string(jsonString))   // text frame — opcode 0x1
try await task.send(.data(binaryData))     // binary frame — opcode 0x2

// Receiving
let message = try await task.receive()
switch message {
case .string(let json):  // decode JSON
case .data(let bytes):   // decode binary
}
```

#### Ping / Pong — keepalive

WebSocket has built-in ping (opcode `0x9`) / pong (`0xA`) frames. Server sends a ping; client must respond with pong — if it doesn't within the timeout, server closes the connection.

`URLSessionWebSocketTask` responds to pongs automatically. You can send manual pings to detect a dead connection faster than waiting for a TCP timeout:

```swift
task.sendPing { error in
    if error != nil {
        // connection dead — trigger MessageStreamService reconnect
    }
}
```

#### Debounce — why it matters at scale

Without debounce, every keystroke fires a frame:

```
"h" → frame  "e" → frame  "l" → frame  "l" → frame  "o" → frame
```

At scale: **1M concurrent typing users × 5 keystrokes/sec = 5M frames/sec** hitting the server. The debounce caps it at 1 frame/sec per user regardless of typing speed.

```swift
// ChatThreadViewModel
private var typingDebounceTask: Task<Void, Never>?

func userDidType() {
    typingDebounceTask?.cancel()                       // reset on every keystroke
    typingDebounceTask = Task {
        try? await Task.sleep(for: .seconds(1))        // 1s of silence before firing
        guard !Task.isCancelled else { return }
        await messageStreamService.send(
            WSEvent(type: .typingIndicator, payload: TypingDTO(chatId: chatId))
        )
    }
}
```

#### Stop-typing detection — two approaches

**Option A: explicit `typingStop` frame** — client sends `{ "type": "typing_stop" }` when the user stops or sends the message.

**Option B: server TTL (used here)** — if no new `typingIndicator` frame arrives within 3s, server stops fanning out. No extra frame type needed. The ViewModel mirrors this with a matching 3s auto-clear:

```swift
// ChatThreadViewModel
@Published var isTypingVisible = false
private var typingTimeoutTask: Task<Void, Never>?

func handleTypingEvent() {
    isTypingVisible = true
    typingTimeoutTask?.cancel()
    typingTimeoutTask = Task {
        try? await Task.sleep(for: .seconds(3))
        guard !Task.isCancelled else { return }
        isTypingVisible = false
    }
}
```

The 3s timeout on the ViewModel matches the server TTL — if frames stop arriving, both sides clear independently without any coordination.

#### Full flow

```
User types a character
  → ChatThreadViewModel.userDidType()
      → typingDebounceTask.cancel() + restart 1s timer

1 second of silence
  → debounce fires
  → messageStreamService.send(WSEvent<TypingDTO>)
      → MessageStreamDataSource.send() → WebSocketClient.send(.string(json))
      → wire: masked text frame (opcode 0x1) → server

Server receives frame
  → fans out { type: "typing_indicator" } to other participant's socket (no DB write)

Other participant's MessageStreamService receives frame
  → WebSocketClient.receive() → AsyncStream<Data> emits
  → MessageStreamDataSource decodes → WSEvent<TypingDTO>
  → typingSubject.send(dto)
  → ChatThreadViewModel.handleTypingEvent()
      → isTypingVisible = true
      → 3s auto-clear timer resets

3s with no new frame
  → ViewModel timer fires → isTypingVisible = false
  → server TTL expires → stops fanning out
  (both sides clear independently, no coordination needed)
```

### Three-Tier REST vs FetchPolicy

`FetchPolicy` covers read intent (.fresh / .cached / .strict) but doesn't model delta sync. Three-tier maps onto FetchPolicy as:

| Tier | Endpoint | FetchPolicy analog |
|---|---|---|
| Initial load | `GET /chat/{id}/all` | `.strict` (phase 1, cache-only, throws on miss) + `.fresh` (phase 2, always network) |
| Cursor pagination | `GET .../before?timestamp=` | `.fresh` — always hits network for older pages |
| Delta sync | `GET .../delta/after?sequenceId=` | No analog — payload is change-proportional, not list-proportional |

Delta sync is the battery-efficiency win: instead of re-fetching 50 messages, fetch only the 3 that arrived while the app was in the background.

### Pagination: Three Mechanisms, Three Jobs

Quick decision guide — pick the right tool for each flow:

| Mechanism | Used when | Example in this design |
|---|---|---|
| **Opaque cursor** | Browsing a live-sorted list — inserts can shift positions between pages | Chat list scroll: `GET /chat/all?cursor=<cursor>` |
| **`before?timestamp=`** | Paging through an append-only sequence — nothing ever reorders | Thread scroll-up: `GET /chat/{id}/all/before?timestamp=` |
| **`sequenceId`** | Fetching everything that *changed* since a known server event — not a position in a list | Gap recovery: `GET /chat/all/delta?sequenceId=<lastKnown>` |

---

**The core confusion: cursor vs sequenceId look identical on the wire (both are opaque strings), but they answer different questions.**

- Cursor answers: *"where am I in this ranked list?"*
- sequenceId answers: *"what happened on the server since event N?"*

---

#### Why cursor for chat list scroll (not timestamp, not sequenceId)

The chat list is sorted by `last_activity` descending. Between page 1 and page 2, a new message arrives in Chat_D and it jumps to the top of the list. A `timestamp` anchor of `t=80` asks the server "give me chats with `last_activity < 80`" — Chat_D at `t=95` is silently skipped.

```
Chat list, Page 1: [Chat_A (t=100), Chat_B (t=90), Chat_C (t=80)]
                             ↑
              New message arrives in Chat_D → Chat_D.last_activity = t=95

Page 2 request with timestamp anchor: last_activity < 80
Server returns:  [Chat_E (t=70), ...]  ← Chat_D (t=95) was missed
```

A `sequenceId` doesn't help here either — it tracks the global order of server-side writes, not your position in a list sorted by `last_activity`. The two sort orders aren't the same.

An **opaque server-issued cursor** anchors the snapshot at page 1 query time. The server records "this cursor = after Chat_C in the snapshot I took when you fetched page 1." New inserts between pages don't shift that anchor. The client stores the cursor and echoes it; never parses it.

```swift
struct PagedChatsResponse: Decodable {
    let chats: [ChatDTO]
    let nextCursor: String?   // nil = no more pages
}

@MainActor
class ChatListViewModel: ObservableObject {
    private var nextCursor: String? = nil

    func loadNextPage() {
        guard let cursor = nextCursor else { return }
        // FetchChatsUseCase.execute(policy: .fresh, param: ChatListParam(cursor: cursor))
    }
}
```

#### Why timestamp for thread scroll-up (not cursor)

Message threads are append-only at the tail — new messages always arrive at the bottom. When you scroll up to see older messages, the oldest visible `sentTime` is a stable anchor: nothing will ever insert itself above it. The "gap shift" problem cannot occur here because positions never reorder. Cursor overhead is unnecessary.

#### Why sequenceId for gap recovery (not cursor, not timestamp)

`GET /chat/all/delta?sequenceId=<lastKnown>` is not paginating a list — it is asking "what changed on the server since event N?" The server maintains a monotonically increasing counter; every write increments it. The client persists the last seen value and echoes it on foreground. The response payload is proportional to activity during the background period, not to list size — fetching 3 changed chats instead of the full 15-item first page.

### Real-time Transport: WebSocket vs Alternatives

Before picking WebSocket, the realistic alternatives and why each was ruled out:

| Option | Mechanism | Verdict |
|---|---|---|
| Long Polling | Client holds open HTTP request; server responds on event or timeout, then client immediately re-requests | ❌ Ruled out |
| Server-Sent Events (SSE) | Server pushes events over a persistent HTTP/2 stream (one direction only) | ❌ Ruled out |
| WebSocket | Full-duplex TCP after HTTP upgrade handshake; both sides send frames at will | ✅ Chosen |
| APNS only | OS-level push notifications | ❌ Complements, does not replace |

**Long polling — why ruled out:**
- Every message delivery = a full HTTP round-trip (request headers, response headers, TCP ACK). 200–800 bytes overhead per event vs. 2–14 bytes for a WebSocket frame.
- Latency equals the polling interval — not truly real-time.
- Battery drain: the radio wakes for every poll cycle, even on idle chats.

**SSE — why ruled out:**
- SSE is **server→client only**. `MessageStreamService.connect()` must send subscribe frames (client→server) to tell the server which chatIds to fan-out. SSE has no client→server channel — you'd need a parallel REST endpoint just for subscribe/unsubscribe, which reintroduces coordination complexity.
- Typing indicators (future) and read receipts both require bidirectional frames. Designing around SSE's limitation now forecloses those features or forces a hybrid.

**Why WebSocket wins:**
- **Bidirectional from the start.** Subscribe frames, future typing events, and read-receipt ACKs all travel on the same connection — no second channel needed.
- **Per-frame overhead is minimal.** After the one-time HTTP upgrade handshake (~1 KB), each message frame carries only 2–14 bytes of framing overhead. Long polling would pay full HTTP headers on every event.
- **Single multiplexed connection.** One `URLSessionWebSocketTask` carries all chatIds via subscribe frames. The per-chatId filter in `subscribe(chatId:)` is a publisher `.filter` in memory — zero additional connections.
- **Future-proof.** `WSEventType` is an enum — adding `.typingIndicator`, `.readReceipt`, `.presenceUpdate` is additive. None of those require protocol changes.

**APNS — why it doesn't replace WebSocket:**
- APNS delivers to the OS, not the app. While the app is foregrounded, APNS is unreliable for in-session delivery (rate-limited, batched by the OS).
- APNS payloads are capped at 4 KB — unsuitable as a message delivery channel.
- The correct model: WebSocket delivers messages while the app is active; APNS wakes the app from background so it can reconnect the WebSocket and run delta sync.

**URLSessionWebSocketTask vs Starscream:**

| | `URLSessionWebSocketTask` | `Starscream` |
|---|---|---|
| Dependency | Zero — part of Foundation | Third-party |
| Reconnect | Manual | Built-in with config |
| Proxy/TLS | System-managed | Configurable |
| Verdict | Prefer for new projects; less surface area | Use if needing custom reconnect logic or non-standard TLS |

In this design, `WebSocketClient` wraps either — the rest of the architecture is indifferent because `MessageStreamDataSource` calls `WebSocketClient` via its own protocol.

---

### Local DB: Realm vs CoreData vs SQLite

The choice of local database determines how `ObserveMessagesUseCase` and `ObserveChatsUseCase` expose live publishers. That's the deciding constraint.

| Option | Live Query Support | Upsert | Boilerplate | Dependency |
|---|---|---|---|---|
| Realm | First-class — notification tokens fire on any write; trivial to wrap as `AnyPublisher` | `realm.add(object, update: .modified)` — atomic, one call | Low | Third-party |
| CoreData | `NSFetchedResultsController` — UIKit-coupled; wrapping as Combine publisher requires significant glue | Fetch-then-insert-or-update; no built-in upsert | High | Zero (first-party) |
| SQLite (GRDB) | `ValueObservation` — clean Combine bridge | `upsert` operator available | Medium | Third-party |
| Raw SQLite | None — manual polling or triggers | Manual | Very high | Zero |

**Why Realm:**
- **Live queries are the architecture's load-bearing feature.** The entire "local DB as SSOT" pattern depends on `ObserveMessagesUseCase` emitting a new `[Message]` every time any DataSource writes. Realm's notification tokens fire on any write to a matching query — one call in the Repository wraps this as `AnyPublisher<[Message], Never>`. CoreData's equivalent (`NSFetchedResultsController`) is tightly coupled to `UITableView`/`UICollectionView`; bridging it to Combine requires a non-trivial adapter.
- **Upsert is atomic and idempotent.** `realm.add(object, update: .modified)` in a write transaction is the whole operation. No "does this ID exist? if yes, update; if no, insert" branching needed. This matters because messages arrive from three sources (REST fetch, WebSocket, delta sync) and all three paths call the same `upsert()`.
- **Performance.** Realm writes are lazy-copy — mutations happen in a transaction without blocking reads. For a chat app with concurrent WebSocket writes and scroll-triggered reads, this is significant.

**The tradeoff — Realm objects are not plain structs:**
- Realm objects must inherit `Object` (RealmSwift). This is a leaky abstraction — it bleeds the storage framework into the model definition.
- **Mitigation in this architecture:** Realm objects live exclusively in the Data layer (`MessageLocalDataSource`). `MessageMapper.toDomain()` converts them to plain `struct Message` (Domain model) before they cross the layer boundary. The Domain layer never imports RealmSwift.
- If the team has a strict "no third-party DB" policy, GRDB is the closest alternative — its `ValueObservation` has a clean Combine bridge and supports upsert. The Repository implementation changes; the Domain layer is untouched.

#### DAU is the wrong scalability lens for a client-side DB

Realm runs **on the device** — not on a shared server. There is no "Realm instance" being hammered by 10M users simultaneously. Each user has their own isolated Realm file on their own phone. A 50M DAU app using Realm is just 50M independent local caches, each fast and isolated.

**Scalability splits into two completely separate axes:**

| Axis | Where it lives | What DAU affects |
|---|---|---|
| **Client-side scalability** | Per-device data volume + query complexity | Not DAU — measured in messages/device, chats/device, query depth |
| **Server-side scalability** | WebSocket servers, fan-out, backend storage, push throughput | This is where DAU matters |

**Client-side DB constraints (per device, not per DAU):**

| Constraint | Realm's practical limit | When it becomes a problem |
|---|---|---|
| Messages stored per device | Handles millions comfortably | Almost never — apps purge old messages (keep last ~1,000 per chat) |
| Write throughput | ~1,000 writes/sec sustained | Only in extreme high-frequency group chats |
| Concurrent read/write | Non-blocking (lazy copy) | Not typically a problem |
| Full-text search | Limited FTS support | If users need to search across all message history |
| Complex joins | Object graph only, no SQL | If schema needs multi-entity aggregations |

**What DAU actually stresses — the server side:**
- **WebSocket server** — maintaining millions of persistent connections simultaneously
- **Message fan-out** — delivering one message to N recipients with low latency
- **Backend storage** — storing and querying billions of messages server-side
- **Push notification throughput** — APNS/FCM at scale
- **API rate limiting and load balancing** — REST endpoints under concurrent load

**In an interview:** if the interviewer asks "how does this scale to 10M DAU?" — clarify which layer they mean. Client-side DB is a per-device concern. Server-side infrastructure is where DAU creates pressure. Answering both in sequence signals you understand the difference.

#### Why real apps moved away from Realm — it was never DAU

| App | Moved to | Real reason |
|---|---|---|
| Signal | GRDB | Better Swift type safety + complex search queries (FTS5) |
| Telegram | Custom C++ TDLib + SQLite | Cross-platform (iOS/Android/Desktop share same logic) + custom MTProto encryption |
| WhatsApp | CoreData (rumored) | First-party, no dependency risk at Meta's scale |

#### The actual client-side migration triggers

1. **Full-text search** — users search "all messages containing X" — Realm's FTS is limited; GRDB/SQLite gives full FTS5
2. **Complex queries** — e.g., "unread messages across all chats grouped by sender" — Realm's object graph struggles with multi-entity aggregations
3. **Cross-platform** — iOS + Android + Desktop sharing business logic pushes toward C++ SQLite (Telegram's approach)
4. **Custom encryption** — enterprise compliance requiring DB-layer encryption Realm doesn't support

None of these are triggered by DAU. And because Domain never imports Realm, the migration stays in the Data layer regardless of the trigger.

#### What real apps actually use

Not every messenger uses Realm — the live query requirement is universal, but how teams solve it varies:

| App | Local DB | Live query mechanism |
|---|---|---|
| Signal iOS | GRDB (SQLite wrapper) | `ValueObservation` — clean Combine bridge |
| Telegram iOS | Custom C++ engine (TDLib) + SQLite | Custom notification layer built on top |
| WhatsApp iOS | CoreData (rumored) | `NSFetchedResultsController` |
| iMessage | CoreData | `NSFetchedResultsController` |
| Facebook Messenger | Custom (Relay + internal store) | Entirely custom reactive store |

Realm is popular in indie and mid-size iOS apps because it ships live queries with minimal boilerplate, mapping cleanly onto Combine. Large companies (Meta, Telegram) build custom storage layers because they have scale, cross-platform consistency requirements, and the engineering budget to justify it.

**For an interview:** Realm is a defensible, mid-level answer — pick it, explain why (live queries, atomic upsert, low boilerplate), and know the tradeoff (object inheritance, third-party dependency). If the interviewer pushes back with "no third-party DBs" — GRDB is the correct fallback. CoreData is the safe first-party answer but you'd need to explain bridging `NSFetchedResultsController` to Combine, which is non-trivial and the interviewer will probe it.

#### Migrating the local DB doesn't break Domain or Presentation

Because Domain never imports Realm — it only knows `MessageRepositoryProtocol` and plain Swift structs — swapping the local DB is scoped entirely to the Data layer.

**What changes on migration (e.g., Realm → GRDB):**

```
Data layer only:
  MessageLocalDataSource   — rewrite query + notification implementation
  ChatLocalDataSource      — same
  MessageRepository        — minor updates if query API shape changes
```

**What is completely untouched:**

```
Domain:
  MessageRepositoryProtocol   — protocol contract doesn't change
  ObserveMessagesUseCase      — still returns AnyPublisher<[Message], Never>
  FetchMessagesUseCase        — still async throws -> [Message]
  Message, Chat               — plain structs, zero storage dependency

Presentation:
  ChatThreadViewModel         — subscribes to the same UseCase interface
  ChatListViewModel           — same
  All ViewControllers         — never knew Realm existed
```

The protocol is the firewall. `ObserveMessagesUseCase` returns `AnyPublisher<[Message], Never>` regardless of whether the DB underneath is Realm, GRDB, CoreData, or a custom store. The ViewModel only ever sees that publisher — the storage engine is an implementation detail behind the Repository protocol.

**Storage is a plugin.** Swap it at any scale without touching business logic or UI.

---

### Analytics: Measuring Both Scalability Axes

You can't validate which scalability axis is stressed without measurement. Client-side write performance is invisible without instrumentation; server-side DAU pressure is guesswork without event tracking. Both axes need separate metrics.

#### Two categories of metrics

**Client-side — per-device write scalability:**

| Metric | What it measures | Where to instrument |
|---|---|---|
| DB write latency | How long `MessageLocalDataSource.upsert()` takes | `MessageLocalDataSource` |
| DB size on device | Total messages stored locally | `MessageLocalDataSource` |
| Cache hit rate | Does `ObserveMessagesUseCase` emit cached data on first load, or empty? | `MessageRepository.observe()` |
| Pending queue size | How many `isSent: false` messages are waiting | `MessageSyncService.syncPending()` |
| Sync duration | How long foreground gap recovery takes end-to-end | `AppCoordinator.handleForeground()` |
| WebSocket reconnect count | How often the socket drops and reconnects per session | `MessageStreamService.connect()` |
| Image cache hit rate | Memory vs disk vs network fetch ratio | `ImageDataSource` |

**Server-side — DAU and infrastructure health:**

| Metric | What it measures |
|---|---|
| DAU / MAU | Derived from `app_open` events — how many unique users per day/month |
| Messages sent per day | Throughput — `message_sent` event on every `SendMessageUseCase` success |
| Message delivery latency | Time from `sentTime` to `receivedTime` — measures fan-out speed |
| WebSocket connection count | Peak concurrent connections — measures infra pressure |
| Delta sync payload size | Are `sequenceId` deltas small as expected, or ballooning? |
| Failed send rate | How often `MessageSyncService` has to retry — signals reliability issues |
| Push notification delivery rate | APNS/FCM success rate at scale |

#### Which layer it lives in

`AnalyticsService` spans three layers — and the split matters:

**Protocol + event types → Domain**

```swift
// Domain — pure Swift, zero SDK import
protocol AnalyticsServiceProtocol {
    func track(_ event: AnalyticsEvent)
}

enum AnalyticsEvent {
    // Server-side DAU signals
    case appOpened
    case messageSent(chatId: String)
    case messageDelivered(latencyMs: Int)

    // Client-side write scalability
    case dbWriteCompleted(latencyMs: Int)
    case syncCompleted(pendingCount: Int, durationMs: Int)
    case wsReconnected(chatIdCount: Int)
    case imageCacheHit(source: CacheSource)
}

enum CacheSource { case memory, disk, network }
```

Domain defines *what* gets tracked. Any Domain Service or DataSource calls `analyticsService.track()` through this protocol without importing Firebase or Amplitude.

**Concrete SDK wrapper → External**

```swift
// External layer — imports the actual SDK
class FirebaseAnalyticsService: AnalyticsServiceProtocol {
    func track(_ event: AnalyticsEvent) {
        switch event {
        case .messageSent(let chatId):
            Analytics.logEvent("message_sent", parameters: ["chat_id": chatId])
        // ...
        }
    }
}
```

Same pattern as `WebSocketClient` wrapping `URLSessionWebSocketTask`, or `ImageDataSource` wrapping SDWebImage. The SDK is always wrapped at the External layer — Domain never imports it.

**Registration → Application**

```swift
// AppCoordinator
let analyticsService: AnalyticsServiceProtocol = FirebaseAnalyticsService()

let messageStreamService = MessageStreamService(
    streamDataSource: ...,
    analyticsService: analyticsService   // injected via init
)
```

#### Calling sites across layers

| Layer | Who calls it | Events tracked |
|---|---|---|
| Domain Services | `MessageStreamService`, `MessageSyncService` | WS connect/reconnect, sync duration, pending count |
| Data | `MessageLocalDataSource`, `ImageDataSource` | DB write latency, cache hit/miss |
| Presentation | `ChatThreadViewModel`, `ChatListViewModel` | User actions — message sent, thread opened |

All calling sites only see `AnalyticsServiceProtocol` — none import the SDK.

**Rule:** data-pipeline events (write latency, sync duration, cache hits) are instrumented at the DataSource/Service level. User-action events (screen open, send tapped) are instrumented at the ViewModel level. Nothing analytics-related ever touches the View.

#### Why not Infrastructure?

`Infrastructure` is for cross-layer SDKs that need a `Gateway` — components that span Presentation, Domain, and Data simultaneously. Analytics doesn't coordinate *between* layers; it's called *from* multiple layers independently. The protocol belongs in Domain so Domain Services can call it without an upward dependency. The concrete SDK wrapper belongs in External, same as every other third-party library.

Swapping `FirebaseAnalyticsService` for `AmplitudeAnalyticsService` is one file in External — nothing else changes.

---

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
