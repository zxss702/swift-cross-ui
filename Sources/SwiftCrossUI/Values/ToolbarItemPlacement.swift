/// A semantic location for an item in a native toolbar.
public enum ToolbarItemPlacement: Hashable, Sendable {
    /// Let the backend choose the most idiomatic placement.
    case automatic
    /// A navigation-related action, such as back, sidebar, or drawer control.
    case navigation
    /// Principal content, commonly used as the toolbar title.
    case principal
    /// The primary action for the current screen.
    case primaryAction
    /// An item in a bottom toolbar.
    case bottomBar
    /// An item at the leading edge of the top toolbar.
    case topBarLeading
    /// An item at the trailing edge of the top toolbar.
    case topBarTrailing
}
