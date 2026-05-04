# 模块/架构笔记：SwiftCrossUI

## State / Observation 模块

### 模块职责
- 提供属性包装器（`@State`、`@Binding`、`@Environment`、`@Bindable` 等）以支撑声明式 UI 的响应式数据流。
- 通过 `ViewModelObserver` 追踪视图 `body` 中的属性访问，驱动细粒度视图刷新。

### 入口与出口
- **主入口**：`Sources/SwiftCrossUI/State/ViewModelObserver.swift`
- **环境值定义**：`Sources/SwiftCrossUI/Environment/EnvironmentValues.swift`
- **环境属性包装器**：`Sources/SwiftCrossUI/Environment/Environment.swift`
- **环境修饰器**：`Sources/SwiftCrossUI/Views/Modifiers/EnvironmentModifier.swift`

### 核心契约
- `ViewModelObserver` 在可用平台上优先使用原生 `withObservationTracking`，否则回退到 `withPerceptionTracking`（`PerceptionCore`）。
- `EnvironmentValues` 的 `observable` subscript 存储槽约束已放宽为 `AnyObject`，存储类型从 `[ObjectIdentifier: any ObservableObject]` 改为 `[ObjectIdentifier: Any]`。
- `@Environment` 提供 `init(_ type: Value.Type) where Value: AnyObject`，支持 `@ObservableObject`、`@Observable`、`@Perceptible` 等任意引用类型的环境注入。

### 调用关系
- `Perception` 库（`PerceptionCore`）作为跨平台兜底观察基础设施，被 `ViewModelObserver` 在新平台不可用时代用。
- 用户模型使用 `@Perceptible`/`@Observable`/`@ObservableObject` 时，均可通过 `@Environment(Type.self)` 或 `.environment(_:)` 注入，也可继续使用 `@Bindable` 或显式属性传递。

### 约束与陷阱
- **陷阱 1**：`withObservationTracking` 的 `onChange` 闭包为 `@Sendable`，若在其中捕获非 `Sendable` 的 `backend`，需通过 `runInMainThread` 等机制保证线程安全，避免直接跨线程访问。
- **陷阱 2**：`PerceptionCore` 与原生 `Observation` 的追踪语义存在细微差异，跨平台代码中若依赖特定重绘时序，需在两端分别验证行为一致性。
- **高频问题**：旧分支或文档中仍可能出现 `ObservableObject` 专属约束的示例代码，需以当前 `AnyObject` 约束为准。

### 定位方法
- 检查 `Environment.swift` 中初始化器的 `where` 子句已放宽为 `AnyObject`。
- 查看 `ViewModelObserver.swift` 中 `#if canImport(Observation)` 分支与 `withPerceptionTracking` 回退分支，以确认当前平台使用的追踪方式。
- 若环境值注入失败，检查 `EnvironmentValues.swift` 中 `observableObjects` 的存储与类型转换逻辑。
