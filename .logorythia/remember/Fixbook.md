## AppKitBackend TextField `@Sendable` 闭包赋值错误

**故障签名**
```
error: assigning non-Sendable parameter 'newValue' to a '@Sendable' closure
```
出现在 `AppKitBackend+TextField.swift` 的 `NSObservableTextField` 与 `NSObservableSecureTextField` 的 `onSubmit` setter 中。

**成因归类**
Swift 6 严格并发模式下，`@MainActor () -> Void` 隐式带有 `@Sendable` 要求。这两个类的 `onSubmit` 属性被编译器推断为普通 `() -> Void`，其 setter 的 `newValue` 在赋值给 `@MainActor () -> Void` 类型的 `_onSubmitAction.action` 时触发类型安全错误。

**修复动作**
将两处属性声明从隐式推断改为显式标注：
```swift
var onSubmit: @MainActor () -> Void { ... }
```
使 setter 的 `newValue` 类型与目标属性 `_onSubmitAction.action` 完全一致。

**验证标准**
`swift build` 后，`AppKitBackend+TextField.swift` 不再报 `assigning non-Sendable parameter` 错误，且 AppKitBackend 模块编译通过。

**适用范围**
- 语言/版本：Swift 6（严格并发检查启用）
- 模块：`AppKitBackend`
- 文件：`file:///Volumes/知阳/开发/Packges/swift-cross-ui/Sources/AppKitBackend/AppKitBackend+TextField.swift`

**排除边界**
- 若目标属性并非 `@MainActor` 标注，则不需要修改属性签名。
- 若项目未启用 Swift 6 严格并发检查，此错误可能以 warning 形式出现或完全不出现。

---

## Publisher 线程安全崩溃

**故障签名**
运行时崩溃或异常行为，栈顶指向 `Publisher.send()` 遍历 `observations` 字典期间。可能伴随 `NSMutableDictionary` 枚举突变错误。

**成因归类**
`Publisher.observations` 在 `send()` 遍历无任何同步保护；若另一线程（如 `ObservableObject` 后台线程）同时调用 `observe(with:)` 修改字典，触发并发修改异常。

**修复动作**
为 `observations` 添加读写锁，或使用 `OSAllocatedUnfairLock`（Swift 6 风格）保护字典读写。

**验证标准**
在多线程场景下对同一 `Publisher` 并发执行 `observe` 与 `send` 不再崩溃。

**适用范围**
- 语言/版本：Swift 6
- 模块：`SwiftCrossUI/State/Publisher.swift`

**排除边界**
仅使用 `observeAsUIUpdater` 的串行队列路径不易触发，但基础 `observe` + `send` 组合存在风险。

---

## ObservableObjectPublisherStore 僵尸条目累积

**故障签名**
大量创建/销毁 `ObservableObject` 实例时内存持续增长； Instruments 中可见大量 `ObservableObjectPublisherStore.Entry` 存活。

**成因归类**
`ObservableObjectPublisherStore.entries` 以 `ObjectIdentifier` 为键缓存发布者，但从不清理 `owner == nil` 的条目；每个销毁的 observable 对象永久留下一个含 `Publisher` 与 `[Cancellable]` 的 Entry。

**修复动作**
在 `publisher(for:)` 调用时检查并移除 `owner == nil` 的条目；或改用 `NSMapTable.weakToStrongObjects()` 替代普通字典。

**验证标准**
循环创建/销毁带有 `@StateObject` 的视图后，`ObservableObjectPublisherStore` 的 `entries` 数量不再无限增长。

**适用范围**
- 模块：`SwiftCrossUI/State/ObservableObject.swift`
- 场景：`ForEach` 内使用 `@StateObject`、大量动态 observable 对象

**排除边界**
Observable 对象生命周期与视图一致且从不销毁时，此问题不会显现。

---

## ViewModelObserver 变更静默丢弃

**故障签名**
状态已变更但 UI 未更新；快速连续操作后界面显示旧数据；偶现的 UI/状态不同步。

**成因归类**
`ViewModelObserver.observe` 的文档说明多次调用时仅追踪最后一次。前一次 `onChange` 若在第二次 `beginTracking` 之后才触发，`invalidate(trackingGeneration)` 返回 `false`，变更被直接忽略。

**修复动作**
不应静默丢弃；至少应在 `beginTracking` 前 flush 上一代的 pending callback，或排队最后一个未处理的变更。

**验证标准**
高频触发 observable 变更（如动画中或快速输入）时，UI 始终能反映最新状态，不再丢失中间更新。

**适用范围**
- 模块：`SwiftCrossUI/State/ViewModelObserver.swift`
- 影响：所有使用 `withObservationTracking` / `withPerceptionTracking` 的视图更新路径

**排除边界**
变更频率低、每次 observe 间隔足够长时不易触发。

---

## Binding/State 等值赋值触发完整更新链

**故障签名**
`Binding` 设置为相同值时仍触发完整布局重新计算；性能分析显示无意义的状态更新占用显著。

**成因归类**
`Binding.setValue` 与 `State.Storage.value` setter 均未检查新值与旧值是否相等（`Equatable`），每次赋值都走 `didChange.send()` → `viewModelDidChange()` → `enqueueBottomUpUpdate()` → `computeLayout()`。

**修复动作**
在 `State.Storage` 的 value setter 或 `Binding.setValue` 中加入 `Equatable` 去重检查；若值未变化则提前返回。

**验证标准**
对 `@State` 的等值重复赋值不再产生 `GraphUpdateHost` 更新事务。

**适用范围**
- 模块：`SwiftCrossUI/State/Binding.swift`、`SwiftCrossUI/State/State.swift`
- 影响：所有使用 `Binding` 与 `@State` 的场景

**排除边界**
非 `Equatable` 类型无法去重，需保持现有行为。
