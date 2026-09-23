# Lithe-IDEA macOS 12 (Monterey) 兼容改造交接文档 (Handoff Pack)

## 1. 项目背景与目标

- **目标系统**：macOS 12.7.1 (Monterey, Apple Silicon arm64)
- **用户背景**：习惯 IntelliJ IDEA 的快捷键与交互模式，不习惯 VS Code；希望 Lithe 能在 macOS 12 本地流畅运行。
- **用户需求确认**：
  - 不需要数据库拖拽（Drag & Drop）特性，可直接剔除以消除 `CoreTransferable.framework` 强依赖。
  - 项目已 Fork 到：`git@github.com:nildeveloper/Lithe-IDEA.git`
  - 当前工作路径：`/Users/liuhaolu/workspace/Lithe-IDEA`
  - 工作分支：`compat/macos-12`（基于官方 main 分支创建）

---

## 2. 关键技术调研结论与架构方案

### 2.1 为什么官方 Release (0.5.1) 无法在 macOS 12 运行？
1. **子进程与运行时完全兼容**：官方 DMG 包内的 `lithe-db-mcp` (Node/TypeScript)、`lithe-db-sidecar` (Rust)、Temurin OpenJDK 21 (Java) 和 Monaco Editor 网页资源在 macOS 12 上均能 100% 正常执行，无系统版本硬依赖。
2. **GUI 主程序硬依赖 macOS 13+ 符号**：`Contents/MacOS/Lithe` 的 `LC_LOAD_DYLIB` 引入了 `CoreTransferable.framework`（macOS 12 系统根本不存在此框架，直接 dyld 崩溃），并且强依赖 `SwiftUI.Window` scene、`SwiftUI.Layout` protocol、`ContinuousClock`、`Duration`、`ViewThatFits`、`Grid` 等 macOS 13 专有运行时符号。
3. **不能用 fake dylib 符号打桩**：因为 `SwiftUI.Window` 和 `SwiftUI.Layout` 是参与 SwiftUI 视图树生命周期求值的核心类型，空桩会在 App 启动初始化时直接触发 `SIGSEGV`。**唯一干净且长久可维护的方案是源码级适配**。

### 2.2 构建环境方案
- **本地环境限制**：宿主机为 macOS 12.7.1，Xcode 命令行工具最高为 Apple Swift 5.7.2，缺乏 Swift 6 / 5.9 语言特性（如 `package` 访问控制等），且无法在 macOS 12 上升级 Xcode 16。
- **解决方案**：在本地进行源码级轻量手术修改，提交到 Fork 仓库，通过 GitHub Actions（`macos-14` runner，预装 Xcode 16 / Swift 6）交叉编译并打包出原生的 `Lithe-macos12-arm64.dmg`。

---

## 3. 已完成修改（已提交至分支 `compat/macos-12`，Commit: 7965afab）

1. **构建与部署目标降级**：
   - `Package.swift`：平台目标由 `.macOS(.v13)` 降为 `.macOS(.v12)`。
   - `macos/Resources/Info.plist`：`LSMinimumSystemVersion` 由 `13.0` 改为 `12.0`。
   - `scripts/build-rust-core.sh`：默认 `MACOSX_DEPLOYMENT_TARGET` 改为 `12.0`。
2. **彻底移除 CoreTransferable 依赖**：
   - `DatabaseSidebarView.swift`：移除 2 处 `.dropDestination` 与 1 处 `.draggable`，并清理了 `formStyle` 和 `scrollContentBackground`。
3. **消除 SwiftUI.Layout 强依赖**：
   - `EditorTabFlowLayout.swift`：将遵从 `Layout` 协议的 `struct EditorTabFlowLayout: Layout` 替换为普通 SwiftUI View（水平 ScrollView + HStack 回退），保留其 `minimumItemWidth` 常量，完全不破坏 `EditorAreaView` 与单元测试。
4. **消除 ViewThatFits**：
   - `GitHubPullRequestsView.swift`：替换为紧凑的 HStack 布局。
   - `WorkbenchView.swift`：状态栏直接展示 `detailedStatusItems`。
5. **消除 Grid / GridRow**：
   - `GenericDebugView.swift`：4 处 Grid/GridRow 替换为标准 VStack + HStack。
6. **消除 macOS 13+ 专用修饰符与组件**：
   - 新增 `SwiftUI12Compatibility.swift`，提供 `.litheScrollBackgroundHidden()` 与 `LabeledContentCompat`。
   - `LinuxDoTopicListView.swift`、`ProjectSidebarView.swift`、`DatabaseSpecializedWorkspaceViews.swift`：全面切换为 `.litheScrollBackgroundHidden()`。
   - `DatabaseSQLWorkspaceView.swift`、`DatabaseTableView.swift`：移除 `.formStyle(.grouped)`，替换 `LabeledContent` 为 `LabeledContentCompat`。

