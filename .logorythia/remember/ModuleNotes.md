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

---

## GtkCodeGen GIR→Swift 绑定生成器

### 模块职责
将 GObject Introspection（GIR）XML 文件自动转换为 Swift 类绑定，支撑 `Gtk`、`Gdk`、`Pango` 等原生库的 Swift 调用层。

### 入口与出口
- **入口**：`GtkCodeGen` 可执行目标，解析命令行指定的 `.gir` 文件路径。
- **出口**：批量生成的 Swift 源文件（通常数百个），组成 `Sources/Gtk/` 等目标。
- **关键文件**：`Sources/GtkCodeGen/GtkCodeGen.swift`（主生成逻辑）、`Sources/GtkCodeGen/GIR.swift`（GIR XML 解析）。

### 核心契约
- 读取 `.gir` 中的类、方法、信号、属性定义，映射为 Swift `class` + `@gir` 风格方法。
- 生成的 Swift 目标依赖对应的 `C*` systemLibrary（如 `Gtk` 依赖 `CGtk`）。

### 约束与陷阱
- **命名空间隔离**：不同 GIR 的命名空间不同（如 `Gtk` vs `Adw`），生成逻辑需适配前缀与模块名。
- **版本敏感**：GIR 文件随原生库版本变化，升级 GTK/libadwaita 后需重新生成绑定，可能引入 API 差异。
- **C 头文件前置条件**：生成绑定前必须确保系统已安装对应 `devel` 包并提供 `.gir` 文件（通常位于 `/usr/share/gir-1.0/`）。

### 定位方法
- 若新增原生库（如 libadwaita）需要 Swift 调用，首先检查系统是否提供 `Adw-1.gir`，然后复用 `GtkCodeGen` 生成新模块，而非手写绑定。

---

## 导航系统（自研统一路径）

### 模块职责
`NavigationStack`、`NavigationBar` 及配套导航基础设施，以完全自研方式实现跨平台统一的页面堆栈管理，不依赖任何后端原生导航控制器。

### 入口与出口
- **主入口**：`NavigationStack`（`Sources/SwiftCrossUI/Views/NavigationStack.swift`）——视图声明层。
- **渲染入口**：`NavigationBar`（`Sources/SwiftCrossUI/Views/NavigationBar.swift`）——自绘标题栏与返回按钮。
- **无后端协议出口**：原生 `NavigationStacks.swift` 后端协议及 UIKit/AppKit/Gtk 三端原生实现已全部删除，所有后端共享同一自研路径。

### 核心契约
- 页面堆栈、标题栏、返回按钮、过渡动画均由框架层自行管理。
- `WindowChromeView`（`Sources/SwiftCrossUI/Views/WindowChromeView.swift`）为桌面端自绘窗口装饰提供基础。
- `NavigationPath` 内部表示未被修改，Codable 兼容性保持现状。

### 约束与陷阱
- **状态保留**：pop 后节点是否隐藏保留（节点池化）取决于 `NavigationStackChildren` 的实现细节，需回归验证。
- **动画衔接**：自研路径与现有 `ViewGraph` 更新/动画体系直接衔接，但页面切换动画需自行实现，不能免费获得平台原生过渡。
- **原生优化缺失**：当前无侧滑返回手势、无平台原生导航栏外观；未来可增量添加，但基础路径保持自研。

### 定位方法
- 导航相关问题直接查看 `NavigationStack.swift` / `NavigationBar.swift`，无需再检查后端原生实现文件（已删除）。
- 若不同后端导航行为不一致，属于回归缺陷（统一路径下所有后端应表现一致）。

---

## WindowManager 与窗口生命周期

### 模块职责
`WindowManager`（`Sources/SwiftCrossUI/Scenes/WindowManager.swift`）管理应用 surfaces 的生命周期注册表；`WindowReference`、`WindowGroupNode`、`WindowNode` 负责实际窗口的创建、更新与关闭。

### 入口与出口
- **注册入口**：`WindowManager.shared.registerSurface(_:)` / `unregisterSurface(_:)`
- **引用层**：`WindowReference.init` 注册 surface 到 WindowManager；close handler 中注销。
- **场景层**：`WindowGroupNode`、`WindowNode` 在创建 `WindowReference` 后也显式调用 `registerSurface`（允许重复注册，字典覆盖）。

### 核心契约
- `WindowManager` 以 `ObjectIdentifier` 为键维护 `surfaces` 字典，跟踪当前活跃的 surface 数量。
- `CanvasSurface` 协议（原 `CoreWindowing`）已精简为最小接口：`createSurface`、`show`、`close`、`setSize`、`setResizeHandler`、`setChild`、`setCloseHandler` 等。
- 所有后端（AppKit、Gtk、Gtk3、WinUI、Dummy）均已完成 Surface API 迁移。

### 约束与陷阱
- **重复注册安全**：`WindowReference.init` 和 `WindowGroupNode`/`WindowNode` 都会调用 `registerSurface`，但字典覆盖行为保证安全。
- **注销时序**：`WindowReference` 的 close handler 包装了外部传入的 `closeHandler`，确保先 `unregisterSurface` 再执行外部逻辑。
- **旧 API 残留**：测试代码中可能存在未迁移的 `createWindow` 调用，已通过批量替换修复。

### 定位方法
- surface 泄漏/未注册：检查 `WindowReference` 的 init 和 close handler 包装逻辑，以及 `WindowGroupNode`/`WindowNode` 的显式注册点。
- 后端接口不匹配：确认后端已实现 `CanvasSurface` 而非旧 `Windowing` 协议。

