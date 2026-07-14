# 刘海抱合式 Compact 布局(Notch-Hugging Compact Layout)

- **日期**:2026-07-14
- **关联 Issue**:#99(参考「灵动歌词 app」把 compact 宽度做到接近灵动岛)
- **前置工作**:`e274b34 feat(ui): reduce compact island footprint`(同分支 `feat/compact-island-width`)
- **状态**:已批准,进入实现

## 背景与动机

#99 的诉求是让 compact 态更贴近 iPhone 灵动岛的小巧观感。上一步已经把 compact 胶囊收窄(220pt)。本次进一步:在**有刘海的设备**上,把封面与播放波浪动画分置于**刘海左右两侧**,歌词放到刘海**下方**一整行,形成真正「抱住刘海」的灵动岛观感。外接屏(无刘海)等其它场景保持现状不变。

## 触发条件(严格收敛风险)

仅当以下三者**同时成立**时启用刘海抱合布局,否则一律走现有水平胶囊布局:

1. `islandState == .compact`
2. `positionMode == .attached`(吸附屏幕顶部;浮窗时刘海不在窗口处,「夹住刘海」无物理依据)
3. 当前屏幕有刘海且能测出刘海宽度(`screen.hasNotch && screen.notchWidth != nil`)

→ expanded / full 态、detached 浮窗、外接无刘海屏 **零影响**。

## 几何测量:`NSScreen` 扩展

在已有 `hasNotch`(`safeAreaInsets.top > 0`)旁新增刘海宽度测量:

```swift
extension NSScreen {
    /// 刘海宽度(逻辑点);无刘海或无法测量时返回 nil。
    var notchWidth: CGFloat? {
        guard let left = auxiliaryTopLeftArea, let right = auxiliaryTopRightArea else { return nil }
        return right.minX - left.maxX
    }
}
```

- 刘海**高度**复用现有 `IslandContentView.menuBarHeight(for:)`(刘海屏上 ≈ 刘海/菜单栏高度)。
- `auxiliaryTopLeftArea` / `auxiliaryTopRightArea` 为 macOS 12+ API,项目 target macOS 14+,可用。
- 拿不到几何(返回 nil)时安全退回水平布局。

## 视图结构

### 新增 `NotchHuggingCompactView`(`Sources/Views/`)

```
VStack(spacing: 0) {
    // 顶部行:高度 = 刘海高度,内容落在刘海两侧的菜单栏那一行
    HStack(spacing: 0) {
        leftEar          // 封面(showArtwork=true)或 music.note 占位(showArtwork=false)
        Spacer().frame(width: notchWidth)   // 刘海宽度的空隙,把两耳推到两侧
        rightEar         // 播放时 PlayingIndicator;暂停/未连接时状态图标
    }
    .frame(height: notchHeight)

    // 下方行:歌词,宽度 = 全窗口宽(与顶部同宽)
    lyricsRow           // 单/双行遵循现有 dualLineMode 设置(复用 MarqueeText / DualLineRow)
}
```

- **左耳**:`showArtwork == true` → `ArtworkView`(自带 `music.note` 无图占位);`showArtwork == false` → 直接显示 `music.note` 占位图标(不加载专辑图),**保持对称、窗口尺寸不变**。
- **右耳**:`isPlaying` → `PlayingIndicator`;否则状态图标(复用 `CompactIslandView` 现有的 `statusIcon`:未连接=天线斜杠,暂停=pause.fill)。
- **歌词行**:复用现有单行 `MarqueeText` / 双行 `DualLineRow` 及其 `displayText` 状态文案逻辑(加载中 / 暂无歌词 / 播放以开始)。为避免与 `CompactIslandView` 重复,把 `displayText` / `currentLineDuration` 等取值逻辑抽到可共享的位置(如一个轻量的 view-model 或共享扩展)。

### 岛体形状:复用实心 `AttachedIslandShape`(与初版设计的偏差)

