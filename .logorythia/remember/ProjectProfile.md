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
