<p align="center">
  <img src="Assets/icon.png" width="128" height="128" alt="Lyrisland Icon">
</p>

<h1 align="center">Lyrisland</h1>

<p align="center">
  <em>/ˈlɪrɪslænd/</em> — Lyrics + Island
</p>

<p align="center">
  macOS 灵动岛风格的 Spotify 实时歌词显示
</p>

<p align="center">
  <img src="https://img.shields.io/badge/macOS-14.0%2B-blue" alt="macOS 14.0+">
  <img src="https://img.shields.io/badge/Spotify-Desktop-1DB954?logo=spotify&logoColor=white" alt="Spotify">
</p>

<p align="center">
  <strong>简体中文</strong> | <a href="README.zh-TW.md">繁體中文</a> | <a href="README.md">English</a> | <a href="README.ja.md">日本語</a> | <a href="README.ko.md">한국어</a>
</p>

---

## What is Lyrisland?

Lyrisland 在屏幕顶部以灵动岛（Dynamic Island）的形式，实时展示 Spotify 正在播放的歌词。歌词与音乐精准同步，轻巧优雅，常驻桌面。

## Features

- **灵动岛形态** — 紧凑、展开、完整三种模式，流畅动画过渡；展开模式显示歌曲信息，完整模式包含播放控制（上一曲/播放暂停/下一曲）
- **实时同步** — 歌词逐行高亮，与播放进度精准对齐
- **专辑封面** — 三种模式均展示专辑封面：紧凑模式缩略图、展开模式中等封面、完整模式大封面
- **双行歌词** — 卡拉 OK 风格，同时显示当前行和下一行歌词（⌘D 切换）
- **多歌词源** — 4 个歌词源 Fallback 链：LRCLIB → Musixmatch → 汽水音乐 → 网易云音乐；支持在设置中拖拽排序优先级、启用/禁用单个歌词源
- **灵活定位** — 吸附菜单栏或自由拖拽到屏幕任意位置，位置偏好跨启动持久化
- **背景样式** — 纯色、专辑渐变、毛玻璃、动态渐变四种背景效果可选
- **快捷键自定义** — 在设置中查看、重新绑定或禁用所有快捷键，支持冲突检测和一键恢复默认
- **RTL 支持** — 自动检测从右到左书写语言（如阿拉伯语），跑马灯滚动和对齐方式自适应
- **多语言界面** — English、简体中文、繁體中文、日本語、한국어
- **无需登录** — 通过 AppleScript 直接读取本地 Spotify 客户端状态，无需账号授权
- **轻量常驻** — 仅在菜单栏运行，不占用 Dock 栏，低资源占用

## Preview

#### Compact
![Compact](Assets/screenshots/attached.png)

#### Expanded
![Expanded](Assets/screenshots/expanded.png)

#### Full
![Full](Assets/screenshots/full.png)

### 背景样式

#### 纯色
![Solid](Assets/screenshots/bg-solid.png)

#### 专辑渐变
![Gradient](Assets/screenshots/bg-album-gradient.png)

#### 毛玻璃
![Glass](Assets/screenshots/bg-glass.png)

#### 动态渐变
![Dynamic](Assets/screenshots/bg-dynamic-gradient.png)

### 定位模式

#### 吸附菜单栏
![Attached](Assets/screenshots/attached.png)

#### 自由浮动
![Detached](Assets/screenshots/detached-compact.png)

## 安装

### Homebrew（推荐）

```bash
brew tap EurFelux/lyrisland
brew install --cask lyrisland
```

### 手动下载

从 [GitHub Releases](https://github.com/EurFelux/Lyrisland/releases) 下载最新的 `.dmg` 文件，打开后将 Lyrisland 拖入"应用程序"文件夹。

## Getting Started

1. 确保已安装 [Spotify 桌面客户端](https://www.spotify.com/download/)
2. 打开 Lyrisland
3. 首次启动时，macOS 会请求自动化权限 — 请点击允许
4. 在 Spotify 播放一首歌，歌词将自动出现在屏幕顶部

## Requirements

- macOS 14.0 (Sonoma) 或更高版本
- Spotify 桌面客户端

## FAQ

**Q: 需要登录 Spotify 账号吗？**
不需要。Lyrisland 读取本地 Spotify 客户端的播放信息，不涉及账号授权。

**Q: 为什么有些歌没有歌词？**
歌词来自第三方公开数据库，冷门曲目或纯音乐可能暂无收录。

**Q: 歌词和音乐不同步怎么办？**
在菜单栏图标中使用偏移量调整（`[` / `]` 键，每次 ±0.5 秒）。

**Q: 支持 Apple Music 吗？**
目前仅支持 Spotify。

## Credits

- [Lyricify Lyrics Helper](https://github.com/WXRIW/Lyricify-Lyrics-Helper) — Musixmatch 及网易云歌词 API 参考

## License

本项目基于 [GNU General Public License v3.0](LICENSE) 开源。