初版打算新增 `NotchHuggingShape`,在顶边正中挖一个透明凹槽来「露出」刘海。**实测后放弃**:物理刘海是硬件纯黑、本就叠在窗口之上,挖透明凹槽反而会露出凹槽后面的桌面,视觉上是一块「空心」的洞。因此最终 notch-hugging **不挖凹槽**,直接复用现有的实心 `AttachedIslandShape`(底部圆角 + 顶部贴边凹角)——实心黑岛体与硬件黑刘海自然融合。两耳的视觉分隔完全由 `NotchHuggingCompactView` 的内容排布(左耳 + 刘海宽 `Spacer` + 右耳)实现。

### `IslandContentView` 改动

- `compact` case 内根据触发条件二选一:满足 → 渲染 `NotchHuggingCompactView`,背景/裁剪用实心 `AttachedIslandShape`;否则维持现有 `CompactIslandView` + `AttachedIslandShape`/`RoundedRectangle`。
- 刘海几何(`notchWidth` / `notchHeight`)存为 `@State`,在 `onAppear` 及位置/屏幕变化时从 `window.screen` 刷新。

## 尺寸与窗口定位

- `IslandContentView.size(...)` 增加分支:`compact && attached && hasNotch && notchWidth != nil` 时:
  - `宽 = 左耳宽 + 刘海宽 + 右耳宽`
  - `高 = 刘海高度 + 歌词行高`(双行时歌词行更高)
- 窗口仍居中于屏顶(`screen.frame.midX - width/2`,`y = maxY - height`)。因刘海本身水平居中,窗口内容(两耳 + 中间刘海宽 `Spacer`)自动对齐刘海。
- 把**纯几何算式**抽成不依赖 `NSScreen` 的静态函数,便于单测:

```swift
static func notchHuggingSize(notchWidth: CGFloat, notchHeight: CGFloat,
                             earWidth: CGFloat, lyricsRowHeight: CGFloat) -> NSSize
```

### 尺寸基线(实现时按真实测量微调)

- 刘海高度 `notchHeight`:取自 `menuBarHeight`(约 32–38pt)。
- 左/右耳宽 `earWidth`:约 40pt(封面/波浪约 24–26pt + 左右内边距),左右相等以保证对称。
- 歌词行高:单行约 26pt,双行约 44pt。
- 窗口总宽:`≈ 40 + notchWidth + 40`(随机型而变),总高:单行约 `notchHeight + 26`。

## 状态降级与边界

| 情况 | 表现 |
|---|---|
| 播放中 + 有歌词 | 左耳封面 / 右耳波浪 / 下方当前歌词行 |
| 暂停 | 保持框架;右耳→pause.fill;歌词行→「已暂停」文案 |
| 未连接 Spotify | 右耳→天线斜杠;歌词行→「播放以开始」 |
| 加载中 / 无歌词 | 歌词行→「加载中」/「暂无歌词」 |
| 无封面图 | `ArtworkView` 自带 `music.note` 占位 |
| `showArtwork = false` | 左耳显示 `music.note` 占位图标,不加载专辑图,窗口尺寸与对称不变 |

始终保持三段框架,不在两种布局间跳变。

## 测试策略(Swift Testing)

新增测试(纯函数,不碰真实 NSScreen):

- `notchHuggingSize(...)`:给定刘海宽/高、耳宽、歌词行高,校验总宽 = 2×耳宽 + 刘海宽、总高 = 刘海高 + 歌词行高;双行 vs 单行高度差异。
- `notchWidth` 计算:给定左右 `auxiliaryTopArea` rect,校验差值;缺失时为 nil 的退回逻辑(可对计算逻辑抽函数后测试)。

UI 布局与形状对齐通过实际运行在刘海屏上手动验证(截图/肉眼)。

## 非目标 / 范围外

- 不改动 expanded / full 态。
- 不改动 detached 浮窗行为。
- 不改动外接无刘海屏的现有布局。
- 不新增用户设置开关(触发完全由「attached + 刘海」自动决定)。

## 已知权衡

Mac 刘海两侧是菜单栏(左=App 菜单,右=状态图标)。两侧布局会覆盖刘海紧邻两侧的一小块菜单栏区域——因紧贴刘海通常空置,遮挡有限,是「抱住刘海」观感的固有代价。产品侧已确认接受。