---

## 布局系统（LayoutSystem / StackLayoutCache）

### 模块职责
负责 `VStack`/`HStack` 等堆视图的尺寸协商与布局缓存。

### 核心契约
- `CurrentLayoutCacheKey` 包含 `environment: AnyHashable`，`EnvironmentValues` 字典的哈希计算构成缓存键开销。
- `StackLayoutCache.Signature` 同样包含 `environment: AnyHashable`。

### 约束与陷阱
- **临时数组重复分配**：`computeLayouts` 每次以 `[ViewLayoutResult](repeating: .leafView(size: .zero), count: children.count)` 新建数组，深度嵌套界面中堆分配压力大。
- **子视图双重布局**：`recomputeCache` 中为计算 flexibilities，每个子视图分别以 `minimumProposedSize` 和 `maximumProposedSize` 各布局一次；缓存失效时深层计算开销显著。
- **签名生成 O(n)**：`stackCacheSignature` 需遍历所有子节点调用类型擦除的 `layoutState()`，本为快速路径却附加线性闭包调用。
- **TupleViewChildren 硬编码**：`VStack.computeLayout` 仅对 `TupleViewChildren` 或 `EmptyViewChildren` 启用布局缓存，其他包装器回退慢路径。

---

## GtkCodeGen GIR→Swift 绑定生成器

### 模块职责
将 GObject Introspection（GIR）XML 文件自动转换为 Swift 类绑定，支撑 `Gtk`、`Gdk`、`Pango` 等原生库的 Swift 调用层。

### 入口与出口
- **入口**：`GtkCodeGen` 可执行目标，解析命令行指定的 `.gir` 文件路径。
- **出口**：批量生成的 Swift 源文件（通常数百个），组成 `Sources/Gtk/` 等目标。
- **关键文件**：`Sources/GtkCodeGen/GtkCodeGen.swift`（主生成逻辑）、`Sources/GtkCodeGen/GIR.swift`（GIR XML 解析）。

### 核心契约
- 读取 `.gir` 中的类、方法、信号、属性定义，映射为 Swift `class` + `@gir` 风格方法。
- 生成的 Swift 目标依赖对应的 `C*` systemLibrary（如 `Gtk` 依赖 `CGtk`）。

### 约束与陷阱
- **命名空间隔离**：不同 GIR 的命名空间不同（如 `Gtk` vs `Adw`），生成逻辑需适配前缀与模块名。
- **版本敏感**：GIR 文件随原生库版本变化，升级 GTK/libadwaita 后需重新生成绑定，可能引入 API 差异。
- **C 头文件前置条件**：生成绑定前必须确保系统已安装对应 `devel` 包并提供 `.gir` 文件（通常位于 `/usr/share/gir-1.0/`）。

### 定位方法
- 若新增原生库（如 libadwaita）需要 Swift 调用，首先检查系统是否提供 `Adw-1.gir`，然后复用 `GtkCodeGen` 生成新模块，而非手写绑定。

---

## 导航系统（自研统一路径）

### 模块职责
`NavigationStack`、`NavigationBar` 及配套导航基础设施，以完全自研方式实现跨平台统一的页面堆栈管理，不依赖任何后端原生导航控制器。

### 入口与出口
- **主入口**：`NavigationStack`（`Sources/SwiftCrossUI/Views/NavigationStack.swift`）——视图声明层。
- **渲染入口**：`NavigationBar`（`Sources/SwiftCrossUI/Views/NavigationBar.swift`）——自绘标题栏与返回按钮。
- **无后端协议出口**：原生 `NavigationStacks.swift` 后端协议及 UIKit/AppKit/Gtk 三端原生实现已全部删除，所有后端共享同一自研路径。

### 核心契约
- 页面堆栈、标题栏、返回按钮、过渡动画均由框架层自行管理。
- `WindowChromeView`（`Sources/SwiftCrossUI/Views/WindowChromeView.swift`）为桌面端自绘窗口装饰提供基础。
- `NavigationPath` 内部表示未被修改，Codable 兼容性保持现状。

### 约束与陷阱
- **状态保留**：pop 后节点是否隐藏保留（节点池化）取决于 `NavigationStackChildren` 的实现细节，需回归验证。
- **动画衔接**：自研路径与现有 `ViewGraph` 更新/动画体系直接衔接，但页面切换动画需自行实现，不能免费获得平台原生过渡。
- **原生优化缺失**：当前无侧滑返回手势、无平台原生导航栏外观；未来可增量添加，但基础路径保持自研。

### 定位方法
- 导航相关问题直接查看 `NavigationStack.swift` / `NavigationBar.swift`，无需再检查后端原生实现文件（已删除）。
- 若不同后端导航行为不一致，属于回归缺陷（统一路径下所有后端应表现一致）。

---

## WindowManager 与窗口生命周期

### 模块职责
`WindowManager`（`Sources/SwiftCrossUI/Scenes/WindowManager.swift`）管理应用 surfaces 的生命周期注册表；`WindowReference`、`WindowGroupNode`、`WindowNode` 负责实际窗口的创建、更新与关闭。

