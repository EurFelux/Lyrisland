<p align="center">
  <img src="Assets/icon.png" width="128" height="128" alt="Lyrisland Icon">
</p>

<h1 align="center">Lyrisland</h1>

<p align="center">
  <em>/ˈlɪrɪslænd/</em> — Lyrics + Island
</p>

<p align="center">
  Real-time Spotify lyrics in a Dynamic Island style overlay for macOS
</p>

<p align="center">
  <img src="https://img.shields.io/badge/macOS-14.0%2B-blue" alt="macOS 14.0+">
  <img src="https://img.shields.io/badge/Spotify-Desktop-1DB954?logo=spotify&logoColor=white" alt="Spotify">
</p>

<p align="center">
  <a href="README.zh-CN.md">简体中文</a> | <a href="README.zh-TW.md">繁體中文</a> | <strong>English</strong> | <a href="README.ja.md">日本語</a> | <a href="README.ko.md">한국어</a>
</p>

---

## What is Lyrisland?

Lyrisland displays real-time Spotify lyrics at the top of your screen in a Dynamic Island style overlay. Lyrics are precisely synced with playback — lightweight, elegant, and always on your desktop.

## Features

- **Dynamic Island Modes** — Compact, Expanded, and Full modes with smooth animated transitions; Expanded shows track info, Full includes playback controls (prev/play-pause/next)
- **Real-time Sync** — Line-by-line lyrics highlighting, precisely aligned with playback progress
- **Album Artwork** — Displays album art in all three modes — thumbnail in Compact, medium cover in Expanded, large cover in Full
- **Dual-line Lyrics** — Karaoke-style display showing current and next line simultaneously (toggle with ⌘D)
- **Multiple Lyrics Sources** — Fallback chain across 4 providers: LRCLIB → Musixmatch → SodaMusic → Netease, with drag-to-reorder priority and per-source enable/disable in Settings
- **Flexible Positioning** — Snap to menu bar (attached) or free-drag anywhere on screen (detached), with position persisted across launches
- **Background Styles** — Choose from solid color, album gradient, frosted glass, or dynamic gradient backgrounds
- **Customizable Shortcuts** — View, rebind, or disable all keyboard shortcuts in Settings, with conflict detection and one-click reset
- **RTL Support** — Automatic text direction detection for right-to-left languages (e.g. Arabic), with adaptive marquee scroll and alignment
- **Multilingual UI** — Localized in English, 简体中文, 繁體中文, 日本語, 한국어
- **No Login Required** — Reads playback state directly from the local Spotify client via AppleScript, no account authorization needed
- **Lightweight & Resident** — Runs in the menu bar only, no Dock icon, minimal resource usage

## Preview

#### Compact
![Compact](Assets/screenshots/attached.png)

#### Expanded
![Expanded](Assets/screenshots/expanded.png)

#### Full
![Full](Assets/screenshots/full.png)

### Background Styles

#### Solid
![Solid](Assets/screenshots/bg-solid.png)

#### Album Gradient
![Gradient](Assets/screenshots/bg-album-gradient.png)

#### Frosted Glass
![Glass](Assets/screenshots/bg-glass.png)

#### Dynamic Gradient
![Dynamic](Assets/screenshots/bg-dynamic-gradient.png)

### Position Modes

#### Attached to Menu Bar
![Attached](Assets/screenshots/attached.png)

#### Free Floating
![Detached](Assets/screenshots/detached-compact.png)

## Installation

### Homebrew (recommended)

```bash
brew tap EurFelux/lyrisland
brew install --cask lyrisland
```

### Manual Download

Download the latest `.dmg` from [GitHub Releases](https://github.com/EurFelux/Lyrisland/releases), open it, and drag Lyrisland to Applications.

## Getting Started

1. Make sure [Spotify Desktop](https://www.spotify.com/download/) is installed
2. Open Lyrisland
3. On first launch, macOS will request Automation permission — please allow it
4. Play a song in Spotify, and lyrics will automatically appear at the top of your screen

## Requirements

- macOS 14.0 (Sonoma) or later
- Spotify Desktop client

## FAQ

**Q: Do I need to log in to Spotify?**
No. Lyrisland reads playback info from the local Spotify client without any account authorization.

**Q: Why are there no lyrics for some songs?**
Lyrics come from third-party public databases. Niche tracks or instrumentals may not be available yet.

**Q: What if the lyrics are out of sync?**
Use the offset adjustment from the menu bar icon (`[` / `]` keys, ±0.5 seconds each).

**Q: Does it support Apple Music?**
Currently only Spotify is supported.

## Credits

- [Lyricify Lyrics Helper](https://github.com/WXRIW/Lyricify-Lyrics-Helper) — Musixmatch & Netease lyrics API reference

## License

This project is licensed under the [GNU General Public License v3.0](LICENSE).
