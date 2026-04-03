# Changelog

## Unreleased

### Added

- GitHub Actions release workflow：push tag 自动构建并发布 DMG + zip 到 GitHub Releases
- DMG 安装包：浅色渐变背景 + 拖拽到 Applications 引导箭头

## 0.4.0 — 2026-04-04

### Added

- App 图标：使用 Icon Composer 制作的 Liquid Glass 风格图标（dark variant），集成到 Asset Catalog 和关于页面
- 菜单栏 Tray 图标：手绘 SVG 矢量图标（小岛 + 波浪），支持深色/浅色模式自适应

## 0.3.0 — 2026-04-04

### Fixed

- Detached + Expanded 模式下内容溢出圆角裁剪区域，通过约束 SwiftUI frame maxHeight 与 NSPanel 尺寸对齐，并将 vertical padding 纳入 detached 面板高度计算 (#67)

### Added

- App 图标：渐变药丸风格图标，集成到 Asset Catalog，关于页面展示
- 菜单栏 Tray 图标：简化版药丸 PDF 矢量图标，支持深色/浅色模式自适应
- 拖拽灵动岛接近菜单栏吸附区域时显示视觉反馈：形状预览切换为吸附样式、边框高亮、白色发光阴影，并触发 haptic 对齐反馈；离开区域后自动恢复 (#64)

## 0.2.0 — 2026-04-04

### Added

- 设置 → 歌词标签页支持拖拽排序歌词源优先级，可启用/禁用单个歌词源；顺序持久化到 UserDefaults，重置按钮恢复默认顺序 (#55)
- 新增繁體中文（zh-Hant）、日本語（ja）、한국어（ko）三种 UI 本地化语言支持 (#41)
- 快捷键管理系统：用户可在设置窗口查看、自定义或禁用所有键盘快捷键，支持冲突检测、跨重启持久化和一键恢复默认，基于 KeyboardShortcuts 库实现全局热键 (#48)
- 灵动岛背景视觉效果：支持纯色、专辑渐变、毛玻璃、动态渐变四种背景样式，可在设置窗口外观标签页中选择，偏好跨启动持久化 (#44)
- RTL（从右到左）语言支持：MarqueeText 根据文本内容自动检测书写方向并反向滚动，淡入淡出遮罩自适应；歌词逐行检测文本方向，`.leading`/`.trailing` 对齐自动翻转以匹配文本语言（如英文系统上的阿拉伯语歌词自动右对齐）(#42)
- Expanded 模式显示歌曲标题和歌手，Full 模式显示歌曲信息和播放控制按钮（上一曲/播放暂停/下一曲）(#29)
- 歌词对齐方式选项：支持左对齐和居中对齐，可在设置窗口外观标签页中切换，偏好跨启动持久化 (#32)
- GitHub Actions CI 流水线：PR 到 main 时自动运行 xcodegen、构建、SwiftFormat 检查、SwiftLint 检查和单元测试 (#22)
- Apple 风格设置窗口（⌘,），包含通用、外观、歌词、关于四个标签页，支持灵动岛位置模式、专辑封面、双行歌词等偏好设置 (#18)
- 通用两层缓存抽象 `Cache<Key, Value>`：支持内存 + 磁盘双层缓存、LRU 淘汰、可配置容量限制、并发请求合并；`ArtworkCache` 和 `LyricsManager` 已迁移至该通用缓存，歌词现支持磁盘持久化 (#17)
- 灵动岛支持"吸附菜单栏"和"自由拖拽"两种位置模式，可通过菜单栏切换，位置偏好跨启动持久化 (#7)
- 测试框架：添加 `LyrislandTests` 测试 target（Swift Testing），包含 LRCParser、TrackMatcher、SyncedLyrics 的单元测试（共 19 个） (#11)
- 统一日志系统：支持 debug/info/warning/error 级别，按日轮转写入 `~/Library/Logs/Lyrisland/`，启动时自动清理 30 天前日志，同时转发至 os.Logger（Console.app 可查看）(#9)
- 灵动岛显示专辑封面：Compact 状态显示小缩略图，Expanded 状态左侧显示中等封面，Full 状态左侧显示大封面配合歌词滚动 (#8)
- 双行歌词显示模式（卡拉OK风格），同时显示当前行和下一行歌词，可通过菜单栏 ⌘D 切换 (#6)
- 新增网易云音乐歌词源（NeteaseProvider），Fallback 链扩展为 LRCLIB → Musixmatch → SodaMusic → Netease (#4)
- 国际化支持（i18n），使用 String Catalog（.xcstrings）
- 简体中文翻译（Onboarding、菜单栏、歌词状态提示）

### Fixed

- 吸附模式下 Expanded 状态的歌曲信息（标题—歌手）溢出到 notch 安全区域被裁剪 (#51)
- Expanded/Full 模式下无歌词时右侧歌词列宽度坍缩导致布局错乱，现在占位文本会撑满可用空间 (#47)
- 吸附模式首次启动时 notch 检测可能失败的问题：延迟到面板首次上屏后再计算 notch 相关尺寸和位置 (#53)
- 切换歌曲时旧歌词短暂闪现：在加载新歌词前立即清除 `currentLyrics`，避免 UI 显示上一首歌的歌词 (#50)
- Expanded 灵动岛歌词改为逐行平滑滚动（ScrollViewReader + scrollTo），替代原有滑动窗口就地刷新；移除 Expanded 视图中对双行歌词模式的引用，双行模式仅作用于 Compact 状态 (#33)
- 首次进入 Full 模式时歌词不会自动滚动到当前播放行，需等下一次行切换才会滚动 (#39)
- 菜单栏点击"设置"无反应：LSUIElement 应用中私有 selector 不可靠，改为手动管理 Settings 窗口 (#31)
- 修复长歌词行 MarqueeText 不再自动滚动的问题：`.id()` 导致视图重建时 `@State` 重置，GeometryReader 尚未测量完成动画就已退出 (#28)
- 自由拖拽模式下拖动灵动岛不再需要长按 0.5 秒，鼠标按下即可直接拖拽 (#25)
- 吸附模式在无刘海外接显示器上有多余顶部间距：改为根据屏幕是否有刘海（`safeAreaInsets.top`）动态决定是否延伸至菜单栏后方，并使用面板实际所在屏幕而非 `NSScreen.main` 计算位置 (#21)
- Full 视图歌词列表滚动卡顿：移除 `tick` 的 30fps 全局发布，视图改为仅响应 `currentLineIndex` 变更；`LyricsScrollView` 不再依赖 `syncEngine`，仅接收必要数据 (#15)
- 跑马灯歌词在当前行结束前会跳回起点重新滚动，改为单次滚动后停留在末尾，新增 `loops` 参数控制是否循环 (#14)
- 灵动岛状态切换动画统一：移除 SwiftUI 独立的尺寸动画，由 NSPanel frame 统一驱动大小变化，消除双重动画抖动 (#12)
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