### 入口与出口
- **注册入口**：`WindowManager.shared.registerSurface(_:)` / `unregisterSurface(_:)`
- **引用层**：`WindowReference.init` 注册 surface 到 WindowManager；close handler 中注销。
- **场景层**：`WindowGroupNode`、`WindowNode` 在创建 `WindowReference` 后也显式调用 `registerSurface`（允许重复注册，字典覆盖）。

### 核心契约
- `WindowManager` 以 `ObjectIdentifier` 为键维护 `surfaces` 字典，跟踪当前活跃的 surface 数量。
- `CanvasSurface` 协议（原 `CoreWindowing`）已精简为最小接口：`createSurface`、`show`、`close`、`setSize`、`setResizeHandler`、`setChild`、`setCloseHandler` 等。
- 所有后端（AppKit、Gtk、Gtk3、WinUI、Dummy）均已完成 Surface API 迁移。

### 约束与陷阱
- **重复注册安全**：`WindowReference.init` 和 `WindowGroupNode`/`WindowNode` 都会调用 `registerSurface`，但字典覆盖行为保证安全。
- **注销时序**：`WindowReference` 的 close handler 包装了外部传入的 `closeHandler`，确保先 `unregisterSurface` 再执行外部逻辑。
- **旧 API 残留**：测试代码中可能存在未迁移的 `createWindow` 调用，已通过批量替换修复。

### 定位方法
- surface 泄漏/未注册：检查 `WindowReference` 的 init 和 close handler 包装逻辑，以及 `WindowGroupNode`/`WindowNode` 的显式注册点。
- 后端接口不匹配：确认后端已实现 `CanvasSurface` 而非旧 `Windowing` 协议。

---

## 状态管理（DynamicPropertyUpdater / StateImpl / Publisher）

### 模块职责
`DynamicPropertyUpdater` 通过字节偏移或 Mirror 发现视图中的动态属性；`StateImpl` 管理 `@State` 的存储与变更通知；`Publisher` 负责变更广播。

### 核心契约
- 全局 `updaterCache: [ObjectIdentifier: Any]` 按类型缓存 `DynamicPropertyUpdater`，无逐出策略。
- `StateImpl` 内部通过 `Box<Storage>` 实现可变性。
- `Publisher.observations` 为普通字典，无并发访问保护。
- `ObservableObjectPublisherStore` 以 `ObjectIdentifier` 为键缓存发布者，不清理 `owner == nil` 的僵尸条目。
- `ViewModelObserver` 采用双轨策略：`withObservationTracking` 优先，`withPerceptionTracking` 兜底。

### 约束与陷阱
- **Mirror 回退极慢**：当字节偏移发现失败时，每次 `update` 回退到 `Mirror` 遍历；0 个属性时比字节偏移慢约 1500 倍，4 个属性时仍慢约 9 倍。更糟的是，一旦失败会被永久缓存为 `nil`，后续永远走 Mirror。
- **状态变更未批量合并**：同一事务内多次 `@State` 赋值均触发 `didChange.send()`，经 `GraphUpdateHost` 合并但仍增加队列压力。
- **Box 间接引用**：每次 `wrappedValue` 读取多一次指针解引用，高频布局计算中累积。
- **Publisher 线程不安全**：`send()` 遍历 `observations` 时若另一线程调用 `observe(with:)` 修改字典，会导致枚举突变崩溃或回调异常。
- **ObservableObjectPublisherStore 泄漏**：`entries` 字典中的 `Entry.owner` 为弱引用，但字典从不清理已销毁对象留下的条目；在大量创建/销毁 `@StateObject` 的场景（如 `ForEach` 内）内存持续膨胀。
- **ViewModelObserver 静默丢变更**：`observe` 被连续调用时，前一次跟踪的 `onChange` 若在下一次 `beginTracking` 之后才触发，会因 `trackingGeneration` 失效而被直接忽略，导致 UI 与状态不同步。
- **Binding 无等值去重**：`Binding.setValue` 即使新值与旧值相等也会走完整 `didChange` → `enqueueBottomUpUpdate` → `computeLayout` 链。
- **GraphUpdateHost flush 顺序风险**：`flushTransactions` 达到 8 次上限后剩余事务延迟执行；`isFlushingTransactions` 标志清除前的新 `enqueue` 会被标记为 deferred，快速连续手势下容易更新堆积。

---

## GtkCodeGen GIR→Swift 绑定生成器

### 模块职责
将 GObject Introspection（GIR）XML 文件自动转换为 Swift 类绑定，支撑 `Gtk`、`Gdk`、`Pango` 等原生库的 Swift 调用层。

### 入口与出口
- **入口**：`GtkCodeGen` 可执行目标，解析命令行指定的 `.gir` 文件路径。
- **出口**：批量生成的 Swift 源文件（通常数百个），组成 `Sources/Gtk/` 等目标。
- **关键文件**：`Sources/GtkCodeGen/GtkCodeGen.swift`（主生成逻辑）、`Sources/GtkCodeGen/GIR.swift`（GIR XML 解析）。

### 核心契约
- 读取 `.gir` 中的类、方法、信号、属性定义，映射为 Swift `class` + `@gir` 风格方法。
- 生成的 Swift 目标依赖对应的 `C*` systemLibrary（如 `Gtk` 依赖 `CGtk`）。

### 约束与陷阱
- **命名空间隔离**：不同 GIR 的命名空间不同（如 `Gtk` vs `Adw`），生成逻辑需适配前缀与模块名。
- **版本敏感**：GIR 文件随原生库版本变化，升级 GTK/libadwaita 后需重新生成绑定，可能引入 API 差异。
- **C 头文件前置条件**：生成绑定前必须确保系统已安装对应 `devel` 包并提供 `.gir` 文件（通常位于 `/usr/share/gir-1.0/`）。

