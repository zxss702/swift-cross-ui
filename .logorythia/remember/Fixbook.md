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
