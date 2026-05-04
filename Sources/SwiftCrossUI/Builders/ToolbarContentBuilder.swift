/// A result builder for toolbar item declarations.
@resultBuilder
public struct ToolbarContentBuilder {
    @MainActor
    public static func buildBlock() -> [ToolbarItem] {
        []
    }

    @MainActor
    public static func buildPartialBlock(first: ToolbarItem) -> [ToolbarItem] {
        [first]
    }

    @MainActor
    public static func buildPartialBlock(first: some View) -> [ToolbarItem] {
        guard let first = first as? any ToolbarItemRepresentable else { return [] }
        return first.asToolbarItems
    }

    @MainActor
    public static func buildPartialBlock(first: Block) -> [ToolbarItem] {
        first.items
    }

    @MainActor
    public static func buildPartialBlock(
        accumulated: [ToolbarItem],
        next: ToolbarItem
    ) -> [ToolbarItem] {
        accumulated + buildPartialBlock(first: next)
    }

    @MainActor
    public static func buildPartialBlock(
        accumulated: [ToolbarItem],
        next: some View
    ) -> [ToolbarItem] {
        accumulated + buildPartialBlock(first: next)
    }

    @MainActor
    public static func buildPartialBlock(
        accumulated: [ToolbarItem],
        next: Block
    ) -> [ToolbarItem] {
        accumulated + buildPartialBlock(first: next)
    }

    @MainActor
    public static func buildOptional(_ component: [ToolbarItem]?) -> Block {
        Block(items: component ?? [])
    }

    @MainActor
    public static func buildEither(first component: [ToolbarItem]) -> Block {
        Block(items: component)
    }

    @MainActor
    public static func buildEither(second component: [ToolbarItem]) -> Block {
        Block(items: component)
    }

    /// An implementation detail of ``ToolbarContentBuilder``'s conditional support.
    public struct Block {
        var items: [ToolbarItem]
    }
}

/// A result builder for content inside a single ``ToolbarItem``.
@resultBuilder
public struct ToolbarItemContentBuilder {
    @MainActor
    public static func buildBlock() -> [ToolbarItemContent] {
        []
    }

    @MainActor
    public static func buildPartialBlock(first: some View) -> [ToolbarItemContent] {
        guard let first = first as? any ToolbarItemContentRepresentable else { return [] }
        return [first.asToolbarItemContent]
    }

    @MainActor
    public static func buildPartialBlock(first: Block) -> [ToolbarItemContent] {
        first.items
    }

    @MainActor
    public static func buildPartialBlock(
        accumulated: [ToolbarItemContent],
        next: some View
    ) -> [ToolbarItemContent] {
        accumulated + buildPartialBlock(first: next)
    }

    @MainActor
    public static func buildPartialBlock(
        accumulated: [ToolbarItemContent],
        next: Block
    ) -> [ToolbarItemContent] {
        accumulated + buildPartialBlock(first: next)
    }

    @MainActor
    public static func buildOptional(_ component: [ToolbarItemContent]?) -> Block {
        Block(items: component ?? [])
    }

    @MainActor
    public static func buildEither(first component: [ToolbarItemContent]) -> Block {
        Block(items: component)
    }

    @MainActor
    public static func buildEither(second component: [ToolbarItemContent]) -> Block {
        Block(items: component)
    }

    /// An implementation detail of ``ToolbarItemContentBuilder``'s conditional support.
    public struct Block {
        var items: [ToolbarItemContent]
    }
}
