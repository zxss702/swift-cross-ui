/// An item in a native toolbar.
public struct ToolbarItem: Sendable {
    /// The item's semantic placement.
    public var placement: ToolbarItemPlacement
    /// The content represented by this toolbar item.
    var content: [ToolbarItemContent]

    /// Creates a toolbar item.
    public init(
        placement: ToolbarItemPlacement = .automatic,
        @ToolbarItemContentBuilder content: () -> [ToolbarItemContent]
    ) {
        self.placement = placement
        self.content = content()
    }

    init(placement: ToolbarItemPlacement, content: [ToolbarItemContent]) {
        self.placement = placement
        self.content = content
    }

    func resolve() -> [ResolvedToolbarItem] {
        content.map { item in
            ResolvedToolbarItem(
                placement: placement,
                content: item.resolve()
            )
        }
    }
}

/// A piece of content that can be rendered inside a toolbar item.
public enum ToolbarItemContent: Sendable {
    /// A labelled button.
    case button(String, action: @Sendable @MainActor () -> Void)
    /// Static text.
    case text(String)
    /// Flexible or fixed spacing.
    case spacer(minLength: Int?)
    /// A separator.
    case separator

    func resolve() -> ResolvedToolbarItem.Content {
        switch self {
            case .button(let label, let action):
                .button(label, action: action)
            case .text(let text):
                .text(text)
            case .spacer(let minLength):
                .spacer(minLength: minLength)
            case .separator:
                .separator
        }
    }
}

/// A group of toolbar items that share a placement.
public struct ToolbarItemGroup: Sendable {
    /// The group's semantic placement.
    public var placement: ToolbarItemPlacement
    /// The content represented by this toolbar item group.
    var content: [ToolbarItemContent]

    /// Creates a toolbar item group.
    public init(
        placement: ToolbarItemPlacement = .automatic,
        @ToolbarItemContentBuilder content: () -> [ToolbarItemContent]
    ) {
        self.placement = placement
        self.content = content()
    }
}

@MainActor
protocol ToolbarItemRepresentable {
    var asToolbarItems: [ToolbarItem] { get }
}

protocol ToolbarItemContentRepresentable: View {
    nonisolated var asToolbarItemContent: ToolbarItemContent { get }
}

extension ToolbarItem: ToolbarItemRepresentable {
    var asToolbarItems: [ToolbarItem] { [self] }
}

extension ToolbarItemGroup: ToolbarItemRepresentable {
    var asToolbarItems: [ToolbarItem] {
        content.map { ToolbarItem(placement: placement, content: [$0]) }
    }
}

extension Button: ToolbarItemRepresentable, ToolbarItemContentRepresentable {
    var asToolbarItems: [ToolbarItem] {
        [ToolbarItem { self }]
    }

    nonisolated var asToolbarItemContent: ToolbarItemContent {
        .button(label, action: action)
    }
}

extension Text: ToolbarItemContentRepresentable {
    nonisolated var asToolbarItemContent: ToolbarItemContent {
        .text(string)
    }
}

extension Spacer: ToolbarItemRepresentable, ToolbarItemContentRepresentable {
    var asToolbarItems: [ToolbarItem] {
        [ToolbarItem { self }]
    }

    nonisolated var asToolbarItemContent: ToolbarItemContent {
        .spacer(minLength: minLength)
    }
}

extension Divider: ToolbarItemRepresentable, ToolbarItemContentRepresentable {
    var asToolbarItems: [ToolbarItem] {
        [ToolbarItem { self }]
    }

    nonisolated var asToolbarItemContent: ToolbarItemContent {
        .separator
    }
}
