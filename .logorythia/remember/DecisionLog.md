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

---

## 2026-05-05：导航系统重设计——数据驱动 + 原生复用最大化

- **决策主题**：`NavigationStack`/`NavigationLink`/`NavigationSplitView` 存在生命周期管理缺陷、EitherView 递归开销、后端复用不足等问题，用户要求重写整个导航系统并尽可能复用各平台原生导航组件，逻辑与 SwiftUI 一致。
- **结论**：
  1. 移除 `EitherView` 递归，改为类型擦除的 `DestinationRegistry`，按 `Hashable` 路径元素分发视图构建器。
  2. `NavigationStackChildren` 改为以路径数据 identity 为键的节点池：pop 后节点隐藏保留而非销毁，短时间内重新 push 相同数据可复用状态。
  3. `NavigationPath` 内部改用 `ObjectIdentifier` + `AnyHashable` 直接存储，仅在需要持久化时才做序列化；运行时不再依赖 JSON 解码与字符串类型匹配。
  4. 后端原生复用策略：UIKit 继续 `UINavigationController` 并引入 diff 更新；AppKit 采用 `NSNavigationController`（macOS 13+）或 `NSTabViewController` 模拟堆栈；Gtk 优先使用 `AdwNavigationView`（libadwaita），回退到 `AdwLeaflet` 或增强 `Gtk.Stack`。
  5. `NavigationSplitView` 新增 `BackendFeatures.NavigationSplits` 协议，映射到 `UISplitViewController` / `NSSplitViewController` / `AdwOverlaySplitView`。
  6. `NavigationLink` 升级为 SwiftUI 风格，支持任意 `View` 标签并通过环境值自动关联最近 `NavigationStack`。
- **背景**：现有导航系统的 7 项核心缺陷（页面状态不保留、EitherView 递归、NavigationPath 序列化冗余、深层观察缺失、后端复用参差不齐、NavigationLink 缺失、NavigationSplitView 无原生映射）导致用户体验与 SwiftUI 差距大，且性能开销显著。
- **备选方案**：
  - A：保持现有 `EitherView` 递归，仅优化后端。因架构层面的身份标识与状态保留问题无法解决，放弃。
  - B：完全自研导航控制器，不依赖平台原生组件。因用户明确要求复用各平台原生导航，放弃。
  - C（采纳）：数据驱动身份 + 目的地注册表 + 节点池化 + 平台原生组件映射，兼顾 SwiftUI API 一致性与平台体验。
- **理由**：
  - `DestinationRegistry` 消除了 deeply-nested generics 的编译与运行时负担。
  - 节点池化以 `Hashable` 路径元素为身份，符合 SwiftUI "数据即身份" 的语义，且支持状态保留。
  - 各平台使用原生导航组件可获得免费的手势、动画、工具栏集成与辅助功能支持。
- **影响范围**：
  - `Sources/SwiftCrossUI/Views/NavigationStack.swift`
  - `Sources/SwiftCrossUI/Views/NavigationLink.swift`
  - `Sources/SwiftCrossUI/Views/NavigationPath.swift`
  - `Sources/SwiftCrossUI/Views/NavigationSplitView.swift`
  - `Sources/SwiftCrossUI/Backend/BackendFeatures/Containers/NavigationStacks.swift`
  - `Sources/UIKitBackend/UIKitBackend+NavigationStack.swift`
  - `Sources/AppKitBackend/AppKitBackend+NavigationStack.swift`
  - `Sources/GtkBackend/GtkBackend+NavigationStack.swift`
- **后续动作**：
  - P0：实现 `DestinationRegistry` 与节点池化。
  - P0：重写 AppKit 后端导航栈。
  - P1：简化 `NavigationPath` 内部结构。
  - P1：Gtk 后端接入 `AdwNavigationView`（待兼容性条件成熟）。
  - P1：新增 `BackendFeatures.NavigationSplits` 与 `NavigationSplitView` 原生映射。
  - P2：`NavigationLink` 支持任意 `View` 标签。

---

## 2026-05-05：Gtk 后端引入 AdwNavigationView 可行性评估

- **决策主题**：评估 Gtk 后端引入 `AdwNavigationView`（libadwaita）的技术可行性与兼容性风险，确定实施策略。
- **结论**：**暂缓强制引入，采用"先准备绑定、后条件编译启用"的策略。**
  1. 引入 libadwaita 需要新增完整的 C 绑定层（`CAdwaita` systemLibrary）+ 通过 `GtkCodeGen` 生成 Swift 绑定（`Adwaita` 目标），工作量中等但流程清晰。
  2. `AdwNavigationView` 要求 libadwaita ≥ 1.4（2023 年 9 月发布），Ubuntu 22.04 LTS（1.1.0）和 Debian 12（1.2.x）不满足，存在重大兼容性风险。
  3. 推荐方案：条件编译 + `Gtk.Stack` 回退（`#if canImport(Adwaita)`），或完全不引入而增强现有 `Gtk.Stack`。
  4. `Adwaita` 模块的绑定生成工作可提前完成，但不强制链接，为未来切换做准备。