### 定位方法
- 若新增原生库（如 libadwaita）需要 Swift 调用，首先检查系统是否提供 `Adw-1.gir`，然后复用 `GtkCodeGen` 生成新模块，而非手写绑定。

---

## 导航系统（自研统一路径）

### 模块职责
`NavigationStack`、`NavigationBar` 及配套导航基础设施，以完全自研方式实现跨平台统一的页面堆栈管理，不依赖任何后端原生导航控制器。

### 入口与出口
- **主入口**：`NavigationStack`（`Sources/SwiftCrossUI/Views/NavigationStack.swift`）——视图声明层。
- **渲染入口**：`NavigationBar`（`Sources/SwiftCrossUI/Views/NavigationBar.swift`）——自绘标题栏与返回按钮。
- **无后端协议出口**：原生 `NavigationStacks.swift` 后端协议及 UIKit/AppKit/Gtk 三端原生实现已全部删除，所有后端共享同一自研路径。

### 核心契约
- 页面堆栈、标题栏、返回按钮、过渡动画均由框架层自行管理。
- `WindowChromeView`（`Sources/SwiftCrossUI/Views/WindowChromeView.swift`）为桌面端自绘窗口装饰提供基础。
- `NavigationPath` 内部表示未被修改，Codable 兼容性保持现状。

### 约束与陷阱
- **状态保留**：pop 后节点是否隐藏保留（节点池化）取决于 `NavigationStackChildren` 的实现细节，需回归验证。
- **动画衔接**：自研路径与现有 `ViewGraph` 更新/动画体系直接衔接，但页面切换动画需自行实现，不能免费获得平台原生过渡。
- **原生优化缺失**：当前无侧滑返回手势、无平台原生导航栏外观；未来可增量添加，但基础路径保持自研。

### 定位方法
- 导航相关问题直接查看 `NavigationStack.swift` / `NavigationBar.swift`，无需再检查后端原生实现文件（已删除）。
- 若不同后端导航行为不一致，属于回归缺陷（统一路径下所有后端应表现一致）。

---

## WindowManager 与窗口生命周期

### 模块职责
`WindowManager`（`Sources/SwiftCrossUI/Scenes/WindowManager.swift`）管理应用 surfaces 的生命周期注册表；`WindowReference`、`WindowGroupNode`、`WindowNode` 负责实际窗口的创建、更新与关闭。

### 入口与出口
- **注册入口**：`WindowManager.shared.registerSurface(_:)` / `unregisterSurface(_:)`
- **引用层**：`WindowReference.init` 注册 surface 到 WindowManager；close handler 中注销。
- **场景层**：`WindowGroupNode`、`WindowNode` 在创建 `WindowReference` 后也显式调用 `registerSurface`（允许重复注册，字典覆盖）。

### 核心契约
- `WindowManager` 以 `ObjectIdentifier` 为键维护 `surfaces` 字典，跟踪当前活跃的 surface 数量。
- `CanvasSurface` 协议（原 `CoreWindowing`）已精简为最小接口：`createSurface`、`show`、`close`、`setSize`、`setResizeHandler`、`setChild`、`setCloseHandler` 等。
- 所有后端（AppKit、Gtk、Gtk3、WinUI、Dummy）均已完成 Surface API 迁移。

### 约束与陷阱
- **重复注册安全**：`WindowReference.init` 和 `WindowGroupNode`/`WindowNode` 都会调用 `registerSurface`，但字典覆盖行为保证安全。
- **注销时序**：`WindowReference` 的 close handler 包装了外部传入的 `closeHandler`，确保先 `unregisterSurface` 再执行外部逻辑。
- **旧 API 残留**：测试代码中可能存在未迁移的 `createWindow` 调用，已通过批量替换修复。

### 定位方法
- surface 泄漏/未注册：检查 `WindowReference` 的 init 和 close handler 包装逻辑，以及 `WindowGroupNode`/`WindowNode` 的显式注册点。
- 后端接口不匹配：确认后端已实现 `CanvasSurface` 而非旧 `Windowing` 协议。

---

## ViewGraph 类型擦除（AnyViewGraphNode / ErasedViewGraphNode）

### 模块职责
隐藏视图节点的具体 `View` 与 `Backend` 泛型，实现同质存储与遍历。

### 核心契约
- `AnyViewGraphNode` 存储 8 个类型擦除闭包（`_computeLayoutWithNewView`、`_commit` 等）。
- `ErasedViewGraphNode` 在 `AnyViewGraphNode` 之上再做一层擦除。

### 约束与陷阱
- **双重类型擦除开销**：`ViewGraphNode<V, Backend>` → `AnyViewGraphNode<V>` → `ErasedViewGraphNode`，高频 `computeLayoutWithNewView` 需穿越两层闭包派发，无法内联。
- **`AnyWidget` 批量转换**：`ViewGraphNodeChildren` 扩展中 `widgets.map { $0.into() }` 每次获取子 widget 列表都执行 O(n) 类型转换。

---

## GtkCodeGen GIR→Swift 绑定生成器

### 模块职责
将 GObject Introspection（GIR）XML 文件自动转换为 Swift 类绑定，支撑 `Gtk`、`Gdk`、`Pango` 等原生库的 Swift 调用层。

