import Foundation

/// A scene that presents a group of identically structured windows.
public struct WindowGroup<Content: View>: WindowingScene {
    public typealias Node = WindowGroupNode<Content>

    /// The title of the window (shown in the title bar on most OSes).
    var title: String
    /// The window's content.
    var content: () -> Content
    /// The window's ID.
    ///
    /// This should never change after creation.
    let id: String?

    /// The type of value this group presents, if it was created with
    /// ``WindowGroup/init(for:id:content:)``.
    var valueType: Any.Type?
    /// Produces a content closure bound to a freshly presented value.
    var contentForValue: ((Any) -> () -> Content)?

    /// Creates a window group optionally specifying a title and an ID. Window title
    /// defaults to `ProcessInfo.processInfo.processName`.
    public init(
        _ title: String? = nil,
        id: String? = nil,
        @ViewBuilder _ content: @escaping () -> Content
    ) {
        #if os(WASI)
            let title = title ?? "Title"
        #else
            let title = title ?? ProcessInfo.processInfo.processName
        #endif
        self.id = id
        self.title = title
        self.content = content
        self.valueType = nil
        self.contentForValue = nil
    }

    /// Creates a window group that presents windows bound to a value of the
    /// given type, as in SwiftUI.
    ///
    /// Windows are opened via `openWindow(value:)`. Each opened window gets
    /// its own `Binding` seeded with the presented value.
    public init<D: Codable & Hashable, C: View>(
        for type: D.Type = D.self,
        id: String? = nil,
        @ViewBuilder content: @escaping (Binding<D?>) -> C
    ) where Content == C {
        #if os(WASI)
            let title = ProcessInfo.processInfo.processName
        #else
            let title = ProcessInfo.processInfo.processName
        #endif
        self.id = id
        self.title = title
        self.valueType = D.self
        self.contentForValue = { value in
            var stored = value as? D
            let binding = Binding<D?>(
                get: { stored },
                set: { stored = $0 }
            )
            return { content(binding) }
        }
        // Fallback content for programmatically opened (value-less) windows.
        self.content = {
            var stored: D? = nil
            return content(Binding(get: { stored }, set: { stored = $0 }))
        }
    }
}

/// The ``SceneGraphNode`` corresponding to a ``WindowGroup`` scene.
public final class WindowGroupNode<Content: View>: SceneGraphNode {
    public typealias NodeScene = WindowGroup<Content>

    /// The references to the underlying window objects, which also manage
    /// each window's view graph.
    ///
    /// Empty if there are currently no instances of the window.
    private var windowReferences: [UUID: WindowReference<WindowGroup<Content>>] = [:]

    /// The value each value-opened window was presented with, so that updates
    /// can rebuild the window's content binding from the latest scene instead
    /// of reverting it to the value-less fallback content.
    private var windowValues: [UUID: Any] = [:]

    /// The underlying scene.
    private var scene: WindowGroup<Content>

    public init<Backend: BaseAppBackend>(
        from scene: WindowGroup<Content>,
        backend: Backend,
        environment: EnvironmentValues
    ) {
        self.scene = scene

        let openOnAppLaunch =
            switch environment.defaultLaunchBehavior {
                case .automatic, .presented: true
                case .suppressed: false
            }

        if openOnAppLaunch {
            let windowID = UUID()
            self.windowReferences = [
                windowID: WindowReference(
                    scene: scene,
                    backend: backend,
                    environment: environment,
                    onClose: { self.windowReferences[windowID] = nil },
                    id: nextId()
                )
            ]
        }
    }

    private func nextId() -> String {
        // Vaguely based off the research covered by https://github.com/pd95/SwiftUI-macos-HandleWindow
        let baseId = scene.id ?? String(describing: Content.self)
        return "\(baseId)-\(windowReferences.count)"
    }

    public func updateNode(
        _ newScene: NodeScene?,
        environment: EnvironmentValues
    ) -> SceneNodeUpdateResult {
        if let newScene {
            self.scene = newScene
        }

        return .leafScene()
    }

    public func update<Backend: BaseAppBackend>(
        backend: Backend,
        environment: EnvironmentValues
    ) {
        if let id = scene.id {
            environment.openWindowFunctionsByID.value[id] = { [weak self] in
                guard let self else { return }

                let windowID = UUID()
                let reference = WindowReference(
                    scene: scene,
                    backend: backend,
                    environment: environment,
                    onClose: { self.windowReferences[windowID] = nil },
                    id: nextId()
                )
                windowReferences[windowID] = reference

                reference.update(
                    nil,
                    backend: backend,
                    environment: environment
                )
            }
        }

        if let valueType = scene.valueType, let contentForValue = scene.contentForValue {
            environment.openWindowFunctionsByValueType.value[ObjectIdentifier(valueType)] = {
                [weak self] value in
                guard let self else { return }

                var scene = scene
                scene.content = contentForValue(value)

                let windowID = UUID()
                let reference = WindowReference(
                    scene: scene,
                    backend: backend,
                    environment: environment,
                    onClose: {
                        self.windowReferences[windowID] = nil
                        self.windowValues[windowID] = nil
                    },
                    id: nextId()
                )
                windowReferences[windowID] = reference
                windowValues[windowID] = value

                reference.update(
                    nil,
                    backend: backend,
                    environment: environment
                )
            }
        }

        for (windowID, windowReference) in windowReferences {
            var windowScene = scene
            // Windows opened with a value keep their own bound content; rebuild
            // it from the latest scene so updates don't revert them to the
            // value-less fallback content.
            if let value = windowValues[windowID],
                let contentForValue = scene.contentForValue
            {
                windowScene.content = contentForValue(value)
            }
            windowReference.update(
                windowScene,
                backend: backend,
                environment: environment
            )
        }
    }
}
