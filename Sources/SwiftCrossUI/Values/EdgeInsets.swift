import Foundation

extension GeometryProxy {
    /// The safe-area insets applied to the view. Currently zero: backends
    /// report notches and system bars through this value when supported.
    public var safeAreaInsets: EdgeInsets {
        .init()
    }
}
