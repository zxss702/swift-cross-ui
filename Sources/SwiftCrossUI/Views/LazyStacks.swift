/// The set of view kinds that remain pinned to the bounds of a scroll view.
public struct PinnedScrollableViews: OptionSet, Sendable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    /// Pin section headers to the bounds of the scroll view.
    public static let sectionHeaders = PinnedScrollableViews(rawValue: 1 << 0)

    /// Pin section footers to the bounds of the scroll view.
    public static let sectionFooters = PinnedScrollableViews(rawValue: 1 << 1)
}

/// A view that arranges its subviews vertically, creating items only as
/// needed.
///
/// When placed in a vertically scrolling ``ScrollView`` on a backend that
/// reports viewport changes, ``ForEach`` descendants materialize only the
/// elements near the visible region. On backends without viewport reporting
/// (or when not inside a ``ScrollView``) all items are materialized eagerly
/// like a ``VStack``.
public struct LazyVStack<Content: View>: View {
    private var alignment: HorizontalAlignment
    private var spacing: Double?
    private var content: Content

    /// Creates a lazy vertical stack.
    public init(
        alignment: HorizontalAlignment = .center,
        spacing: Double? = nil,
        pinnedViews: PinnedScrollableViews = [],
        @ViewBuilder content: () -> Content
    ) {
        self.alignment = alignment
        self.spacing = spacing
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: alignment, spacing: spacing) {
            content
        }
        .environment(\.lazyStackEnabled, true)
    }
}

/// A view that arranges its subviews horizontally, creating items only as
/// needed.
///
/// Items are currently materialized eagerly like an ``HStack``; true lazy
/// materialization requires scroll-view visibility tracking and is planned
/// for a future release.
public struct LazyHStack<Content: View>: View {
    private var alignment: VerticalAlignment
    private var spacing: Double?
    private var content: Content

    /// Creates a lazy horizontal stack.
    public init(
        alignment: VerticalAlignment = .center,
        spacing: Double? = nil,
        pinnedViews: PinnedScrollableViews = [],
        @ViewBuilder content: () -> Content
    ) {
        self.alignment = alignment
        self.spacing = spacing
        self.content = content()
    }

    public var body: some View {
        HStack(alignment: alignment, spacing: spacing) {
            content
        }
    }
}
