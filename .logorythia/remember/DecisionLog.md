# 决策记录：SwiftCrossUI

## 2026-05-04：引入 SwiftUI Observation Public API 并放宽 Environment 约束

- **决策主题**：参考 `adding-Observation-support` 分支，在当前 `main` 分支（含动画支持改动）之上对齐 SwiftUI Observation public API，同时保持现有 State/DynamicProperty/动画设计不变。
- **结论**：
  1. `ViewModelObserver` 采用原生 `withObservationTracking` 优先、`withPerceptionTracking` 兜底的策略。
  2. `@Environment`、`EnvironmentValues`、`EnvironmentModifier` 的泛型约束统一从 `ObservableObject` 放宽为 `AnyObject`。
- **背景**：此前 `@Environment` 仅支持 `ObservableObject`，无法注入 `@Observable`/`@Perceptible` 实例，导致与 SwiftUI API 不对齐且用户易踩类型不匹配编译错误。
- **备选方案**：
  - A：完全迁移到原生 `Observation`，移除 `Perception` 依赖。因需要支持旧平台和非 Apple 平台，放弃。
  - B：保持 `Perception` 唯一路径，新增一套独立的 Observation 风格 API。因维护两套 API 成本高，放弃。
  - C（采纳）：在 `ViewModelObserver` 层做条件编译双轨，在 `Environment` 层统一放宽约束，既复用现有动画/State 设计，又兼容新 API。
- **理由**：
  - `withObservationTracking` 在 Apple 新平台可用且性能更优；`PerceptionCore` 继续保证跨平台兼容。
  - 将 `AnyObject` 作为环境注入的统一上限约束，是最小改动且语义最贴近 SwiftUI 的方案。
- **影响范围**：
  - `Sources/SwiftCrossUI/State/ViewModelObserver.swift`
  - `Sources/SwiftCrossUI/Environment/Environment.swift`
  - `Sources/SwiftCrossUI/Environment/EnvironmentValues.swift`
  - `Sources/SwiftCrossUI/Views/Modifiers/EnvironmentModifier.swift`
- **后续动作**：验证示例项目在双平台（Apple 新平台 / Linux 或旧 Apple 平台）的编译与运行行为一致。