### 入口与出口
- **入口**：`GtkCodeGen` 可执行目标，解析命令行指定的 `.gir` 文件路径。
- **出口**：批量生成的 Swift 源文件（通常数百个），组成 `Sources/Gtk/` 等目标。
- **关键文件**：`Sources/GtkCodeGen/GtkCodeGen.swift`（主生成逻辑）、`Sources/GtkCodeGen/GIR.swift`（GIR XML 解析）。

### 核心契约
- 读取 `.gir` 中的类、方法、信号、属性定义，映射为 Swift `class` + `@gir` 风格方法。
- 生成的 Swift 目标依赖对应的 `C*` systemLibrary（如 `Gtk` 依赖 `CGtk`）。

### 约束与陷阱
- **命名空间隔离**：不同 GIR 的命名空间不同（如 `Gtk` vs `Adw`），生成逻辑需适配前缀与模块名。
- **版本敏感**：GIR 文件随原生库版本变化，升级 GTK/libadwaita 后需重新生成绑定，可能引入 API 差异。
- **C 头文件前置条件**：生成绑定前必须确保系统已安装对应 `devel` 包并提供 `.gir` 文件（通常位于 `/usr/share/gir-1.0/`）。

### 定位方法
- 若新增原生库（如 libadwaita）需要 Swift 调用，首先检查系统是否提供 `Adw-1.gir`，然后复用 `GtkCodeGen` 生成新模块，而非手写绑定。

---

## 导航系统（自研统一路径）

### 模块职责
`NavigationStack`、`NavigationBar` 及配套导航基础设施，以完全自研方式实现跨平台统一的页面堆栈管理，不依赖任何后端原生导航控制器。

### 入口与出口
- **主入口**：`NavigationStack`（`Sources/SwiftCrossUI/Views/NavigationStack.swift`）——视图声明层。
- **渲染入口**：`NavigationBar`（`Sources/SwiftCrossUI/Views/NavigationBar.swift`）——自绘标题栏与返回按钮。
- **无后端协议出口**：原生 `NavigationStacks.swift` 后端协议及 UIKit/AppKit/Gtk 三端原生实现已全部删除，所有后端共享同一自研路径。

### 核心契约
- 页面堆栈、标题栏、返回按钮、过渡动画均由框架层自行管理。
- `WindowChromeView`（`Sources/SwiftCrossUI/Views/WindowChromeView.swift`）为桌面端自绘窗口装饰提供基础。
- `NavigationPath` 内部表示未被修改，Codable 兼容性保持现状。

### 约束与陷阱
- **状态保留**：pop 后节点是否隐藏保留（节点池化）取决于 `NavigationStackChildren` 的实现细节，需回归验证。
- **动画衔接**：自研路径与现有 `ViewGraph` 更新/动画体系直接衔接，但页面切换动画需自行实现，不能免费获得平台原生过渡。
- **原生优化缺失**：当前无侧滑返回手势、无平台原生导航栏外观；未来可增量添加，但基础路径保持自研。

### 定位方法
- 导航相关问题直接查看 `NavigationStack.swift` / `NavigationBar.swift`，无需再检查后端原生实现文件（已删除）。
- 若不同后端导航行为不一致，属于回归缺陷（统一路径下所有后端应表现一致）。

---

## WindowManager 与窗口生命周期

### 模块职责
`WindowManager`（`Sources/SwiftCrossUI/Scenes/WindowManager.swift`）管理应用 surfaces 的生命周期注册表；`WindowReference`、`WindowGroupNode`、`WindowNode` 负责实际窗口的创建、更新与关闭。

### 入口与出口
- **注册入口**：`WindowManager.shared.registerSurface(_:)` / `unregisterSurface(_:)`
- **引用层**：`WindowReference.init` 注册 surface 到 WindowManager；close handler 中注销。
- **场景层**：`WindowGroupNode`、`WindowNode` 在创建 `WindowReference` 后也显式调用 `registerSurface`（允许重复注册，字典覆盖）。

### 核心契约
- `WindowManager` 以 `ObjectIdentifier` 为键维护 `surfaces` 字典，跟踪当前活跃的 surface 数量。
- `CanvasSurface` 协议（原 `CoreWindowing`）已精简为最小接口：`createSurface`、`show`、`close`、`setSize`、`setResizeHandler`、`setChild`、`setCloseHandler` 等。
- 所有后端（AppKit、Gtk、Gtk3、WinUI、Dummy）均已完成 Surface API 迁移。

### 约束与陷阱
- **重复注册安全**：`WindowReference.init` 和 `WindowGroupNode`/`WindowNode` 都会调用 `registerSurface`，但字典覆盖行为保证安全。
- **注销时序**：`WindowReference` 的 close handler 包装了外部传入的 `closeHandler`，确保先 `unregisterSurface` 再执行外部逻辑。
- **旧 API 残留**：测试代码中可能存在未迁移的 `createWindow` 调用，已通过批量替换修复。

### 定位方法
- surface 泄漏/未注册：检查 `WindowReference` 的 init 和 close handler 包装逻辑，以及 `WindowGroupNode`/`WindowNode` 的显式注册点。
- 后端接口不匹配：确认后端已实现 `CanvasSurface` 而非旧 `Windowing` 协议。

---

## GtkBackend 渲染与测量

### 模块职责
Linux GTK 后端，将 SwiftCrossUI 的布局结果映射到 GTK widget，并处理文本测量、图像渲染、路径绘制。

