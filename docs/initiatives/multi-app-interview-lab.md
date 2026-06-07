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

## Design System

`MelodifyDesignSystem` is a shared SPM local package consumed by every mini-app's Presentation layer.

**Layer rule:** Domain and Data never import it. Only Presentation and Application import it.

```
Melodify workspace
├── CoreKit               ← Data + Infrastructure primitives (no UI)
├── MelodifyDesignSystem  ← UI primitives (no domain knowledge)
├── MusicApp              ← Presentation imports both CoreKit (via Data) and MelodifyDesignSystem
├── ChatApp               ← same
└── FeedApp               ← same
```

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
- [x] Philosophy hardened — `RepositoryProtocol` added as explicit Domain component; Domain Service three-test diagnostic + smell test vs Repository; `Spec` suffix introduced for stateless business rules (`Domain/Specs/`); suffix clarity table updated with stateful column
- [x] `Param` replaced by `Request<Query, Path>` — unified UseCase input carrying query + path + `policy: FetchPolicy` (`.fresh` default); all `*Param` typealiases renamed to `*Request`; `policy:` dropped from UseCase/Repository signatures; Data HTTP structs renamed to `*APIRequest` to avoid collision; philosophy updated with `Request` and `APIRequest` suffix rows

### Phase 2 — ChatApp ✅

- [x] Design WebSocket multiplexing layer in CoreKit
- [x] Implement type-safe `MessageContent` enum
- [x] Offline send queue (persist unsent messages, retry on reconnect)
- [x] Mock JSON/local data source for conversations and messages
- [x] UICollectionView with heterogeneous cells (text, image, audio)

### Phase 3 — Design System

**Goal:** Build `MelodifyDesignSystem` into a scalable, maintainable, distributable UI library shared across all mini-apps. Presentation layers become thin — they compose DS components; they don't define primitive UI.

#### Design Principles

- **Token-first** — every visual decision (color, spacing, radius, shadow) is a named token. Changing the brand or supporting dark/light theming touches only token files, never component internals.
- **Hybrid UIKit + SwiftUI** — UIKit for performance-sensitive, lifecycle-heavy screens (collection view cells, scroll-intensive lists); SwiftUI for state-driven, self-contained surfaces (empty states, overlays, action menus). Both layers share the same token vocabulary.
- **Configuration pattern** — every component has a `*Configuration` value type as its public API. The component owns layout and style; callers own data. No subclassing, no delegates for trivial customisation.
- **Distributable** — the SPM local package structure is ready to be extracted to a remote package. Domain and Data layers never import it. Only Presentation and Application import it.

#### Package Structure

```
MelodifyDesignSystem/
├── Tokens/
│   ├── Color.swift          ← semantic tokens (primary, surface, error, …)
│   ├── Typography.swift     ← type scale (display, title, body, caption)
│   ├── Spacing.swift        ← existing (xs → xl)
│   ├── Radius.swift         ← corner radius scale
│   └── Elevation.swift      ← shadow tokens (low, mid, high)
├── Components/
│   ├── UIKit/               ← UIView-based, for UIKit-heavy screens
│   │   ├── MDSAvatarView    ← circular image + initials fallback
│   │   ├── MDSBadgeView     ← unread/count badge
│   │   ├── MDSMessageBubble ← text bubble, outgoing/incoming variant
│   │   ├── MDSAudioPlayerView ← waveform icon + duration + play state
│   │   ├── MDSLoadingView   ← full-screen / inline spinner
│   │   ├── MDSPrimaryButton ← existing, hardened
│   │   ├── MDSEmptyStateView ← existing, hardened
│   │   └── MDSTrackRowView  ← existing, hardened
│   └── SwiftUI/             ← View-based, for SwiftUI screens
│       ├── DSButton         ← ButtonStyle + filled/outlined variants
│       ├── DSEmptyState     ← View (wraps MDSEmptyStateView via representable)
│       ├── DSAvatar         ← View (wraps MDSAvatarView via representable)
│       ├── DSBadge          ← ViewModifier
│       └── DSLoadingOverlay ← View, fullscreen translucent spinner
└── Bridge/
    ├── UIHostingView.swift       ← UIView subclass hosting a SwiftUI View
    │                               (no UIViewController needed — avoids lifecycle noise)
    └── UIViewRepresentable+DS.swift ← convenience representable wrappers for UIKit DS components
```

#### Hybrid Strategy

