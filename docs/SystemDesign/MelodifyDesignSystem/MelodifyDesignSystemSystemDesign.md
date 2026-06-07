# MelodifyDesignSystem — System Design

`MelodifyDesignSystem` (MDS) is a shared SPM local package consumed by every mini-app's Presentation layer. It provides a token-first, hybrid UIKit + SwiftUI component library with a configuration-pattern public API.

## 1. Requirements

### Functional
- **Token layer:** named constants for color, typography, spacing, corner radius, and shadow elevation — all visual decisions resolve to a token
- **UIKit components (atoms → molecules):** `MDSAvatarView`, `MDSBadgeView`, `MDSLoadingView`, `MDSMessageBubble`, `MDSAudioPlayerView`; also legacy atoms `MDSPrimaryButton`, `MDSEmptyStateView`, `MDSTrackRowView`
- **SwiftUI components:** `MDSButton`, `MDSBadge`, `MDSAvatar`, `MDSEmptyState`, `MDSLoadingOverlay`
- **Bridge layer:** `UIHostingView<Content>` (inline SwiftUI in UIKit without a child VC), `MDSAudioPlayerRepresentable` (UIKit audio player in SwiftUI)
- **Configuration pattern:** every component exposes a `*Configuration` value type as its public API; callers own data, component owns layout

### Non-Functional
- Only `Presentation` and `Application` layers import `MelodifyDesignSystem` — `Domain` and `Data` never do
- Dark/light mode handled automatically via system `UIColor` adaptations (`.label`, `.systemBackground`, etc.); no manual appearance switch
- Theming is a token swap — changing a brand color touches `Color.swift` only, never component internals
- SPM local package structure; ready to be extracted as a remote package without structural changes
- No domain models, no networking, no business logic

---

## 2. Component API (Public Interface)

### Token API

```swift
// Color (MDSColor namespace)
MDSColor.primary              // UIColor — brand blue
MDSColor.primaryVariant       // UIColor — teal accent
MDSColor.onPrimary            // UIColor — white (text on brand backgrounds)
MDSColor.surface              // UIColor — .systemBackground (adapts light/dark)
MDSColor.surfaceElevated      // UIColor — .secondarySystemBackground
MDSColor.error                // UIColor — .systemRed
MDSColor.warning              // UIColor — .systemOrange
MDSColor.success              // UIColor — .systemGreen
MDSColor.textPrimary          // UIColor — .label
MDSColor.textSecondary        // UIColor — .secondaryLabel
MDSColor.textDisabled         // UIColor — .tertiaryLabel

// Typography
Typography.display            // UIFont — 28pt bold
Typography.title              // UIFont — 16pt semibold
Typography.body               // UIFont — 14pt regular
Typography.caption            // UIFont — 12pt regular

// Spacing (CGFloat)
Spacing.xs = 4    Spacing.sm = 8    Spacing.md = 16    Spacing.lg = 24    Spacing.xl = 32

// Radius (CGFloat — corner radius scale)
Radius.xs     Radius.sm     Radius.md     Radius.lg     Radius.full   // pill

// Elevation (shadow descriptor — applied via UIView.applyShadow(_:))
Elevation.low     Elevation.mid     Elevation.high
```

### UIKit Component API

```swift
// MDSAvatarView — circular image with initials fallback
struct MDSAvatarConfiguration {
    var imageURL: URL?
    var initials: String         // shown when imageURL is nil or load fails
    var size: MDSAvatarSize      // .small | .medium | .large
    var backgroundColor: UIColor
}

// MDSBadgeView — numeric unread badge, auto-hides at count == 0
struct MDSBadgeConfiguration {
    var count: Int
}

// MDSLoadingView — spinner + optional label
struct MDSLoadingConfiguration {
    var message: String?
    var variant: MDSLoadingVariant  // .inline | .fullscreen
}

// MDSMessageBubble — chat bubble, outgoing/incoming
struct MDSMessageBubbleConfiguration {
    var text: String
    var timestamp: String
    var isOutgoing: Bool
    var statusIcon: UIImage?        // nil for incoming
}

// MDSAudioPlayerView — play/pause + waveform icon + duration
struct MDSAudioPlayerConfiguration {
    var duration: TimeInterval
    var isPlaying: Bool
    var onPlayPause: () -> Void
}
```