### 核心契约
- 使用 GTK `Fixed` 容器手动管理所有子 widget 位置。
- 文本测量通过创建临时 `Pango` 对象完成。
- 图像更新通过 `UnsafeMutableBufferPointer<UInt8>` + `gdk_pixbuf_new_from_data` 完成。

### 约束与陷阱
- **Pango 对象重复创建**：每次 `size(of text:)` 都新建 Pango 上下文与布局；文本测量在布局中极高频，对象创建成本高昂。
- **图片像素缓冲区重复分配**：`updateImageView` 每次更新都分配新 buffer 并拷贝像素，动画/实时图像场景压力巨大。
- **Cairo 模式重复创建**：`renderPath` 每次调用 `cairo_pattern_create_rgba`，频繁重绘时 C 对象分配成为瓶颈。
- **CSS 字符串拼接**：`updatePicker` 每次构建 `CSSBlock` 并拼接字符串更新样式，频繁主题更新时开销显著。
- **Fixed 容器不参与原生布局**：所有位置由 SwiftCrossUI 计算后手动 `setPosition`，GTK 无法利用内部布局缓存，且每次设置触发重新测量/绘制。

---

## GtkCodeGen GIR→Swift 绑定生成器

### 模块职责
将 GObject Introspection（GIR）XML 文件自动转换为 Swift 类绑定，支撑 `Gtk`、`Gdk`、`Pango` 等原生库的 Swift 调用层。

### 入口与出口
- **入口**：`GtkCodeGen` 可执行目标，解析命令行指定的 `.gir` 文件路径。
- **出口**：批量生成的 Swift 源文件（通常数百个），组成 `Sources/Gtk/` 等目标。
- **关键文件**：`Sources/GtkCodeGen/GtkCodeGen.swift`（主生成逻辑）、`Sources/GtkCodeGen/GIR.swift`（GIR XML 解析）。

### 核心契约
- 读取 `.gir` 中的类、方法、信号、属性定义，映射为 Swift `class` + `@gir` 风格方法。
- 生成的 Swift 目标依赖对应的 `C*` systemLibrary（如 `Gtk` 依赖 `CGtk`）。

### 约束与陷阱
- **命名空间隔离**：不同 GIR 的命名空间不同（如 `Gtk` vs `Adw`），生成逻辑需适配前缀与模块名。
- **版本敏感**：GIR 文件随原生库版本变化，升级 GTK/libadwaita 后需重新生成绑定，可能引入 API 差异。
- **C 头文件前置条件**：生成绑定前必须确保系统已安装对应 `devel` 包并提供 `.gir` 文件（通常位于 `/usr/share/gir-1.0/`）。

### 定位方法
- 若新增原生库（如 libadwaita）需要 Swift 调用，首先检查系统是否提供 `Adw-1.gir`，然后复用 `GtkCodeGen` 生成新模块，而非手写绑定。

---

## 导航系统（自研统一路径）

### 模块职责
`NavigationStack`、`NavigationBar` 及配套导航基础设施，以完全自研方式实现跨平台统一的页面堆栈管理，不依赖任何后端原生导航控制器。

### 入口与出口
- **主入口**：`NavigationStack`（`Sources/SwiftCrossUI/Views/NavigationStack.swift`）——视图声明层。
- **渲染入口**：`NavigationBar`（`Sources/SwiftCrossUI/Views/NavigationBar.swift`）——自绘标题栏与返回按钮。
- **无后端协议出口**：原生 `NavigationStacks.swift` 后端协议及 UIKit/AppKit/Gtk 三端原生实现已全部删除，所有后端共享同一自研路径。

### 核心契约
- 页面堆栈、标题栏、返回按钮、过渡动画均由框架层自行管理。
- `WindowChromeView`（`Sources/SwiftCrossUI/Views/WindowChromeView.swift`）为桌面端自绘窗口装饰提供基础。
- `NavigationPath` 内部表示未被修改，Codable 兼容性保持现状。

### 约束与陷阱
- **状态保留**：pop 后节点是否隐藏保留（节点池化）取决于 `NavigationStackChildren` 的实现细节，需回归验证。
- **动画衔接**：自研路径与现有 `ViewGraph` 更新/动画体系直接衔接，但页面切换动画需自行实现，不能免费获得平台原生过渡。
- **原生优化缺失**：当前无侧滑返回手势、无平台原生导航栏外观；未来可增量添加，但基础路径保持自研。

### 定位方法
- 导航相关问题直接查看 `NavigationStack.swift` / `NavigationBar.swift`，无需再检查后端原生实现文件（已删除）。
- 若不同后端导航行为不一致，属于回归缺陷（统一路径下所有后端应表现一致）。

---

## WindowManager 与窗口生命周期

### 模块职责
`WindowManager`（`Sources/SwiftCrossUI/Scenes/WindowManager.swift`）管理应用 surfaces 的生命周期注册表；`WindowReference`、`WindowGroupNode`、`WindowNode` 负责实际窗口的创建、更新与关闭。

### 入口与出口
- **注册入口**：`WindowManager.shared.registerSurface(_:)` / `unregisterSurface(_:)`
- **引用层**：`WindowReference.init` 注册 surface 到 WindowManager；close handler 中注销。
- **场景层**：`WindowGroupNode`、`WindowNode` 在创建 `WindowReference` 后也显式调用 `registerSurface`（允许重复注册，字典覆盖）。