```
UIKit screen (ViewController)
  └── uses UIKit DS components directly (MDSMessageBubble, MDSAvatarView…)
  └── embeds SwiftUI DS components via UIHostingView<DSLoadingOverlay>
        (no UIHostingController — avoids unnecessary VC hierarchy)

SwiftUI screen (View)
  └── uses SwiftUI DS components directly (DSButton, DSEmptyState…)
  └── embeds UIKit DS components via UIViewRepresentable wrappers
        (only when UIKit component has no SwiftUI equivalent)
```

**Why UIHostingView over UIHostingController?** For embedding a SwiftUI view inline in a UIKit layout (e.g., a loading overlay inside a ViewController's view hierarchy), a bare UIHostingController adds an unnecessary child ViewController. `UIHostingView<Content>` is a UIView subclass that hosts the SwiftUI render tree directly — cleaner stack, no extra lifecycle.

#### Deliverables

**Tokens**
- [ ] `Radius.swift` — corner radius scale (xs → full/pill)
- [ ] `Elevation.swift` — shadow tokens (low, mid, high)
- [ ] `Color.swift` — semantic tokens (primary, surface, error, warning, success, onPrimary…); retire `UIColor+Tokens` extension pattern

**UIKit components (Atoms → Molecules → Organisms)**
- [ ] `MDSAvatarView` *(atom)* — circular image with initials fallback, configurable size
- [ ] `MDSBadgeView` *(atom)* — numeric unread badge, auto-hides at zero
- [ ] `MDSLoadingView` *(atom)* — spinner + optional label, inline and full-screen variants
- [ ] `MDSMessageBubble` *(molecule)* — text bubble with outgoing/incoming variant, status indicator
- [ ] `MDSAudioPlayerView` *(molecule)* — waveform icon + duration label + play/pause state

**SwiftUI components**
- [ ] `DSButton` *(atom)* — ButtonStyle with filled and outlined variants
- [ ] `DSBadge` *(atom)* — ViewModifier, overlays a count badge on any View
- [ ] `DSAvatar` *(molecule)* — async image + initials fallback, wraps `MDSAvatarView` via representable
- [ ] `DSEmptyState` *(organism)* — icon + title + subtitle + optional action, wraps `MDSEmptyStateView`
- [ ] `DSLoadingOverlay` *(molecule)* — translucent fullscreen spinner, shown via `.overlay`

**Bridge**
- [ ] `UIHostingView<Content>` — UIView subclass hosting a SwiftUI View inline (no child ViewController)
- [ ] `UIViewRepresentable` wrappers for `MDSAvatarView` and `MDSAudioPlayerView`

**Retrofit — MusicApp**
- [ ] `TrackCell` — replace inline artwork + label stack with `MDSTrackRowView` (already in DS)
- [ ] `TrackListViewController` — replace manual empty state with `MDSEmptyStateView`; replace manual loading indicator with `MDSLoadingView`
- [ ] `TrackDetailViewController` — replace inline button with `MDSPrimaryButton`; use token spacing and radius throughout
- [ ] `HomeViewController` — replace inline section headers and loading states with DS atoms

**Retrofit — ChatApp**
- [ ] `ConversationCell` — replace inline avatar placeholder with `MDSAvatarView`; replace inline badge with `MDSBadgeView`
- [ ] `TextMessageCell` — replace inline bubble view with `MDSMessageBubble`
- [ ] `AudioMessageCell` — replace inline waveform + duration layout with `MDSAudioPlayerView`
- [ ] `DeletedMessageCell` — apply token typography and color (captionSmall, textDisabled)
- [ ] `ConversationListViewController` — add `MDSEmptyStateView` for zero-conversation state
- [ ] `ChatViewController` input bar — replace inline `UITextField` + `UIButton` with `MDSPrimaryButton`; apply token spacing

**Previews catalog**
- [ ] One `*Preview.swift` file per component showing all variants in light + dark mode

#### Interview Angle

| Question | Answer |
|---|---|
| Why a separate package for UI? | One source of truth — change `MDSMessageBubble` once, ChatApp and any future app update. No duplication, no divergence. |
| Why not SwiftUI only? | Collection view cells and scroll-heavy lists benefit from UIKit's fine-grained lifecycle (`willDisplay`, `prefetchDataSource`). Hybrid lets you pick the right tool per screen. |
| What does "token-first" buy you? | Theming is a token swap, not a component rewrite. Dark mode, brand refresh, white-labelling — all handled at the token layer. |
| Why UIHostingView over UIHostingController? | Avoids an extra child ViewController for inline embeddings. UIHostingView is a plain UIView — it slots into Auto Layout like any other view. |

### Phase 4 — FeedApp
- [ ] Heterogeneous feed items (post, story strip, ad, suggested users)
- [ ] Cursor-based pagination
- [ ] Realm offline-first reads
- [ ] Image prefetching

### Phase 5 — Drill Sessions
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
