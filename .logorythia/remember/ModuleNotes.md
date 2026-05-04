# 模块/架构笔记

## AppKitBackend TextField 模块

### 模块职责
AppKit 后端中 `TextField` 与 `SecureField` 的创建与更新逻辑，位于 `AppKitBackend+TextField.swift`。

### 入口与出口
- **创建入口**：`createTextField()` / `createSecureField()` → 返回 `NSObservableTextField` / `NSObservableSecureTextField`
- **更新入口**：`updateTextField()` / `updateSecureField()` → 同步状态、绑定 `onChange` 与 `onSubmit` 闭包
- **事件出口**：`NSObservableTextField.onSubmit` / `NSObservableSecureTextField.onSubmit` → 触发用户传入的提交回调

### 核心契约
- `NSObservableTextField`：继承 `NSTextField`，内部持有 `_onSubmitAction`（`TextFieldAction` 实例）以桥接 `@objc` 选择器。
- `NSObservableSecureTextField`：继承 `NSSecureTextField`，同理持有 `_onSubmitAction`。
- `TextFieldAction`：本地私有 `NSObject` 子类，`action` 属性为 `() -> Void`，提供 `@objc func run()`。

### 约束与陷阱
- **Swift 6 Sendable 连环报错**：全局 `Action` 类的 `action` 若为 `@MainActor () -> Void`，则 `() -> Void` 闭包无法直接赋值；若把属性改为 `@MainActor () -> Void`，调用方又会报同样的错。必须使用本地私有类（如 `TextFieldAction`）隔离类型差异。
- `@objc` 选择器桥接要求目标方法暴露给 Objective-C runtime，因此包装类必须继承 `NSObject`。

### 定位方法
- 编译错误 `assigning non-Sendable parameter 'onSubmit' to a '@Sendable' closure` → 检查 `NSObservableTextField` / `NSObservableSecureTextField` 的 `onSubmit` 属性类型及其包装类的 `action` 类型是否一致，确认是否使用了本地私有类而非全局 `Action` 类。
