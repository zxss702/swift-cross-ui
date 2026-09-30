import Foundation

/// An action that opens a window with the specified ID.
@MainActor
public struct OpenWindowAction {
    let environment: EnvironmentValues

    /// Opens the window with the specified ID.
    public func callAsFunction(id: String) {
        guard environment.backend.supportsMultipleWindows else {
            logger.warning(
                """
                openWindow(id:) called but the backend doesn't support \
                multi-window, ignoring
                """
            )
            return
        }

        guard let openWindow = environment.openWindowFunctionsByID.value[id] else {
            logger.warning(
                """
                openWindow(id:) called with an ID that does not have an \
                associated window
                """,
                metadata: ["id": "\(id)"]
            )
            return
        }
        openWindow()
    }

    /// Opens a window bound to the given value.
    ///
    /// The value is routed to the ``WindowGroup`` declared for the value's
    /// type; each opened window receives the value through its content
    /// binding.
    public func callAsFunction<D: Codable & Hashable>(value: D) {
        guard environment.backend.supportsMultipleWindows else {
            logger.warning(
                """
                openWindow(value:) called but the backend doesn't support \
                multi-window, ignoring
                """
            )
            return
        }

        guard let openWindow = environment.openWindowFunctionsByValueType
            .value[ObjectIdentifier(D.self)] else {
            logger.warning(
                """
                openWindow(value:) called with a value type that does not \
                have an associated window group
                """,
                metadata: ["type": "\(D.self)"]
            )
            return
        }
        if ProcessInfo.processInfo.environment["SY_PROBE"] != nil {
            FileHandle.standardError.write("[PROBE] openWindow(value:\(D.self)) dispatch\n".data(using: .utf8)!)
        }
        openWindow(value)
    }
}
