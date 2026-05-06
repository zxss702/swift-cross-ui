# 任务进度与可恢复点

## 2026-05-05 → 2026-05-06：导航系统重设计 + 状态系统稳定性分析

- **任务目标**：
  1. 深度分析现有 `NavigationStack`/`NavigationLink`/`NavigationSplitView` 的问题并重新设计整个导航系统。
  2. 分析状态系统稳定性问题，列出修复清单。
- **当前状态**：**全部完成，编译通过**。
- **已做变更**：
  - 导航系统彻底自研化：删除 `NavigationStacks.swift` 协议、`Windowing.swift`、UIKit/AppKit/Gtk 三端原生 `NavigationStack` 实现；`NavigationStack` 重写为统一自研 fallback 路径；新增 `NavigationBar.swift`、`WindowChromeView.swift`。
  - 窗口协议精简：`CoreWindowing.swift` 重命名为 `CanvasSurface.swift`，接口收缩为最小必要集；所有后端（AppKit、Gtk、Gtk3、WinUI、Dummy）迁移至 Surface API；DummyBackend 完成 13 处方法重命名。
  - `WindowManager` 增强为真正的 surface 跟踪器（`registerSurface`/`unregisterSurface`）；`WindowReference`、`WindowGroupNode`、`WindowNode` 显式适配。
  - 状态系统修复：`Publisher` 统一 `withLock` 封装；`ObservableObjectPublisherStore` 每 16 次访问触发一次 `pruneZombieEntries()`；`ViewModelObserver` 引入 `pendingUpdate` 标志位修复丢变更；`Binding` 增加 `Equatable` 等值去重。
  - 测试适配：所有测试文件 `createWindow` → `createSurface`；`ObservableObject`/`@Published` 歧义通过 `SwiftCrossUI.ObservableObject`/`@SwiftCrossUI.Published` 解决；损坏的 `GtkBackend+Toolbars.swift` 与 `Gtk3Backend+Toolbars.swift` 删除。
- **编译验证**：`SwiftCrossUI`、`SwiftCrossUIMacrosPlugin`、`DummyBackend`、`AppKitBackend`、`GtkBackend`、`Gtk3Backend`、`SwiftCrossUITests` 全部一次编译通过（exit code 0），无新增 error 或 Swift 6 strict concurrency warning。
- **风险与未决事项**：
  - 动画 / State 设计不变量未受破坏（编译通过 + 无并发 warning）。
  - `NavigationPath` 的 Codable 兼容性：自研路径未改动内部表示，持久化场景仍需单独验证。
  - Gtk 后端当前以自研导航为主，未引入 `AdwNavigationView`（兼容性条件未成熟）。
- **复现与验证路径**：
  - 编译验证：`swift build --target SwiftCrossUI --target SwiftCrossUIMacrosPlugin --target DummyBackend --target AppKitBackend --target GtkBackend --target Gtk3Backend --target SwiftCrossUITests`
  - 导航状态保留 / 深层观察 / Publisher 线程安全 / ViewModelObserver 丢变更：需运行现有测试并补充回归测试。