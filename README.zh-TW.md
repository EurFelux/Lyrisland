<p align="center">
  <img src="Assets/icon.png" width="128" height="128" alt="Lyrisland Icon">
</p>

<h1 align="center">Lyrisland</h1>

<p align="center">
  <em>/ˈlɪrɪslænd/</em> — Lyrics + Island
</p>

<p align="center">
  macOS 靈動島風格的 Spotify 即時歌詞顯示
</p>

<p align="center">
  <img src="https://img.shields.io/badge/macOS-14.0%2B-blue" alt="macOS 14.0+">
  <img src="https://img.shields.io/badge/Spotify-Desktop-1DB954?logo=spotify&logoColor=white" alt="Spotify">
</p>

<p align="center">
  <a href="README.zh-CN.md">简体中文</a> | <strong>繁體中文</strong> | <a href="README.md">English</a> | <a href="README.ja.md">日本語</a> | <a href="README.ko.md">한국어</a>
</p>

---

## What is Lyrisland?

Lyrisland 在螢幕頂部以靈動島（Dynamic Island）的形式，即時顯示 Spotify 正在播放的歌詞。歌詞與音樂精準同步，輕巧優雅，常駐桌面。

## Features

- **靈動島形態** — 緊湊、展開、完整三種模式，流暢動畫過渡；展開模式顯示歌曲資訊，完整模式包含播放控制（上一曲/播放暫停/下一曲）
- **即時同步** — 歌詞逐行高亮，與播放進度精準對齊
- **專輯封面** — 三種模式均展示專輯封面：緊湊模式縮圖、展開模式中等封面、完整模式大封面
- **雙行歌詞** — 卡拉 OK 風格，同時顯示當前行和下一行歌詞（⌘D 切換）
- **多歌詞源** — 4 個歌詞源 Fallback 鏈：LRCLIB → Musixmatch → 汽水音樂 → 網易雲音樂；支援在設定中拖曳排序優先順序、啟用/停用單個歌詞源
- **靈活定位** — 吸附選單列或自由拖曳到螢幕任意位置，位置偏好跨啟動持久化
- **背景樣式** — 純色、專輯漸層、毛玻璃、動態漸層四種背景效果可選
- **快捷鍵自訂** — 在設定中檢視、重新綁定或停用所有快捷鍵，支援衝突偵測和一鍵恢復預設
- **RTL 支援** — 自動偵測從右到左書寫語言（如阿拉伯語），跑馬燈捲動和對齊方式自適應
- **多語言介面** — English、简体中文、繁體中文、日本語、한국어
- **無需登入** — 透過 AppleScript 直接讀取本機 Spotify 客戶端狀態，無需帳號授權
- **輕量常駐** — 僅在選單列執行，不佔用 Dock 列，低資源佔用

## Preview

#### Compact
![Compact](Assets/screenshots/attached.png)

#### Expanded
![Expanded](Assets/screenshots/expanded.png)

#### Full
![Full](Assets/screenshots/full.png)

### 背景樣式

#### 純色
![Solid](Assets/screenshots/bg-solid.png)

#### 專輯漸層
![Gradient](Assets/screenshots/bg-album-gradient.png)

#### 毛玻璃
![Glass](Assets/screenshots/bg-glass.png)

#### 動態漸層
![Dynamic](Assets/screenshots/bg-dynamic-gradient.png)

### 定位模式

#### 吸附選單列
![Attached](Assets/screenshots/attached.png)

#### 自由浮動
![Detached](Assets/screenshots/detached-compact.png)

## 安裝

### Homebrew（推薦）

```bash
brew tap EurFelux/lyrisland
brew install --cask lyrisland
```

### 手動下載

從 [GitHub Releases](https://github.com/EurFelux/Lyrisland/releases) 下載最新的 `.dmg` 檔案，開啟後將 Lyrisland 拖入「應用程式」資料夾。

## Getting Started

1. 確保已安裝 [Spotify 桌面客戶端](https://www.spotify.com/download/)
2. 開啟 Lyrisland
3. 首次啟動時，macOS 會請求自動化權限 — 請點按允許
4. 在 Spotify 播放一首歌，歌詞將自動出現在螢幕頂部

## Requirements

- macOS 14.0 (Sonoma) 或更高版本
- Spotify 桌面客戶端

## FAQ

**Q: 需要登入 Spotify 帳號嗎？**
不需要。Lyrisland 讀取本機 Spotify 客戶端的播放資訊，不涉及帳號授權。

**Q: 為什麼有些歌沒有歌詞？**
歌詞來自第三方公開資料庫，冷門曲目或純音樂可能暫無收錄。

**Q: 歌詞和音樂不同步怎麼辦？**
在選單列圖示中使用偏移量調整（`[` / `]` 鍵，每次 ±0.5 秒）。

**Q: 支援 Apple Music 嗎？**
目前僅支援 Spotify。

## Credits

- [Lyricify Lyrics Helper](https://github.com/WXRIW/Lyricify-Lyrics-Helper) — Musixmatch 及網易雲歌詞 API 參考

## License

本專案基於 [GNU General Public License v3.0](LICENSE) 開源。
