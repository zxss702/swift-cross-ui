/// The placement of a toolbar in the window hierarchy, mirroring SwiftUI's
/// `ToolbarPlacement`.
public struct ToolbarPlacement: Sendable, Hashable {
    enum Kind: Sendable, Hashable {
        case automatic
        case windowToolbar
        case navigationBar
        case bottomBar
        case tabBar
        case statusBar
        case sidebar
    }
    var kind: Kind

    /// The system-chosen placement.
    public static let automatic = ToolbarPlacement(kind: .automatic)
    /// The toolbar attached to the window frame.
    public static let windowToolbar = ToolbarPlacement(kind: .windowToolbar)
    /// A navigation-bar placement.
    public static let navigationBar = ToolbarPlacement(kind: .navigationBar)
    /// A bottom-bar placement.
    public static let bottomBar = ToolbarPlacement(kind: .bottomBar)
    /// A tab-bar placement.
    public static let tabBar = ToolbarPlacement(kind: .tabBar)
    /// A status-bar placement.
    public static let statusBar = ToolbarPlacement(kind: .statusBar)
    /// A sidebar placement.
    public static let sidebar = ToolbarPlacement(kind: .sidebar)
}

extension EnvironmentValues {
    /// The toolbar's background visibility per placement, if customized.
    @Entry @_spi(Backends) public var toolbarBackgroundVisibility: Visibility? = nil

    /// The visibility of toolbars, if customized.
    @Entry @_spi(Backends) public var toolbarVisibility: Visibility? = nil

    /// Whether the navigation back button is hidden.
    @Entry @_spi(Backends) public var navigationBarBackButtonHidden: Bool = false
}

extension View {
    /// Sets the visibility of the background behind the given toolbars.
    ///
    /// Recorded in the environment; backends apply it when rendering window
    /// toolbars (backend support pending).
    public func toolbarBackground(
        _ visibility: Visibility,
        for bars: ToolbarPlacement...
    ) -> some View {
        environment(\.toolbarBackgroundVisibility, visibility)
    }

    /// Sets the style of the background behind the given toolbars.
    ///
    /// Recorded in the environment; backends apply it when rendering window
    /// toolbars (backend support pending).
    public func toolbarBackground<S: ShapeStyle>(
        _ style: S,
        for bars: ToolbarPlacement...
    ) -> some View {
        environment(\.toolbarBackgroundVisibility, .visible)
    }

    /// Sets the visibility of the given toolbars.
    ///
    /// Recorded in the environment; backends apply it when rendering window
    /// toolbars (backend support pending).
    public func toolbarVisibility(
        _ visibility: Visibility,
        for bars: ToolbarPlacement...
    ) -> some View {
        environment(\.toolbarVisibility, visibility)
    }

    /// Hides the navigation bar's back button while this view is displayed.
    ///
    /// Environment values only propagate down, so the request can't reach an
    /// enclosing navigation stack directly. Instead the modifier wraps the
    /// view in a ``WindowChromeBackHiddenAttachment`` that publishes the
    /// request into the window chrome — the same channel ``navigationTitle``
    /// uses. The environment value is still written for nested readers.
    public func navigationBarBackButtonHidden(_ hidden: Bool = true) -> some View {
        WindowChromeBackHiddenAttachment(
            content: environment(\.navigationBarBackButtonHidden, hidden),
            hidden: hidden
        )
    }
}
