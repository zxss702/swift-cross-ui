import Foundation

/// Manages the lifecycle and chrome of application surfaces.
/// Desktop window decorations are drawn by SwiftCrossUI itself
/// rather than delegated to the backend.
@MainActor
final class WindowManager {
    /// Shared singleton for the active session.
    static let shared = WindowManager()

    private var surfaces: [ObjectIdentifier: Any] = [:]

    private init() {}

    /// Informs the manager that a new surface has been created.
    func registerSurface(_ surface: Any) {
        surfaces[ObjectIdentifier(surface as AnyObject)] = surface
    }

    /// Informs the manager that a surface has been closed.
    func unregisterSurface(_ surface: Any) {
        surfaces.removeValue(forKey: ObjectIdentifier(surface as AnyObject))
    }

    /// The number of currently registered surfaces.
    var registeredSurfaceCount: Int {
        surfaces.count
    }
}
