# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run

This project uses **XcodeGen** to generate the Xcode project from `project.yml`. The `.xcodeproj` is gitignored.

```bash
# Generate Xcode project (required after adding/removing files or changing project.yml)
xcodegen generate

# Build
xcodebuild -project Lyrisland.xcodeproj -scheme Lyrisland -destination 'platform=macOS' build

# Run the built app — always kill the existing process first, then launch.
pkill -x Lyrisland 2>/dev/null; sleep 0.5
open "$(xcodebuild -project Lyrisland.xcodeproj -scheme Lyrisland -showBuildSettings 2>/dev/null | grep -m1 'BUILT_PRODUCTS_DIR' | awk '{print $3}')/Lyrisland.app"

# Test
xcodebuild test -project Lyrisland.xcodeproj -scheme LyrislandTests -destination 'platform=macOS'
```

**Important:** `xcodegen generate` overwrites `Lyrisland.entitlements` with values from `project.yml`'s `entitlements.properties`. Keep those in sync — don't hand-edit the entitlements file.

```bash
# Lint & format
swiftformat Sources        # auto-format
swiftlint --fix Sources    # auto-fix lint issues
swiftlint Sources          # check remaining warnings/errors
```

Both run automatically as Xcode pre-build scripts and as pre-commit hooks via [prek](https://github.com/j178/prek). Config: `.swiftlint.yml`, `.swiftformat`, `prek.toml`.

After cloning, run `prek install` to set up the git pre-commit hook.

**Caveat:** SwiftLint auto-fix changes `let _ =` to `_ =`, which breaks `@ViewBuilder` contexts. If you ever need `let _ =` in a `@ViewBuilder`, add an inline `swiftlint:disable` comment.

## Workflow

- **Never commit directly to `main`.** The `main` branch is protected. For any fix or feature, create a new branch (e.g. `feat/cache-layer`, `fix/marquee-reset`) from `main`, commit there, and open a PR to merge back.
- **⚠️ Every new issue/task MUST get its own branch from `origin/main`.** Never mix unrelated fixes into an existing feature branch. When starting a new issue, the very first step is always `git checkout -b <type>/<desc> origin/main`. Changes for different issues must live in separate branches and separate PRs.
- Always update `CHANGELOG.md` under the `Unreleased` section when resolving an issue (bug fix or feature). Reference the **PR number** (e.g. `(#67)`), not the issue number. **Write changelog entries in English.**
- When a commit resolves a GitHub issue, the commit message **must** include `Fixes #<number>` (e.g. `Fixes #3`) so GitHub automatically closes the issue on push.
- Use [Conventional Commits](https://www.conventionalcommits.org/) format: `<type>(<scope>): <description>`. Common types: `feat`, `fix`, `refactor`, `docs`, `chore`, `style`, `perf`, `test`. Example: `fix(lyrics): resolve long line truncation with marquee scrolling`.
- New features and bug fixes that touch pure logic (parsers, matchers, models) should include unit tests in `Tests/` using **Swift Testing** (`import Testing`, `@Test`, `@Suite`). Run `xcodebuild test` to verify before committing.
- After completing a coding task, use the **code-reviewer** agent (`pr-review-toolkit:code-reviewer`) to review the changes. If the review raises issues (critical or important), fix them and re-run the reviewer. **Repeat until the reviewer approves** before committing.

## Architecture

LSUIElement menu bar app (no Dock icon). macOS 14.0+, Swift 5.10.

### Data Flow

```
AppleScript poll (adaptive: 200ms/1s/3s)
    → SpotifyAppleScriptService → SpotifyPlaybackState
    → PlaybackSyncEngine.calibrate() → anchor point
    → 30fps tick timer → interpolated position + cached currentLineIndex
    → SwiftUI views react to @Published currentLineIndex changes

Track change → LyricsManager.loadLyrics()
    → Concurrent fetch from all enabled providers → best TrackMatcher score wins
    → SyncedLyrics cached by track ID
```

### Key Design Decisions

- **AppleScript for playback state** (not Spotify Web API) — no OAuth needed, low-latency, works offline. Trade-off: requires Automation permission and desktop Spotify client.
- **Anchor + interpolation model** — AppleScript gives position every 200ms; between polls, `PlaybackSyncEngine` linearly extrapolates at 30fps via a Timer-driven `tick` counter. The tick updates an internal `position` and a `@Published currentLineIndex` — views only rebuild when the current lyric line actually changes, not every frame.
- **Transparent floating window** — `NSPanel` with `hasShadow=false`, `backgroundColor=.clear`, `isOpaque=false`. The `NSHostingView` is wrapped in a plain `NSView` container, and `sceneBridgingOptions = []` (macOS 14+) disables SwiftUI's automatic window background. All three layers are necessary — removing any one brings back the black rectangle.
- **Adaptive polling** — `PollRate` enum in AppDelegate: `.playing` (200ms), `.paused` (1s), `.notRunning` (3s). PlaybackSyncEngine also stops its tick timer when paused.

### Module Map

- **App/** — `AppDelegate` is the orchestrator: wires services, manages onboarding vs main UI, owns the poll timer and menu bar.
- **Spotify/** — `SpotifyAppleScriptService` (stateless, sync AppleScript calls) and `PlaybackSyncEngine` (@MainActor, owns anchor + tick timer).
- **Lyrics/** — `LyricsManager` (concurrent best-score selection + cache), `Providers/` (each implements `LyricsProvider` protocol), `Models/` (TrackInfo, SyncedLyrics/LyricLine).
- **Window/** — `DynamicIslandPanel` (NSPanel subclass) and `IslandState` enum (compact/expanded/full).
- **Views/** — `IslandContentView` is the root; delegates to Compact/Expanded/Full sub-views. `LyricsScrollView` handles auto-scroll. State changes call `DynamicIslandPanel.animateResize()` to sync NSPanel frame.
- **Utils/** — `LRCParser` (shared `[mm:ss.xx]` parser used by LRCLIB and Musixmatch), `TrackMatcher` (weighted name/artist/album/duration scoring for search result ranking).

### Logging

The project uses a custom logger (`Sources/Utils/Log.swift`) built on Apple's `OSLog`. It provides dual output: unified system log (viewable in Console.app) and daily rotated log files at `~/Library/Logs/Lyrisland/<yyyy-MM-dd>.log` (30-day retention, auto-cleanup).

**Usage** — call the global convenience functions anywhere in the codebase:

```swift
logDebug("Cache hit for: \(trackId)")      // verbose tracing
logInfo("Track changed: \(title)")          // normal milestones
logWarning("Provider failed: \(error)")     // recoverable issues
logError("Critical failure: \(error)")      // bugs / unexpected state
```

Messages are `@autoclosure` so string interpolation is skipped when the level is below `minimumLevel`. The logger buffers writes and flushes every 5 seconds or every 50 messages. Call `Log.shared.flush()` before a crash-prone path if needed.

**Convention** — Providers prefix messages with their tag (e.g. `[lrclib]`, `[musixmatch]`, `[netease]`, `[sodamusic]`) for easy filtering.

### Caching

The project uses a generic two-tier cache (`Cache<Key, Value>`) for all persistent data. When adding or modifying caching behavior, **read [`docs/cache-spec.md`](docs/cache-spec.md) first** for architecture, API, serializer protocol, and integration guide.

### Adding a New Lyrics Provider

1. Create `Sources/Lyrics/Providers/YourProvider.swift` implementing `LyricsProvider` protocol (name, fetchLyrics, searchLyrics).
2. Add it to the `allProviders` array in `LyricsManager.swift` and add a default entry in `ProviderSettings.defaultEntries`.
3. Run `xcodegen generate` to include the new file, then build.