---

## 4. 下一步待办（新会话续接清单）

### 4.1 引入 ContinuousClock & Duration Polyfill（或局部替换）
在 macOS 12 下，Swift 标准库的 `ContinuousClock`、`Duration` 和 `Task.sleep(for:)` 仅在 macOS 13+ 可用。
我们在本地已通过 `swiftc -target arm64-apple-macosx12.0` 完整验证：
可以在 `LitheModuleAPI` 或共享文件中提供免侵入的 Polyfill：
```swift
public struct Duration: Sendable, Equatable, Comparable {
    public let nanoseconds: UInt64
    public init(nanoseconds: UInt64) { self.nanoseconds = nanoseconds }
    public static func milliseconds(_ ms: Int64) -> Duration {
        Duration(nanoseconds: UInt64(max(0, ms)) * 1_000_000)
    }
    public static func seconds(_ s: Int64) -> Duration {
        Duration(nanoseconds: UInt64(max(0, s)) * 1_000_000_000)
    }
    public static func < (lhs: Duration, rhs: Duration) -> Bool {
        lhs.nanoseconds < rhs.nanoseconds
    }
    public var components: (seconds: Int64, attoseconds: Int64) {
        let sec = Int64(nanoseconds / 1_000_000_000)
        let remNano = Int64(nanoseconds % 1_000_000_000)
        return (seconds: sec, attoseconds: remNano * 1_000_000_000)
    }
}

public struct ContinuousClock: Sendable {
    public struct Instant: Sendable, Comparable, Equatable, Hashable {
        public let date: Date
        public init(date: Date = Date()) { self.date = date }
        public static var now: Instant { Instant() }
        public static func < (lhs: Instant, rhs: Instant) -> Bool { lhs.date < rhs.date }
        public func advanced(by duration: Duration) -> Instant {
            Instant(date: date.addingTimeInterval(Double(duration.nanoseconds) / 1_000_000_000))
        }
        public func duration(to other: Instant) -> Duration {
            let interval = other.date.timeIntervalSince(date)
            return Duration(nanoseconds: UInt64(max(0, interval * 1_000_000_000)))
        }
        public static func + (lhs: Instant, rhs: Duration) -> Instant {
            lhs.advanced(by: rhs)
        }
    }
    public init() {}
    public static var now: Instant { Instant() }
    public var now: Instant { Instant() }
    public func sleep(until deadline: Instant) async throws {
        let remaining = deadline.date.timeIntervalSince(Date())
        if remaining > 0 {
            try await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000))
        }
    }
}

extension Task where Success == Never, Failure == Never {
    public static func sleep(for duration: Duration) async throws {
        try await Task.sleep(nanoseconds: duration.nanoseconds)
    }
}
```
也可以直接在涉事的 7 个文件中把时间戳换为 `Date` / `DispatchTime`，`Task.sleep(for:)` 换为 `Task.sleep(nanoseconds:)`。

### 4.2 Window 场景与 openWindow 改造
- `LitheApp.swift`：
  - 移除 `LitheApp.body` 中的 `.defaultSize(...)`、`WindowGroup(id: LitheWindowID.project, for: UUID.self)` 以及 `Window(..., id: LitheWindowID.settings)`。
  - 保留主 `WindowGroup(id: LitheWindowID.welcome)`。
  - 使用标准的 AppKit `NSHostingController` + `NSWindow`（`SettingsWindowController`）实现独立的设置窗口弹出。
- `RootView.swift`：
  - 移除 `@Environment(\.openWindow)`。
  - 将设置弹出改为调用 `SettingsWindowController.shared.show(...)`。

### 4.3 创建 GitHub Actions 编译流水线
创建 `.github/workflows/build-macos12.yml`：
```yaml
name: Build Lithe for macOS 12

on:
  push:
    branches: [ compat/macos-12 ]
  workflow_dispatch:

jobs:
  build:
    runs-on: macos-14
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Setup Rust
        uses: dtolnay/rust-toolchain@stable
        with:
          targets: aarch64-apple-darwin

      - name: Select Xcode 16
        run: sudo xcode-select -s /Applications/Xcode_16.0.app

      - name: Build Rust Core
        env:
          MACOSX_DEPLOYMENT_TARGET: "12.0"
        run: ./scripts/build-rust-core.sh

      - name: Package macOS App & DMG
        env:
          MACOSX_DEPLOYMENT_TARGET: "12.0"
        run: ./scripts/package-app.sh

      - name: Upload DMG Artifact
        uses: actions/upload-artifact@v4
        with:
          name: Lithe-macos12-arm64
          path: build/*.dmg
```

### 4.4 推送代码并触发构建
```bash
git push -u fork compat/macos-12
```
构建成功后直接从 GitHub Actions 下载 `Lithe-macos12-arm64.dmg` 并在本地 macOS 12.7.1 上安装运行即可！
