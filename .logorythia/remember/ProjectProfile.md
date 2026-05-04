# 项目画像：swift-cross-ui

## 仓库基线信息

- **路径**：`file:///Volumes/知阳/开发/Packges/swift-cross-ui/`
- **类型**：Swift 包（SPM），跨平台 SwiftUI-like UI 框架
- **技术栈**：Swift 6，多后端（AppKit / UIKit / Gtk / WinUI / Terminal）

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