- **背景**：导航系统重设计（同日决策）将 `AdwNavigationView` 列为 Gtk 后端首选原生组件，但此前未验证 libadwaita 在各发行版的实际可用性。
- **备选方案**：
  - A（推荐）：条件编译 + `Gtk.Stack` 回退。兼容旧 LTS，但需维护两套实现。
  - B：强制要求 libadwaita ≥ 1.4。实现简单，但直接抛弃 Ubuntu 22.04 / Debian 12 用户。
  - C：不引入 libadwaita，增强现有 `Gtk.Stack`（手动返回按钮、过渡动画）。零依赖，但与"复用原生组件"目标有差距。
- **理由**：项目已有 `GtkCodeGen` GIR→Swift 流水线，绑定生成本身不难；真正的难点是旧 LTS 发行版的运行时兼容性。在 Ubuntu 22.04 生命周期结束（2027 年 4 月）前，强制依赖门槛过高。
- **影响范围**：
  - `Package.swift`（新增 `CAdwaita`、`Adwaita` 目标，条件依赖配置）
  - `Sources/CAdwaita/`（新建 C 绑定头文件与 modulemap）
  - `Sources/Adwaita/`（生成的 Swift 绑定）
  - `Sources/GtkBackend/GtkBackend+NavigationStack.swift`（双重实现或回退逻辑）
- **后续动作**：
  - 可选：提前生成并维护 `Adwaita` 模块绑定，但不加入 `GtkBackend` 的默认依赖。
  - 导航重写第一阶段暂以 `Gtk.Stack` 为基础实现，待兼容性条件成熟后再切换。

---

## 2026-05-06：导航系统执行方案重大调整——从"原生复用"转向"完全自研"

- **决策主题**：导航系统实际落地时，将 05-05 决策中"尽可能复用各平台原生导航组件"的方案调整为"完全自研、统一 fallback 路径"。
- **结论**：**彻底自研化，不依赖任何平台原生导航控制器。**
  1. 删除 `NavigationStacks.swift` 后端协议及 UIKit/AppKit/Gtk 三端原生 `NavigationStack` 实现。
  2. `NavigationStack` 重写为统一的自研 fallback 路径，由框架层自行管理页面堆栈、标题栏与过渡动画。
  3. 配套新增 `NavigationBar.swift`（自绘标题栏与返回按钮）和 `WindowChromeView.swift`（桌面端自绘窗口装饰基础）。
- **背景**：05-05 决策设想复用 `UINavigationController` / `NSNavigationController` / `AdwNavigationView`，但执行中发现：
  - AppKit `NSNavigationController` 仅 macOS 13+ 可用，旧版本回退策略复杂；
  - `AdwNavigationView` 因 libadwaita 版本兼容性无法强制引入；
  - 维护多套后端原生实现与统一 SwiftUI 行为之间的映射成本极高，且行为不一致风险大。
  - 相比之下，自研路径可控性更高，且与现有视图更新/动画体系衔接更紧密。
- **备选方案**：
  - A（05-05 原方案）：继续按平台分别实现原生导航映射。因维护成本高、平台差异大、旧版本兼容性复杂，放弃。
  - B（采纳）：完全自研导航控制器，统一所有后端行为。以可控性和一致性换取"原生手感"；后续可在自研框架之上增量添加平台特定优化。
- **理由**：
  - 统一行为：消除不同后端之间导航动画、手势、工具栏集成的差异。
  - 降低维护成本：一套实现替代三套（UIKit/AppKit/Gtk）后端原生实现 + 一套 fallback。
  - 与现有体系兼容：自研路径与 `ViewGraph` 更新、动画、`@State` 生命周期管理更一致，避免跨边界状态同步问题。
- **影响范围**：
  - 删除：`Sources/SwiftCrossUI/Backend/BackendFeatures/Containers/NavigationStacks.swift`
  - 删除：`Sources/SwiftCrossUI/Backend/BackendFeatures/Windowing.swift`
  - 删除：`Sources/UIKitBackend/UIKitBackend+NavigationStack.swift`
  - 删除：`Sources/AppKitBackend/AppKitBackend+NavigationStack.swift`
  - 删除：`Sources/GtkBackend/GtkBackend+NavigationStack.swift`
  - 重写：`Sources/SwiftCrossUI/Views/NavigationStack.swift`
  - 新增：`Sources/SwiftCrossUI/Views/NavigationBar.swift`
  - 新增：`Sources/SwiftCrossUI/Views/WindowChromeView.swift`
- **后续动作**：
  - 在自研导航框架稳定后，可增量为特定后端添加原生优化（如 iOS 侧滑返回手势），但基础路径保持自研。