### 核心契约
- `WindowManager` 以 `ObjectIdentifier` 为键维护 `surfaces` 字典，跟踪当前活跃的 surface 数量。
- `CanvasSurface` 协议（原 `CoreWindowing`）已精简为最小接口：`createSurface`、`show`、`close`、`setSize`、`setResizeHandler`、`setChild`、`setCloseHandler` 等。
- 所有后端（AppKit、Gtk、Gtk3、WinUI、Dummy）均已完成 Surface API 迁移。

### 约束与陷阱
- **重复注册安全**：`WindowReference.init` 和 `WindowGroupNode`/`WindowNode` 都会调用 `registerSurface`，但字典覆盖行为保证安全。
- **注销时序**：`WindowReference` 的 close handler 包装了外部传入的 `closeHandler`，确保先 `unregisterSurface` 再执行外部逻辑。
- **旧 API 残留**：测试代码中可能存在未迁移的 `createWindow` 调用，已通过批量替换修复。

### 定位方法
- surface 泄漏/未注册：检查 `WindowReference` 的 init 和 close handler 包装逻辑，以及 `WindowGroupNode`/`WindowNode` 的显式注册点。
- 后端接口不匹配：确认后端已实现 `CanvasSurface` 而非旧 `Windowing` 协议。

---

## ForEach 与动态子视图

### 模块职责
管理由数据集合驱动的动态子视图（`ForEach`），负责节点复用、差异更新与布局。

### 核心契约
- `ForEachViewChildren` 同时维护 `nodes`、`identifierMap`、`identifiers`、`items`、`activeKeys`、`renderKeys`、`committedRenderKeys`、`removalLayoutKeys`、`layoutableKeys`、`layoutableChildren`、`removalLayoutableChildren`、`widgets`、`erasedNodes` 等 12+ 集合。
- 每次 `computeLayout` 创建 `newActiveKeys`、`newActiveKeySet`、`occurrenceCounts`、`warnedDuplicateIdentifiers` 等临时对象，并为每个元素新建 `AnyView(childContent)` 与 `ErasedViewGraphNode`。

### 约束与陷阱
- **临时对象风暴**：列表滚动或数据刷新时，大量短期对象给 ARC 与堆分配器带来压力；`AnyView` 与 `ErasedViewGraphNode` 创建尤其昂贵。
- **多集合同步风险**：12+ 集合冗余存储，更新时需同步，内存占用高且逻辑复杂。

---

## GtkCodeGen GIR→Swift 绑定生成器

### 模块职责
将 GObject Introspection（GIR）XML 文件自动转换为 Swift 类绑定，支撑 `Gtk`、`Gdk`、`Pango` 等原生库的 Swift 调用层。

### 入口与出口
- **入口**：`GtkCodeGen` 可执行目标，解析命令行指定的 `.gir` 文件路径。
- **出口**：批量生成的 Swift 源文件（通常数百个），组成 `Sources/Gtk/` 等目标。
- **关键文件**：`Sources/GtkCodeGen/GtkCodeGen.swift`（主生成逻辑）、`Sources/GtkCodeGen/GIR.swift`（GIR XML 解析）。

### 核心契约
- 读取 `.gir` 中的类、方法、信号、属性定义，映射为 Swift `class` + `@gir` 风格方法。
- 生成的 Swift 目标依赖对应的 `C*` systemLibrary（如 `Gtk` 依赖 `CGtk`）。

### 约束与陷阱
- **命名空间隔离**：不同 GIR 的命名空间不同（如 `Gtk` vs `Adw`），生成逻辑需适配前缀与模块名。
- **版本敏感**：GIR 文件随原生库版本变化，升级 GTK/libadwaita 后需重新生成绑定，可能引入 API 差异。
- **C 头文件前置条件**：生成绑定前必须确保系统已安装对应 `devel` 包并提供 `.gir` 文件（通常位于 `/usr/share/gir-1.0/`）。

### 定位方法
- 若新增原生库（如 libadwaita）需要 Swift 调用，首先检查系统是否提供 `Adw-1.gir`，然后复用 `GtkCodeGen` 生成新模块，而非手写绑定。

---

## 导航系统（自研统一路径）

### 模块职责
`NavigationStack`、`NavigationBar` 及配套导航基础设施，以完全自研方式实现跨平台统一的页面堆栈管理，不依赖任何后端原生导航控制器。

### 入口与出口
- **主入口**：`NavigationStack`（`Sources/SwiftCrossUI/Views/NavigationStack.swift`）——视图声明层。
- **渲染入口**：`NavigationBar`（`Sources/SwiftCrossUI/Views/NavigationBar.swift`）——自绘标题栏与返回按钮。
- **无后端协议出口**：原生 `NavigationStacks.swift` 后端协议及 UIKit/AppKit/Gtk 三端原生实现已全部删除，所有后端共享同一自研路径。

### 核心契约
- 页面堆栈、标题栏、返回按钮、过渡动画均由框架层自行管理。
- `WindowChromeView`（`Sources/SwiftCrossUI/Views/WindowChromeView.swift`）为桌面端自绘窗口装饰提供基础。
- `NavigationPath` 内部表示未被修改，Codable 兼容性保持现状。

