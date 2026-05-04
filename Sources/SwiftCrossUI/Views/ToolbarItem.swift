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
    /// Flexible or fixed spacing.
    case spacer(minLength: Int?)
    /// A separator.
    case separator

    func resolve() -> ResolvedToolbarItem.Content {
        switch self {
            case .button(let label, let action):
                .button(label, action: action)
            case .spacer(let minLength):
                .spacer(minLength: minLength)
            case .separator:
                .separator
        }
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

extension Button: ToolbarItemRepresentable, ToolbarItemContentRepresentable {
    var asToolbarItems: [ToolbarItem] {
        [ToolbarItem { self }]
    }

    nonisolated var asToolbarItemContent: ToolbarItemContent {
        .button(label, action: action)
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
