# Changelog

## Unreleased

### Added

- 灵动岛支持"吸附菜单栏"和"自由拖拽"两种位置模式，可通过菜单栏切换，位置偏好跨启动持久化 (#7)
- 测试框架：添加 `LyrislandTests` 测试 target（Swift Testing），包含 LRCParser、TrackMatcher、SyncedLyrics 的单元测试（共 19 个） (#11)
- 统一日志系统：支持 debug/info/warning/error 级别，按日轮转写入 `~/Library/Logs/Lyrisland/`，启动时自动清理 30 天前日志，同时转发至 os.Logger（Console.app 可查看）(#9)
- 灵动岛显示专辑封面：Compact 状态显示小缩略图，Expanded 状态左侧显示中等封面，Full 状态左侧显示大封面配合歌词滚动 (#8)
- 双行歌词显示模式（卡拉OK风格），同时显示当前行和下一行歌词，可通过菜单栏 ⌘D 切换 (#6)
- 新增网易云音乐歌词源（NeteaseProvider），Fallback 链扩展为 LRCLIB → Musixmatch → SodaMusic → Netease (#4)
- 国际化支持（i18n），使用 String Catalog（.xcstrings）
- 简体中文翻译（Onboarding、菜单栏、歌词状态提示）

### Fixed

- 灵动岛在深色壁纸下边界不可见，改用深灰填充并添加微妙边框 (#10)
- 歌词行切换时过渡动画更加平滑流畅，优化 Compact/Expanded/Full 三种状态下的视觉过渡效果 (#5)
- 长歌词行不再被截断，Compact 和 Expanded 状态使用跑马灯自动滚动显示完整歌词 (#3)
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