### 约束与陷阱
- **状态保留**：pop 后节点是否隐藏保留（节点池化）取决于 `NavigationStackChildren` 的实现细节，需回归验证。
- **动画衔接**：自研路径与现有 `ViewGraph` 更新/动画体系直接衔接，但页面切换动画需自行实现，不能免费获得平台原生过渡。
- **原生优化缺失**：当前无侧滑返回手势、无平台原生导航栏外观；未来可增量添加，但基础路径保持自研。

### 定位方法
- 导航相关问题直接查看 `NavigationStack.swift` / `NavigationBar.swift`，无需再检查后端原生实现文件（已删除）。
- 若不同后端导航行为不一致，属于回归缺陷（统一路径下所有后端应表现一致）。

---

## WindowManager 与窗口生命周期

### 模块职责
`WindowManager`（`Sources/SwiftCrossUI/Scenes/WindowManager.swift`）管理应用 surfaces 的生命周期注册表；`WindowReference`、`WindowGroupNode`、`WindowNode` 负责实际窗口的创建、更新与关闭。

### 入口与出口
- **注册入口**：`WindowManager.shared.registerSurface(_:)` / `unregisterSurface(_:)`
- **引用层**：`WindowReference.init` 注册 surface 到 WindowManager；close handler 中注销。
- **场景层**：`WindowGroupNode`、`WindowNode` 在创建 `WindowReference` 后也显式调用 `registerSurface`（允许重复注册，字典覆盖）。

### 核心契约
- `WindowManager` 以 `ObjectIdentifier` 为键维护 `surfaces` 字典，跟踪当前活跃的 surface 数量。
- `CanvasSurface` 协议（原 `CoreWindowing`）已精简为最小接口：`createSurface`、`show`、`close`、`setSize`、`setResizeHandler`、`setChild`、`setCloseHandler` 等。
- 所有后端（AppKit、Gtk、Gtk3、WinUI、Dummy）均已完成 Surface API 迁移。

### 约束与陷阱
- **重复注册安全**：`WindowReference.init` 和 `WindowGroupNode`/`WindowNode` 都会调用 `registerSurface`，但字典覆盖行为保证安全。
- **注销时序**：`WindowReference` 的 close handler 包装了外部传入的 `closeHandler`，确保先 `unregisterSurface` 再执行外部逻辑。
- **旧 API 残留**：测试代码中可能存在未迁移的 `createWindow` 调用，已通过批量替换修复。

### 定位方法
- surface 泄漏/未注册：检查 `WindowReference` 的 init 和 close handler 包装逻辑，以及 `WindowGroupNode`/`WindowNode` 的显式注册点。
- 后端接口不匹配：确认后端已实现 `CanvasSurface` 而非旧 `Windowing` 协议。

---

## 导航系统（NavigationStack / NavigationLink / NavigationSplitView）

### 模块职责
提供跨平台导航堆栈、路径管理与分栏视图，目标是 API 与 SwiftUI 一致并最大化复用各平台原生导航组件。

### 入口与出口
- **公共入口**：`NavigationStack(path:root:)`、`NavigationLink(value:label:)`、`NavigationSplitView`
- **后端协议**：`BackendFeatures.Containers.NavigationStacks`
- **后端实现**：`UIKitBackend+NavigationStack`、`AppKitBackend+NavigationStack`、`GtkBackend+NavigationStack`

### 核心契约
- `NavigationStack` 当前通过递归嵌套 `EitherView` 实现多目的地类型安全：`EitherView<EitherView<..., A>, B>`。`navigationDestination(for:)` 每注册一个目的地就嵌套一层。
- `NavigationStackChildren.synchronizeChildren` 直接按数组索引增删节点，pop 时销毁、push 时重建，无状态保留。
- `NavigationPath` 使用 `String(reflecting:)` 类型名匹配 + `JSONDecoder` 解码每条路径条目。
- `readObservationDependencies` 仅追踪当前可见页面（栈顶）的依赖。

### 约束与陷阱
- **EitherView 递归开销**：目的地增多时类型嵌套深度线性增长，`childOrCrash(for:)` 的闭包调用链随之增长；泛型结构膨胀增加编译时间与二进制体积。
- **页面状态不保留**：pop 后 view graph node 被销毁，页面内 `@State`、滚动位置等完全丢失；重新 push 相同数据也是全新重建。
- **NavigationPath 序列化冗余**：每次访问路径都要字符串比较类型名；持久化恢复时所有历史条目一次性 JSON 解码；类型重命名会导致路径永久失效。
- **深层页面观察缺失**：非栈顶页面若使用 `@Observable`/`@State`，其变更不会触发导航栈更新，后台状态变更是被忽略的。
- **后端复用参差不齐**：
  - UIKit：已使用 `UINavigationController`，但 `setPages` 全量比较 `viewControllers` 引用，复杂度 O(n)。
  - AppKit：完全未使用原生导航语义，仅手动 `addSubview`/`removeFromSuperview` 切换视图；无导航标题动画、无工具栏过渡、无后退手势。
  - Gtk：使用 `Gtk.Stack` 做简单 slide 过渡，但非导航控制器；无后退按钮、无标题栏、无手势返回；旧页面清理与新页面添加未批量处理。
- **NavigationLink 功能缺失**：只是 `Button` 包装器调用 `path.append`；不支持自动关联最近 `NavigationStack`、不支持任意 `View` 标签、不支持导航手势。
- **NavigationSplitView 无原生映射**：仅是对 `SplitView` 的简单包装，无 iPadOS/macOS 的侧边栏折叠/展开、列宽自适应、详情列替换等原生行为。
