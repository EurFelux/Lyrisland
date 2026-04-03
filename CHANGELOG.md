# Changelog

## Unreleased

### Added

- 国际化支持（i18n），使用 String Catalog（.xcstrings）
- 简体中文翻译（Onboarding、菜单栏、歌词状态提示）

### Fixed

- 歌词第一句出现前不再误显示 "No lyrics available"，改为显示 ♪ 占位符 (#1)
- 拖动歌词窗口不再误触发形态切换 (#2)

## 0.0.1 — 2026-04-03

首个功能完整版本。

### Features

- 灵动岛风格悬浮窗，支持 Compact / Expanded / Full 三种形态
- 实时读取 Spotify 桌面客户端播放状态（AppleScript，无需登录）
- 播放时间戳同步引擎（锚点 + 线性插值，30fps 刷新）
- 多歌词源 Fallback 链：LRCLIB → Musixmatch → Soda Music（汽水音乐）
- 智能搜索结果匹配（加权评分：曲名 + 艺术家 + 专辑 + 时长）
- 歌词偏移量手动微调（±0.5s）
- 自适应轮询频率（播放 200ms / 暂停 1s / 未运行 3s）
- 首次启动 Onboarding 引导流程
- 菜单栏常驻，不占用 Dock 栏
