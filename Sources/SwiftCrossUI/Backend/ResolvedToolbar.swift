/// A backend-agnostic representation of toolbar content.
public struct ResolvedToolbar: Sendable {
    /// An empty toolbar.
    public static let empty = ResolvedToolbar(items: [])

    /// The toolbar's items in declaration order.
    public var items: [ResolvedToolbarItem]

    /// Creates a resolved toolbar.
    public init(items: [ResolvedToolbarItem]) {
        self.items = items
    }

    /// Returns a toolbar with `other`'s items appended after this toolbar's items.
    func overlayed(with other: ResolvedToolbar) -> ResolvedToolbar {
        ResolvedToolbar(items: items + other.items)
    }
}

/// A backend-agnostic representation of a single toolbar item.
public struct ResolvedToolbarItem: Sendable {
    /// The item's semantic placement.
    public var placement: ToolbarItemPlacement
    /// The item's content.
    public var content: Content

    /// Creates a resolved toolbar item.
    public init(placement: ToolbarItemPlacement, content: Content) {
        self.placement = placement
        self.content = content
    }

    /// The concrete content of a toolbar item.
    public enum Content: Sendable {
        /// A labelled button.
        case button(String, action: @Sendable @MainActor () -> Void)
        /// Static text.
        case text(String)
        /// Flexible or fixed spacing.
        case spacer(minLength: Int?)
        /// A separator.
        case separator
    }
}
