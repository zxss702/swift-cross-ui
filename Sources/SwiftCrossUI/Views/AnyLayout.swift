/// A layout that places subviews in a horizontal or vertical stack,
/// mirroring SwiftUI's `Layout`-family conveniences.
public protocol Layout: Sendable {}

/// The layout of an ``HStack``.
public struct HStackLayout: Layout, Sendable {
    var alignment: VerticalAlignment
    var spacing: Double?

    public init(alignment: VerticalAlignment = .center, spacing: Double? = nil) {
        self.alignment = alignment
        self.spacing = spacing
    }
}

/// The layout of a ``VStack``.
public struct VStackLayout: Layout, Sendable {
    var alignment: HorizontalAlignment
    var spacing: Double?

    public init(alignment: HorizontalAlignment = .center, spacing: Double? = nil) {
        self.alignment = alignment
        self.spacing = spacing
    }
}

/// The layout of a ``ZStack``.
public struct ZStackLayout: Layout, Sendable {
    var alignment: Alignment

    public init(alignment: Alignment = .center) {
        self.alignment = alignment
    }
}

/// A type-erased layout, callable with content to produce the laid-out view.
public struct AnyLayout: Layout {
    enum Kind: Sendable {
        case hstack(alignment: VerticalAlignment, spacing: Double?)
        case vstack(alignment: HorizontalAlignment, spacing: Double?)
        case zstack(alignment: Alignment)
    }

    var kind: Kind

    public init<L: Layout>(_ layout: L) {
        switch layout {
        case let layout as HStackLayout:
            kind = .hstack(alignment: layout.alignment, spacing: layout.spacing)
        case let layout as VStackLayout:
            kind = .vstack(alignment: layout.alignment, spacing: layout.spacing)
        case let layout as ZStackLayout:
            kind = .zstack(alignment: layout.alignment)
        default:
            // Unrecognized layouts degrade to a center-aligned stack, matching
            // SwiftUI's behavior of routing unknown layouts through the same
            // call interface.
            kind = .vstack(alignment: .center, spacing: nil)
        }
    }

    /// Lays out content with this layout.
    @MainActor
    public func callAsFunction<Content: View>(
        @ViewBuilder _ content: () -> Content
    ) -> some View {
        switch kind {
        case .hstack(let alignment, let spacing):
            AnyView(HStack(alignment: alignment, spacing: spacing, content))
        case .vstack(let alignment, let spacing):
            AnyView(VStack(alignment: alignment, spacing: spacing, content: content))
        case .zstack(let alignment):
            AnyView(ZStack(alignment: alignment, content: content))
        }
    }
}
