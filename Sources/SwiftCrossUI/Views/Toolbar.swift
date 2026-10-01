/// The placement of a toolbar item within a toolbar.
public enum ToolbarItemPlacement: Sendable, Hashable {
    /// The system chooses the placement.
    case automatic
    /// Primary actions, rendered on the trailing side.
    case primaryAction
    /// Confirmation actions ("Done", "Save"), trailing side.
    case confirmationAction
    /// Cancellation actions, leading side.
    case cancellationAction
    /// Destructive actions.
    case destructiveAction
    /// Navigation actions, leading side.
    case navigation
    /// Status items, centered.
    case status
    /// Items in a bottom bar.
    case bottomBar
    /// Explicit leading/trailing top bar placements.
    case topBarLeading
    case topBarTrailing

    var isLeading: Bool {
        switch self {
        case .navigation, .cancellationAction, .topBarLeading:
            true
        default:
            false
        }
    }
}

/// How much horizontal space a toolbar spacer occupies.
public enum ToolbarSpacerFlexibility: Sendable, Hashable {
    /// A fixed amount of space.
    case fixed
    /// A flexible amount of space.
    case flexible
}

/// A resolved toolbar entry: either an item view or a spacer.
public struct ResolvedToolbarItem {
    public enum Kind {
        case view(AnyView)
        case spacer(ToolbarSpacerFlexibility)
    }
    public var placement: ToolbarItemPlacement
    public var kind: Kind
}

/// A piece of toolbar content, produced by ``ToolbarContentBuilder``.
@MainActor
public protocol ToolbarContent {
    /// The type of content representing the body of this toolbar content.
    associatedtype Body: ToolbarContent

    /// The content of this toolbar element.
    @ToolbarContentBuilder var body: Body { get }

    /// The resolved items this content contributes to the toolbar.
    var _asToolbarItems: [ResolvedToolbarItem] { get }
}

extension ToolbarContent {
    public var _asToolbarItems: [ResolvedToolbarItem] {
        body._asToolbarItems
    }
}

extension Never: ToolbarContent {}

/// A toolbar item wrapping a single view.
public struct ToolbarItem<Content: View>: ToolbarContent {
    var placement: ToolbarItemPlacement
    var content: Content

    public var body: Never {
        fatalError("Rendered ToolbarItem")
    }

    public init(
        placement: ToolbarItemPlacement = .automatic,
        @ViewBuilder content: () -> Content
    ) {
        self.placement = placement
        self.content = content()
    }

    public var _asToolbarItems: [ResolvedToolbarItem] {
        [ResolvedToolbarItem(placement: placement, kind: .view(AnyView(content)))]
    }
}

/// A group of views placed together in the toolbar.
public struct ToolbarItemGroup<Content: View>: ToolbarContent {
    var placement: ToolbarItemPlacement
    var content: Content

    public var body: Never {
        fatalError("Rendered ToolbarItemGroup")
    }

    public init(
        placement: ToolbarItemPlacement = .automatic,
        @ViewBuilder content: () -> Content
    ) {
        self.placement = placement
        self.content = content()
    }

    public var _asToolbarItems: [ResolvedToolbarItem] {
        [ResolvedToolbarItem(placement: placement, kind: .view(AnyView(content)))]
    }
}

/// A spacer between toolbar items.
public struct ToolbarSpacer: ToolbarContent {
    var flexibility: ToolbarSpacerFlexibility
    var placement: ToolbarItemPlacement

    public var body: Never {
        fatalError("Rendered ToolbarSpacer")
    }

    public init(
        _ flexibility: ToolbarSpacerFlexibility = .flexible,
        placement: ToolbarItemPlacement = .automatic
    ) {
        self.flexibility = flexibility
        self.placement = placement
    }

    public var _asToolbarItems: [ResolvedToolbarItem] {
        [ResolvedToolbarItem(placement: placement, kind: .spacer(flexibility))]
    }
}

