# Changelog

## 0.6.0 — 2026-04-04

### Changed

- Replace priority-based provider fallback with concurrent fetch + best match score selection; remove provider priority concept, simplify settings UI to enable/disable toggle (#89)

### Added

- Add QQ Music and KuGou lyrics providers, significantly improving lyrics coverage for Chinese songs; KuGou supports KRC encrypted format decryption (XOR + DEFLATE) and translated lyrics (#92)
- Manual lyrics source selection: tap the source label in Full mode or use "Select Lyrics…" from menu bar to open the lyrics picker; searches all providers in parallel, each returning multiple candidates ranked by match score; user selection is persisted as track preference and auto-applied on next play (#86)

### Fixed

- Text invisible on light backgrounds: text color now adapts based on background luminance (W3C relative luminance calculation), automatically switching to dark text on light solid backgrounds (#87)
- Brief downward jitter at window top during mode transitions (compact→expanded, expanded→full) (#84)

## 0.5.1 — 2026-04-04

### Fixed

- MarqueeText not scrolling in Compact dual-line lyrics mode: animation state was not reset when a lyric line was promoted from "next line" to "current line" (#82)

## 0.5.0 — 2026-04-04

### Fixed

- Album artwork layout shift during lyrics loading in Full mode (#75)
- Long lyric lines wrapping instead of using MarqueeText single-line scrolling in Full mode (#78, #79)

### Added

- rem-based font scaling: all lyrics-related font sizes scale proportionally from a configurable root font size, adjustable in Settings → Appearance (#77)
- GitHub Actions release workflow: push tag auto-builds and publishes DMG + zip to GitHub Releases
- DMG installer: light gradient background with drag-to-Applications arrow guide
- Homebrew Cask installation support (#72)

## 0.4.0 — 2026-04-04

### Added

- App icon: Liquid Glass style icon (dark variant) made with Icon Composer, integrated into Asset Catalog and About page
- Menu bar tray icon: hand-drawn SVG vector icon (island + waves), adapts to dark/light mode

## 0.3.0 — 2026-04-04

### Fixed

- Content overflowing rounded clipping area in Detached + Expanded mode, fixed by constraining SwiftUI frame maxHeight to align with NSPanel size and including vertical padding in detached panel height calculation (#67)

### Added

- App icon: gradient pill-style icon, integrated into Asset Catalog and displayed on About page
- Menu bar tray icon: simplified pill PDF vector icon, adapts to dark/light mode
- Visual feedback when dragging Dynamic Island near menu bar snap zone: shape preview switches to snapped style with highlighted border and white glow shadow, triggers haptic alignment feedback; auto-reverts on leaving the zone (#64)

## 0.2.0 — 2026-04-04

### Added

- Drag-to-reorder lyrics provider priority in Settings → Lyrics tab, with per-provider enable/disable toggle; order persisted to UserDefaults with reset-to-default button (#55)
- Add Traditional Chinese (zh-Hant), Japanese (ja), and Korean (ko) UI localizations (#41)
- Keyboard shortcut management: view, customize, or disable all shortcuts in Settings, with conflict detection, cross-restart persistence, and one-click reset to defaults, built on KeyboardShortcuts library for global hotkeys (#48)
- Dynamic Island background effects: solid color, album gradient, frosted glass, and animated gradient styles, selectable in Settings → Appearance with cross-launch persistence (#44)
- RTL language support: MarqueeText auto-detects text direction and reverses scroll, with adaptive fade masks; lyrics per-line direction detection with auto-flipping `.leading`/`.trailing` alignment (e.g. Arabic lyrics right-aligned on English system) (#42)
- Song title and artist shown in Expanded mode; song info and playback controls (previous/play-pause/next) in Full mode (#29)
- Lyrics alignment option: left-aligned or centered, selectable in Settings → Appearance with cross-launch persistence (#32)
- GitHub Actions CI pipeline: auto-runs xcodegen, build, SwiftFormat check, SwiftLint check, and unit tests on PR to main (#22)
- Apple-style Settings window (⌘,) with General, Appearance, Lyrics, and About tabs, supporting Dynamic Island position mode, album artwork, dual-line lyrics, and other preferences (#18)
- Generic two-tier cache `Cache<Key, Value>`: memory + disk with LRU eviction, configurable capacity, and concurrent request coalescing; `ArtworkCache` and `LyricsManager` migrated to use it, lyrics now support disk persistence (#17)
- Dynamic Island supports "Snap to menu bar" and "Free drag" position modes, switchable from menu bar with cross-launch persistence (#7)
- Test framework: `LyrislandTests` target (Swift Testing) with unit tests for LRCParser, TrackMatcher, and SyncedLyrics (19 tests) (#11)
- Unified logging system: debug/info/warning/error levels, daily rotation to `~/Library/Logs/Lyrisland/`, auto-cleanup after 30 days, forwarded to os.Logger for Console.app (#9)
- Album artwork in Dynamic Island: small thumbnail in Compact, medium artwork on left in Expanded, large artwork with lyrics scrolling in Full (#8)
- Dual-line lyrics display mode (karaoke-style), showing current and next lyric lines simultaneously, toggled via menu bar ⌘D (#6)
- Add Netease Cloud Music lyrics provider (NeteaseProvider), extending fallback chain to LRCLIB → Musixmatch → SodaMusic → Netease (#4)
- Internationalization (i18n) using String Catalog (.xcstrings)
- Simplified Chinese translation (Onboarding, menu bar, lyrics status messages)

### Fixed

- Song info (title—artist) overflowing into notch safe area in Snapped + Expanded mode (#51)
- Lyrics column width collapsing when no lyrics available in Expanded/Full mode, placeholder text now fills available space (#47)
- Notch detection potentially failing on first launch in Snap mode: deferred calculation until panel first appears on screen (#53)
- Old lyrics briefly flashing on track change: `currentLyrics` now cleared immediately before loading new lyrics (#50)
- Expanded Dynamic Island lyrics now scroll line-by-line smoothly (ScrollViewReader + scrollTo), replacing in-place sliding window refresh; removed dual-line mode references from Expanded view — dual-line mode only applies to Compact state (#33)
- Lyrics not auto-scrolling to current line on first entering Full mode, requiring next line change to trigger scroll (#39)
- Settings menu item unresponsive in menu bar: private selector unreliable in LSUIElement apps, replaced with manual Settings window management (#31)
- MarqueeText no longer auto-scrolling for long lyrics: `.id()` causing view rebuild that resets `@State`, GeometryReader not yet measured before animation exits (#28)
- Free drag mode no longer requires 0.5s long press — mouse down immediately starts dragging (#25)
- Extra top spacing in Snap mode on external displays without notch: now dynamically decides whether to extend behind menu bar based on screen `safeAreaInsets.top`, using the panel's actual screen instead of `NSScreen.main` (#21)
- Full view lyrics list scroll stutter: removed 30fps global `tick` publishing, views now only respond to `currentLineIndex` changes; `LyricsScrollView` no longer depends on `syncEngine`, receiving only necessary data (#15)
- MarqueeText lyrics jumping back to start before current line ends, changed to single scroll then hold at end, added `loops` parameter to control looping (#14)
- Unified Dynamic Island state transition animations: removed independent SwiftUI size animation, NSPanel frame now drives all size changes, eliminating dual-animation jitter (#12)
- Dynamic Island border invisible on dark wallpapers, replaced with dark gray fill and subtle border (#10)
- Smoother lyric line transition animations, improved visual transitions across Compact/Expanded/Full states (#5)
- Long lyric lines no longer truncated, Compact and Expanded states use marquee auto-scroll to show full lyrics (#3)
- No longer showing "No lyrics available" before first lyric line, replaced with ♪ placeholder (#1)
- Dragging lyrics window no longer accidentally triggers mode switch (#2)

## 0.0.1 — 2026-04-03

First functionally complete version.

### Features

- Dynamic Island-style floating window with Compact / Expanded / Full modes
- Real-time Spotify desktop client playback state via AppleScript (no login required)
- Playback timestamp sync engine (anchor + linear interpolation, 30fps refresh)
- Multi-source lyrics fallback chain: LRCLIB → Musixmatch → Soda Music
- Smart search result matching (weighted scoring: track name + artist + album + duration)
- Manual lyrics offset adjustment (±0.5s)
- Adaptive polling rate (playing 200ms / paused 1s / not running 3s)
- First-launch onboarding flow
- Menu bar resident, no Dock icon
