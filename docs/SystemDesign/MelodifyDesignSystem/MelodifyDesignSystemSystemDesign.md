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
