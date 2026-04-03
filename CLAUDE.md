# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Run

This project uses **XcodeGen** to generate the Xcode project from `project.yml`. The `.xcodeproj` is gitignored.

```bash
# Generate Xcode project (required after adding/removing files or changing project.yml)
xcodegen generate

# Build
xcodebuild -project Lyrisland.xcodeproj -scheme Lyrisland -destination 'platform=macOS' build

# Run the built app
open ~/Library/Developer/Xcode/DerivedData/Lyrisland-*/Build/Products/Debug/Lyrisland.app
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

**Caveat:** SwiftLint auto-fix changes `let _ =` to `_ =`, which breaks `@ViewBuilder` contexts. The `let _ = syncEngine.tick` pattern in `IslandContentView` uses an inline `swiftlint:disable` for this reason.

## Workflow

- Always update `CHANGELOG.md` under the `Unreleased` section when resolving an issue (bug fix or feature). Include the issue number (e.g. `#1`).

## Architecture

LSUIElement menu bar app (no Dock icon). macOS 14.0+, Swift 5.10.

### Data Flow

```
AppleScript poll (adaptive: 200ms/1s/3s)
    → SpotifyAppleScriptService → SpotifyPlaybackState
    → PlaybackSyncEngine.calibrate() → anchor point
    → 30fps tick timer → interpolated position
    → SwiftUI views read syncEngine.position driven by syncEngine.tick

Track change → LyricsManager.loadLyrics()
    → Provider fallback chain (LRCLIB → Musixmatch → SodaMusic)
    → SyncedLyrics cached by track ID
```

### Key Design Decisions

- **AppleScript for playback state** (not Spotify Web API) — no OAuth needed, low-latency, works offline. Trade-off: requires Automation permission and desktop Spotify client.
- **Anchor + interpolation model** — AppleScript gives position every 200ms; between polls, `PlaybackSyncEngine` linearly extrapolates at 30fps via a Timer-driven `tick` counter. Views depend on the `@Published tick` to trigger redraws.
- **Transparent floating window** — `NSPanel` with `hasShadow=false`, `backgroundColor=.clear`, `isOpaque=false`. The `NSHostingView` is wrapped in a plain `NSView` container, and `sceneBridgingOptions = []` (macOS 14+) disables SwiftUI's automatic window background. All three layers are necessary — removing any one brings back the black rectangle.
- **Adaptive polling** — `PollRate` enum in AppDelegate: `.playing` (200ms), `.paused` (1s), `.notRunning` (3s). PlaybackSyncEngine also stops its tick timer when paused.

### Module Map

- **App/** — `AppDelegate` is the orchestrator: wires services, manages onboarding vs main UI, owns the poll timer and menu bar.
- **Spotify/** — `SpotifyAppleScriptService` (stateless, sync AppleScript calls) and `PlaybackSyncEngine` (@MainActor, owns anchor + tick timer).
- **Lyrics/** — `LyricsManager` (fallback chain + cache), `Providers/` (each implements `LyricsProvider` protocol), `Models/` (TrackInfo, SyncedLyrics/LyricLine).
- **Window/** — `DynamicIslandPanel` (NSPanel subclass) and `IslandState` enum (compact/expanded/full).
- **Views/** — `IslandContentView` is the root; delegates to Compact/Expanded/Full sub-views. `LyricsScrollView` handles auto-scroll. State changes call `DynamicIslandPanel.animateResize()` to sync NSPanel frame.
- **Utils/** — `LRCParser` (shared `[mm:ss.xx]` parser used by LRCLIB and Musixmatch), `TrackMatcher` (weighted name/artist/album/duration scoring for search result ranking).

### Adding a New Lyrics Provider

1. Create `Sources/Lyrics/Providers/YourProvider.swift` implementing `LyricsProvider` protocol (name, priority, fetchLyrics).
2. Add it to the `providers` array in `LyricsManager.swift` at the appropriate priority.
3. Run `xcodegen generate` to include the new file, then build.