/// A toolbar content element combining multiple pieces.
public struct TupleToolbarContent: ToolbarContent {
    var items: [ResolvedToolbarItem]

    public var body: Never {
        fatalError("Rendered TupleToolbarContent")
    }

    public var _asToolbarItems: [ResolvedToolbarItem] { items }
}

/// Toolbar content for if/else branches.
public struct EitherToolbarContent<A: ToolbarContent, B: ToolbarContent>: ToolbarContent {
    enum Storage {
        case a(A)
        case b(B)
    }
    var storage: Storage

    public var body: Never {
        fatalError("Rendered EitherToolbarContent")
    }

    init(_ a: A) { storage = .a(a) }
    init(_ b: B) { storage = .b(b) }
    public var _asToolbarItems: [ResolvedToolbarItem] {
        switch storage {
        case .a(let a): a._asToolbarItems
        case .b(let b): b._asToolbarItems
        }
    }
}

/// Toolbar content produced by an `if` without `else`.
public struct OptionalToolbarContent<C: ToolbarContent>: ToolbarContent {
    var content: C?

    public var body: Never {
        fatalError("Rendered OptionalToolbarContent")
    }

    public var _asToolbarItems: [ResolvedToolbarItem] {
        content?._asToolbarItems ?? []
    }
}

/// A result builder for toolbar content.
@resultBuilder
@MainActor
public struct ToolbarContentBuilder {
    public static func buildBlock() -> TupleToolbarContent {
        TupleToolbarContent(items: [])
    }

    public static func buildBlock(_ content: (any ToolbarContent)...) -> TupleToolbarContent {
        TupleToolbarContent(items: content.flatMap(\._asToolbarItems))
    }

    /// Passes `Never` bodies through unchanged so primitive toolbar content
    /// can declare `var body: Never`.
    public static func buildBlock(_ content: Never) -> Never {
        content
    }

    public static func buildEither<A: ToolbarContent, B: ToolbarContent>(
        first component: A
    ) -> EitherToolbarContent<A, B> {
        EitherToolbarContent(component)
    }

    public static func buildEither<A: ToolbarContent, B: ToolbarContent>(
        second component: B
    ) -> EitherToolbarContent<A, B> {
        EitherToolbarContent(component)
    }

    public static func buildOptional<C: ToolbarContent>(
        _ component: C?
    ) -> OptionalToolbarContent<C> {
        OptionalToolbarContent(content: component)
    }

    public static func buildLimitedAvailability<C: ToolbarContent>(
        _ component: C
    ) -> C {
        component
    }
}

/// The horizontal bar that renders resolved toolbar items above a view's
/// content.
struct ToolbarBar: View {
    var items: [ResolvedToolbarItem]

    var body: some View {
        let leading = items.filter { $0.placement.isLeading }
        let trailing = items.filter { !$0.placement.isLeading }
        HStack(spacing: 8) {
            renderItems(leading)
            Spacer()
            renderItems(trailing)
        }
        .padding(4)
    }

    @ViewBuilder
    private func renderItems(_ items: [ResolvedToolbarItem]) -> some View {
        ForEach(Array(items.enumerated()), id: \.offset) { item in
            switch item.element.kind {
            case .view(let view):
                // Toolbar labels render icon-only, as on macOS.
                view.labelsHidden()
            case .spacer(.fixed):
                Spacer().frame(width: 16)
            case .spacer(.flexible):
                Spacer()
            }
        }
    }
}

extension View {
    /// Populates the toolbar of this view.
    ///
    /// On backends with integrated window chrome the items are rendered in
    /// the window's title-bar strip; otherwise they render as a horizontal
    /// bar above the content.
    public func toolbar<TB: ToolbarContent>(
        @ToolbarContentBuilder _ content: () -> TB
    ) -> some View {
        WindowChromeToolbarAttachment(
            content: self,
            items: content()._asToolbarItems
        )
    }
}
