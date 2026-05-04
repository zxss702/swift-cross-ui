<<<<<<< Updated upstream
# 项目画像：SwiftCrossUI

## 仓库基线信息

- **组织形态**：Swift Package，跨平台 UI 框架，对标 SwiftUI API。
- **技术栈**：Swift，深度依赖 Point-Free 的 `Perception` 库（`PerceptionCore`）以实现跨平台兼容的细粒度观察能力。
- **构建与依赖**：Swift Package Manager 管理。

## 标准命令体系

（待补充）

## 工程约束

- **观察框架双轨策略**：`ViewModelObserver` 在 Apple 新平台（macOS 14.0 / iOS 17.0 / tvOS 17.0 / watchOS 10.0 / visionOS 1.0）优先使用原生 `Observation` 框架的 `withObservationTracking`，旧平台及非 Apple 平台回退到 `PerceptionCore`。
- **环境注入兼容**：`@Environment`、`EnvironmentValues`、`EnvironmentModifier` 的约束已从 `ObservableObject` 统一放宽到 `AnyObject`，使 `@Environment(Type.self)` 和 `.environment(_:)` 可同时支持 `@ObservableObject`、`@Observable` 及 `@Perceptible` 实例。

## 目录职责映射

（待补充）

## 关键配置入口

（待补充）
=======
## swift-cross-ui

**仓库基线信息**
跨平台 SwiftUI 实现框架。当前工作主要围绕 macOS 后端（AppKitBackend）及 SwiftUI Observation API 的引入。

**技术栈**
- 语言：Swift 6（严格并发检查已启用）
- 后端：AppKit（macOS）

**标准命令体系**
- 构建：`swift build`
- 运行示例：`swift run`

**目录职责映射**
- `Sources/AppKitBackend/`：macOS AppKit 后端实现，包含 `NSObservableTextField`、`NSObservableSecureTextField` 等控件包装。
- `Sources/SwiftCrossUI/`：核心跨平台 UI 框架逻辑，含 State、Environment、View 体系。

**关键配置入口**
- `Package.swift`：构建配置与依赖管理。

**工程约束**
- Swift 6 严格并发模式下，`@MainActor` 闭包隐式要求 `@Sendable`，赋值时需注意类型匹配。
- 项目在引入 SwiftUI Observation public API 时，需保持现有动画与 State 设计不变量。
>>>>>>> Stashed changes