### SwiftUI Component API

```swift
// MDSButton — ButtonStyle variants
struct MDSButton: View { ... }    // .mdsButtonStyle(.filled) or .mdsButtonStyle(.outlined)

// MDSBadge — ViewModifier
View.mdsBadge(count: Int)         // overlays a badge on any View

// MDSAvatar — AsyncImage + initials fallback
MDSAvatar(name: String, url: URL?, size: MDSAvatarSize)

// MDSEmptyState — icon + title + subtitle + optional CTA
MDSEmptyState(
    icon: Image,
    title: String,
    subtitle: String,
    action: MDSEmptyStateAction?   // label + closure
)

// MDSLoadingOverlay — fullscreen translucent spinner
View.overlay { MDSLoadingOverlay(isVisible: Bool) }
```

### Bridge API

```swift
// UIView subclass — hosts a SwiftUI View inline in a UIKit hierarchy.
// No UIHostingController needed; avoids adding an extra VC to the stack.
class UIHostingView<Content: View>: UIView {
    init(rootView: Content)
    func update(rootView: Content)   // triggers re-render
}

// UIViewRepresentable wrapper for MDSAudioPlayerView.
// Used only in SwiftUI screens that need the stateful animation — all other
// MDS UIKit components have native SwiftUI counterparts and are not wrapped.
struct MDSAudioPlayerRepresentable: UIViewRepresentable { ... }
```

---

## 3. Data Model Design

MDS has no domain models and no persistence. Its only model layer is the configuration value types that form the component public API — documented fully under Section 2.

**Why configuration value types, not direct property setters?**  
A `*Configuration` struct is the snapshot of all data the component needs. Passing one value to `configure(_ config:)` (UIKit) or as init params (SwiftUI) is atomic — no partial-update bugs. The component rejects invalid configurations at init, not after layout.

**Token → Configuration → Rendering chain**

```
MDSColor.primary      ─┐
Typography.title      ─┤
Spacing.md            ─┤→ MDSAvatarConfiguration → MDSAvatarView.configure(_:) → UIView.layoutSubviews
Radius.full           ─┘
```

---

## 4. High-Level Design

```
MelodifyDesignSystem/
├── Tokens/
│   ├── Color.swift          — MDSColor namespace
│   ├── Typography.swift     — Typography namespace
│   ├── Spacing.swift        — Spacing namespace
│   ├── Radius.swift         — Radius scale
│   └── Elevation.swift      — shadow descriptors + UIView.applyShadow(_:) extension
├── Components/
│   ├── UIKit/
│   │   ├── MDSAvatarView/        — MDSAvatarView + MDSAvatarConfiguration + MDSAvatarSize
│   │   ├── MDSBadgeView/         — MDSBadgeView + MDSBadgeConfiguration
│   │   ├── MDSLoadingView/       — MDSLoadingView + MDSLoadingConfiguration + MDSLoadingVariant
│   │   ├── MDSMessageBubble/     — MDSMessageBubble + MDSMessageBubbleConfiguration
│   │   └── MDSAudioPlayerView/   — MDSAudioPlayerView + MDSAudioPlayerConfiguration
│   ├── SwiftUI/
│   │   ├── MDSButton.swift       — MDSButtonStyle, MDSButtonVariant, .mdsButtonStyle() extension
│   │   ├── MDSBadge.swift        — MDSBadgeModifier, .mdsBadge(count:) extension
│   │   ├── MDSAvatar.swift       — MDSAvatar View (AsyncImage + initials fallback)
│   │   ├── MDSEmptyState.swift   — MDSEmptyState View + MDSEmptyStateAction
│   │   └── MDSLoadingOverlay.swift — MDSLoadingOverlay View
│   └── Legacy/                   — pre-DS components, retained and hardened with tokens
│       ├── PrimaryButton/        — MDSPrimaryButton + PrimaryButtonConfiguration
│       ├── EmptyStateView/       — MDSEmptyStateView + EmptyStateConfiguration
│       └── TrackRowView/         — MDSTrackRowView + TrackRowConfiguration
└── Bridge/
    ├── UIHostingView.swift               — generic UIView subclass hosting SwiftUI
    └── MDSAudioPlayerRepresentable.swift — UIViewRepresentable for MDSAudioPlayerView
```

