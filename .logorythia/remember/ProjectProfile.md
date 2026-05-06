# 项目画像：swift-cross-ui

## 仓库基线信息

- **路径**：`file:///Volumes/知阳/开发/Packges/swift-cross-ui/`
- **类型**：Swift 包（SPM），跨平台 SwiftUI-like UI 框架
- **技术栈**：Swift 6，多后端（AppKit / UIKit / Gtk / WinUI / Terminal）
- **GTK 后端绑定机制**：通过 `CGtk` systemLibrary 目标 + `pkgConfig("gtk4")` 链接原生 GTK4；Swift 类绑定由自研 `GtkCodeGen` 工具基于 `.gir`（GObject Introspection）文件批量生成，而非手写。引入新的原生库（如 libadwaita）需要重复此流程：新增 `C*` systemLibrary → 获取 `.gir` → 运行 `GtkCodeGen` → 生成 Swift 目标。

## 架构概览

```
SwiftCrossUI (公共 API)
  → 后端适配层
    → AppKitBackend / UIKitBackend / GtkBackend / WinUIBackend / TerminalBackend
```

### 核心目录

| 目录 | 职责 |
|------|------|
| `Sources/SwiftCrossUI/` | 跨平台公共 API（View、State、Environment、Modifier、动画等） |
| `Sources/AppKitBackend/` | macOS AppKit 后端实现 |
| `Sources/UIKitBackend/` | iOS/tvOS UIKit 后端实现 |
| `Sources/GtkBackend/` | Linux GTK 后端实现 |
| `Sources/WinUIBackend/` | Windows WinUI 后端实现 |
| `Sources/TerminalBackend/` | 终端后端实现 |

## 构建命令

```bash
swift build       # 开发构建
swift run         # 运行示例
```

## 工程约束

- Swift 6 严格并发检查已开启（`-strict-concurrency=complete`）。
- 后端实现中大量使用 `NSObject` 子类 + `@objc` 选择器进行事件桥接，需特别注意 `@Sendable` 闭包与隔离域的兼容性。
- 用户明确要求保护现有动画 / State 设计不变量，改动需为增量引入。
- `LayoutSystem` 对 `TupleViewChildren` 硬编码依赖；非元组子视图（如 `Group` 包装）回退到慢路径，布局缓存失效。
- `SwiftSyntax` 作为运行时依赖（仅用于修复链接器/插件构建错误），增加二进制体积与启动时间。
- 已知性能基准：新布局系统使 grid benchmark 提升 4 倍，但 message list benchmark 退化 2 倍（`Layout performance.md` 已记录，原因未调查）。
- 导航系统（2026-05-06 已完成自研化）：`NavigationStack` 已重写为完全自研的统一 fallback 路径，不依赖任何后端原生导航控制器；`EitherView` 递归已移除；`NavigationBar` 与 `WindowChromeView` 为自绘基础。所有后端原生 `NavigationStack` 实现文件已删除。
- 状态系统稳定性修复（2026-05-06 已完成）：`Publisher` 统一 `withLock` 封装；`ObservableObjectPublisherStore` 每 16 次访问触发一次僵尸清理；`ViewModelObserver` 引入 `pendingUpdate` 标志位修复丢变更；`Binding` 增加 `Equatable` 等值去重。
- 窗口协议已精简（2026-05-06）：`CoreWindowing.swift` 重命名为 `CanvasSurface.swift`，接口收缩为最小必要集；`Windowing.swift` 已删除；所有后端迁移至 Surface API。
- GTK 后端引入新原生库（如 libadwaita）必须新增 `C*` systemLibrary 目标并重新运行 `GtkCodeGen` 生成 Swift 绑定，不能直接使用 Swift 调用 C API。`GtkCodeGen` 位于 `Sources/GtkCodeGen/`，解析 GIR XML 后输出整模块 Swift 类文件（参考 `Gtk` 目标生成方式）。
- libadwaita 兼容性约束：`AdwNavigationView` 需 libadwaita ≥ 1.4，Ubuntu 22.04 LTS 与 Debian 12 默认源不满足。导航系统当前以自研路径为主，未来可条件编译增量接入 `AdwNavigationView`。

## 基准与诊断入口

| 路径 | 用途 |
|------|------|
| `Benchmarks/LayoutPerformanceBenchmark/` | 布局性能基准测试 |
| `Sources/SwiftCrossUI/SwiftCrossUI.docc/Layout performance.md` | 布局性能说明与已知退化记录 |
