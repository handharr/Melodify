# Initiative: Multi-App Interview Lab

## Goal

Rebuild Melodify into a multi-app interview preparation workspace. Each mini-app targets a specific interview scenario. Practicing here means being able to explain every component's exact responsibility, every architectural decision, and every trade-off — cold, under pressure.

## Motivation

Failed Glovo iOS architecture interview (May 29, 2026). Key gaps:
- Used optionals in DTOs instead of enums with associated types
- Proposed one WebSocket per conversation (channel explosion)
- Dropped components into diagrams without defining their interfaces
- Could not course-correct under challenge

## Target Apps

| App | Key Concepts to Drill |
|---|---|
| **MusicApp** | HLS streaming, AudioService interface, FetchPolicy, async/await concurrency |
| **ChatApp** | WebSocket multiplexing, type-safe MessageContent enum, offline send queue, real-time concurrency |
| **FeedApp** | Heterogeneous UICollectionView, cursor pagination, image prefetching, Realm offline-first |

More apps added later.

## Architecture

> Extends [`docs/ios-app-system-design-philosophy.md`](../ios-app-system-design-philosophy.md). That doc is the skeleton — this initiative describes the multi-app delta only.

### Workspace Structure

```
Melodify/                            ← project name unchanged
├── Melodify.xcworkspace
├── Melodify/                        ← host app (launcher)
│   └── AppDelegate.swift
├── CoreKit/                         ← SPM local package (Data + Infrastructure primitives)
│   └── Sources/CoreKit/
│       ├── Network/                 (APIClient, WebSocketClient — shared networking)
│       ├── Persistence/             (LocalDataSourceProtocol + JSON mock impl)
│       └── Analytics/               (AnalyticsGatewayProtocol — Gateway protocol, concrete per app)
├── MusicApp/                        ← SPM local package
│   └── Sources/MusicApp/
│       ├── Domain/
│       ├── Data/
│       └── Presentation/
├── ChatApp/                         ← SPM local package
│   └── Sources/ChatApp/
│       ├── Domain/
│       ├── Data/
│       └── Presentation/
└── FeedApp/                         ← SPM local package
    └── Sources/FeedApp/
        ├── Domain/
        ├── Data/
        └── Presentation/
```

### Layer Rules

- `Presentation → Domain ← Data` in every mini-app
- Domain in each mini-app defines its own Repository/Service protocols — never imports CoreKit
- Only Data and Application layers import CoreKit (networking + persistence primitives)
- DI is manual init injection — each app's Coordinator is the composition root, no ServiceLocator
- Mock JSON lives in `Data/` as `LocalJSONDataSource` implementing the same protocol as the remote source — swappable without touching Domain

### WebSocket Design (Chat — most critical)

One shared `WebSocketClient` in `CoreKit`. Multiplexed channels per conversation. Chat domain never owns a connection — it subscribes to a channel.

```
WebSocketClient (CoreKit)
  └── subscribe(channel: "conv-123") → AsyncStream<ChatEvent>
ChatRepository (ChatApp/Data)
  └── messages(conversationId:) → AsyncStream<[Message]>
```

### Type-Safe Message Modeling

```swift
enum MessageContent {
    case text(String)
    case image(URL, aspectRatio: CGFloat)
    case audio(duration: TimeInterval, url: URL)
    case deleted
}
```

No optionals for content type. Switch exhaustively in the cell factory.

## Phases

### Phase 1 — Restructure ✅
- [x] Create `CoreKit` SPM local package
- [x] Move existing music code into `MusicApp` SPM local package
- [x] Wire host app launcher (tab bar — Music Search, Music Home, Chat placeholder, Feed placeholder)
- [x] `WebSocketClient` in `CoreKit/Network/` — channel-multiplexed transport (`subscribe(channel:) → AsyncStream<String>`), `ChannelRouter` actor guards continuations
- [x] `AnalyticsEvent` made app-agnostic — protocol with `name`/`params` in CoreKit; `MusicAnalyticsEvent` enum in `MusicApp/Domain/Analytics/`
- [x] Analytics concretes in CoreKit — `ConsoleAnalyticsGateway` (dev/debug), `NoOpAnalyticsGateway` (test/preview); host app `ConsoleAnalyticsService` removed
- [x] Image loading stack — `ImageDataSourceProtocol` + `ImagePrefetcherProtocol` in CoreKit; `URLSessionImageDataSource` + `NoOpImagePrefetcher` as dev/test stubs; `ImageDataSource` (SDWebImage stub) in `MusicApp/Data/`; `ImageRepositoryProtocol` in `MusicApp/Domain/`; `ImageRepository` in `MusicApp/Data/` wires DataSource + Prefetcher

### Phase 2 — ChatApp
- [ ] Design WebSocket multiplexing layer in CoreKit
- [ ] Implement type-safe `MessageContent` enum
- [ ] Offline send queue (persist unsent messages, retry on reconnect)
- [ ] Mock JSON/local data source for conversations and messages
- [ ] UICollectionView with heterogeneous cells (text, image, audio)

### Phase 3 — FeedApp
- [ ] Heterogeneous feed items (post, story strip, ad, suggested users)
- [ ] Cursor-based pagination
- [ ] Realm offline-first reads
- [ ] Image prefetching

### Phase 4 — Drill Sessions
- [ ] For each app: whiteboard the architecture from scratch in <10 min
- [ ] For each component: define exact interface + responsibilities out loud
- [ ] Practice course-correcting when challenged on WebSocket / pagination / offline

## Interview Answer Targets

| Question | Answer |
|---|---|
| Why WebSocket over HTTP for outbound chat? | You don't need to — HTTP POST for send, WebSocket only for receiving real-time events. Justify based on direction of data flow. |
| Why one socket, not one per conversation? | Server channel explosion. O(conversations) connections per user is unsustainable. One socket + channel subscription is O(1) per user. |
| Why enum over optionals for message type? | Exhaustive switch at compile time. Optionals create invalid states — a message with no text and no image is legal at the type level but illegal in the domain. |
| What does AudioService own exactly? | Playback state machine, `AVAudioSession` category management, background audio entitlement, progress publisher. Not networking — that's the repository. |