**Hybrid strategy decision table**

| Screen type | MDS UIKit components | MDS SwiftUI components | Bridge needed? |
|---|---|---|---|
| UIKit ViewController | Used directly | Embedded via `UIHostingView<T>` | Yes — UIHostingView |
| SwiftUI View | Embedded via `UIViewRepresentable` | Used directly | Only for MDSAudioPlayerView |
| UIKit cell (CollectionView) | Used directly | Not used — lifecycle complexity | No |

**Why `UIHostingView` over `UIHostingController`?**  
For inline embeddings (e.g. a loading overlay inside a ViewController's view hierarchy), `UIHostingController` adds an unnecessary child ViewController with its own `viewWillAppear`/`viewDidLayoutSubviews` lifecycle. `UIHostingView<Content>` is a plain `UIView` subclass — it slots into Auto Layout like any other view, no lifecycle noise.

**Why is `MDSAudioPlayerView` the only wrapped UIKit component?**  
All other MDS UIKit atoms have equivalent native SwiftUI counterparts (`MDSAvatar`, `MDSEmptyState`). `MDSAudioPlayerView` has stateful waveform animation and a play/pause callback — there is no clean SwiftUI equivalent without rewriting the animation logic. The `UIViewRepresentable` wrapper is the pragmatic call.

---

## 5. Data Flow

### UIKit component rendering pipeline

```
Caller (ViewController / Cell)
  → creates MDSAvatarConfiguration(initials: "AL", size: .medium, backgroundColor: MDSColor.primary)
  → avatarView.configure(config)
      → self.size = config.size.dimension            // reads Radius token for cornerRadius
      → backgroundColor = config.backgroundColor
      → if config.imageURL != nil: load image async
        else: initialsLabel.text = config.initials
      → setNeedsLayout()
  → layoutSubviews()
      → cornerRadius = bounds.height / 2             // Radius.full = pill shape via layout
      → subviews positioned using Spacing tokens
```

### SwiftUI component rendering pipeline

```
Caller (SwiftUI View)
  → MDSAvatar(name: "Alice", url: url, size: .medium)
      body:
        ZStack {
            Circle().fill(MDSColor.primary.color)   // token access
            AsyncImage(url: url) { ... }
              .placeholder { Text("AL").font(.from(Typography.title)) }
        }
        .frame(width: size.dimension, height: size.dimension)
  → SwiftUI diffing engine recomputes on state change — no manual setNeedsLayout
```

### Bridge: UIHostingView embedding in UIKit

```
TrackListViewController
  → let loadingHost = UIHostingView(rootView: MDSLoadingOverlay(isVisible: isLoading))
  → view.addSubview(loadingHost)
  → loadingHost.translatesAutoresizingMaskIntoConstraints = false
  → NSLayoutConstraint.activate(...)  // pins to edges like any UIView
  → when isLoading changes:
      loadingHost.update(rootView: MDSLoadingOverlay(isVisible: newValue))
      // triggers SwiftUI body recompute; no VC lifecycle overhead
```

### Token change impact (e.g. brand refresh)

```
Color.swift: MDSColor.primary = UIColor(red: 0.85, green: 0.22, blue: 0.44, alpha: 1)  // one-line change

Impact path:
  All MDSAvatarView instances → backgroundColor = MDSColor.primary   ✅ updated
  All MDSPrimaryButton instances → backgroundColor = MDSColor.primary ✅ updated
  All SwiftUI MDSButton(.filled) → uses MDSColor.primary              ✅ updated
  No component internals touched — token is the single source of truth
```

---

## 6. Technical Deep-dive

### Why token-first instead of hardcoded values inside components?

Without tokens, "brand blue" is `#0066CC` duplicated across 20 files. A brand refresh or dark-mode audit means finding and replacing every occurrence. With tokens, `MDSColor.primary` is the single source — change it once in `Color.swift` and every component that reads it updates automatically. Theming, white-labelling, and dark mode support all reduce to token swaps.

### Why a `*Configuration` value type instead of direct property setters on each component?

Direct property setters (`avatarView.initials = "AL"`, `avatarView.size = .medium`) allow partial updates: a caller can set `initials` but forget to set `size`, leaving the view in an inconsistent intermediate state. A `Configuration` struct is atomic — the component receives a complete snapshot and applies it in one `configure(_:)` call. Invalid combinations can be caught at the struct level before any layout runs. The component owns layout and style; the caller owns data — clean separation.

### Why UIKit for collection view cells and scroll-heavy lists, not SwiftUI?

SwiftUI's `List` and `LazyVStack` do not expose `UICollectionViewDataSourcePrefetching` — the protocol that lets you trigger image prefetch before a cell is visible. For chat and feed use cases, prefetching is the difference between smooth scroll and visible loading. UIKit's `willDisplay(_:forItemAt:)` and `prefetchDataSource` give granular scroll lifecycle control that SwiftUI abstracts away. SwiftUI is the right choice for state-driven, self-contained surfaces (empty states, modals, action sheets) where scroll lifecycle doesn't matter.

### Why `UIHostingView` over `UIHostingController` for inline SwiftUI?

`UIHostingController` is a `UIViewController`. Embedding it for a single view (e.g. a loading overlay) adds it to the view controller hierarchy — it participates in `viewWillAppear`, `viewDidLayoutSubviews`, and similar lifecycle calls that are irrelevant for an overlay. `UIHostingView<Content>` is a plain `UIView` subclass: it lives in the view hierarchy, not the controller hierarchy. Auto Layout treats it like any other view. No lifecycle noise, no extra coordinator delegate wiring.

### Why is `MDSAudioPlayerView` the only UIKit component with a `UIViewRepresentable` wrapper?

All other MDS UIKit components (`MDSAvatarView`, `MDSEmptyStateView`) have native SwiftUI counterparts (`MDSAvatar`, `MDSEmptyState`) that are built with the same tokens and offer identical visual output. Wrapping them via `UIViewRepresentable` would add lifecycle boilerplate for no benefit. `MDSAudioPlayerView` has stateful waveform animation and a `onPlayPause` callback driven by `layoutSubviews` — there is no equivalent SwiftUI animation primitive without reimplementing the animation logic entirely. The wrapper is the pragmatic choice for this one case.

### Why SPM local package instead of embedded targets or a monolith?

An SPM local package enforces hard module boundaries at compile time — a target that doesn't list `MelodifyDesignSystem` in its dependencies cannot import it. An embedded target or folder group is a soft boundary enforced only by convention. The SPM structure also means MDS is trivially extractable to a remote package (e.g. a versioned GitHub release) when the project grows to need it — the consuming apps would change one line in `Package.swift`.

### Interview Q&A

| Question | Answer |
|---|---|
| What does "token-first" mean in practice? | Every visual decision (color, spacing, radius, shadow) is a named constant. Changing the brand or supporting theming touches only the token files, never component internals. |
| Why `*Configuration` instead of setters? | Configuration is atomic — no partial-update bugs. The component receives a complete snapshot and applies it once. Setters allow invalid intermediate states. |
| Why UIKit for cells in the chat list? | Prefetching via `UICollectionViewDataSourcePrefetching`. SwiftUI has no equivalent API for scroll-ahead image loading. |
| Why `UIHostingView` and not `UIHostingController`? | `UIHostingController` is a ViewController — it adds unnecessary lifecycle overhead for an inline view embedding. `UIHostingView` is a plain `UIView` and slots into Auto Layout directly. |
| Can MDS be shipped as a remote package? | Yes. The SPM local package structure is ready. Change the `Package.swift` dependency from a local path to a GitHub URL with a version — nothing inside MDS changes. |
