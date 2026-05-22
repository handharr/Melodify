# CLAUDE.md — Melodify

Practice iOS app built for **mid-level iOS interview preparation**.

## Purpose

Melodify is a UIKit + Clean Architecture practice project. It simulates a realistic interview codebase — the kind you'd be given to refactor or extend in a live coding session. Every architectural decision here is intentional and should be explainable out loud.

## Architecture

```
Presentation  →  ViewController + ViewModel (Combine @Published)
Domain        →  UseCase + Protocol + Param + FetchPolicy + Model
Data          →  Repository + DataSource + DTO + Mapper + APIClient
Application   →  AppDelegate (UIKit, no SceneDelegate)
```

Layer dependency rule: **Presentation → Domain ← Data**. Domain depends on nothing.

## APIs

| Data | Source |
|---|---|
| Track search | iTunes Search API — `https://itunes.apple.com/search` |
| Track detail | iTunes Lookup API — `https://itunes.apple.com/lookup?id={id}` |
| Playlists CRUD | MockAPI.io — `https://6a09e642e7e3f433d483900b.mockapi.io/api/v1/playlist` |

## Key Patterns to Know Cold

- DTO → Mapper → Domain Model (Mapper is the only type that knows both)
- `FetchPolicy` (.fresh / .cached / .strict) travels from ViewModel to Repository
- Typed `Param` structs on every UseCase — adding a field doesn't break call sites
- `@MainActor` on ViewModel — all state mutations on main thread, no `DispatchQueue.main.async`
- `async let` for 2 concurrent fetches, `withThrowingTaskGroup` for N
- `defer { isLoading = false }` — guaranteed cleanup on success and failure
- `[weak self]` in all closures to avoid retain cycles
- Unit tests: mock the layer below, assert on the layer you just built

## Entry Point

`AppDelegate.swift` — `UIApplicationSceneManifest_Generation` is disabled in build settings.
Window is wired in `application(_:didFinishLaunchingWithOptions:)`.

## Temp Docs

| File | Purpose |
|---|---|
| `temp-dir/next-step.md` | Recruiter email + interview prep checklist + architecture notes + algorithm cheat sheet |
| `temp-dir/progress.md` | Session progress, file list, pending tasks |
| `temp-dir/mockapi-setup.md` | MockAPI.io setup + endpoint reference |
| `temp-dir/hr-itvw.md` | HR interview notes |
| `temp-dir/ios-music-streaming-system-design.md` | iOS music streaming system design — HLS, architecture, streaming deep dive |
