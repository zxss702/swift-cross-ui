/// A horizontal or vertical edge of a rectangle.
public enum VerticalEdge: Int8, CaseIterable, Hashable, Sendable {
    /// The top edge.
    case top
    /// The bottom edge.
    case bottom

    /// An efficient set of vertical edges.
    public struct Set: OptionSet, Hashable, Sendable {
        public let rawValue: Int8

        public init(rawValue: Int8) {
            self.rawValue = rawValue
        }

        public init(_ edge: VerticalEdge) {
            self.rawValue = 1 << edge.rawValue
        }

        public static let top = Set(.top)
        public static let bottom = Set(.bottom)
        public static let all: Set = [.top, .bottom]
    }
}

/// A leading or trailing edge of a rectangle.
public enum HorizontalEdge: Int8, CaseIterable, Hashable, Sendable {
    /// The leading edge (the left edge in left to right layouts).
    case leading
    /// The trailing edge (the right edge in left to right layouts).
    case trailing

    /// An efficient set of horizontal edges.
    public struct Set: OptionSet, Hashable, Sendable {
        public let rawValue: Int8

        public init(rawValue: Int8) {
            self.rawValue = rawValue
        }

        public init(_ edge: HorizontalEdge) {
            self.rawValue = 1 << edge.rawValue
        }

        public static let leading = Set(.leading)
        public static let trailing = Set(.trailing)
        public static let all: Set = [.leading, .trailing]
    }
}

extension View {
    /// Inserts a view at the given vertical edge, reserving space for it.
    public func safeAreaInset<Content: View>(
        edge: VerticalEdge,
        alignment: HorizontalAlignment = .center,
        spacing: CGFloat? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        _safeAreaInset(
            edge: edge == .top ? Edge.Set.top : .bottom,
            alignment: Alignment(horizontal: alignment, vertical: .center),
            spacing: spacing.map(Double.init),
            content: content
        )
    }

    /// Inserts a view at the given horizontal edge, reserving space for it.
    public func safeAreaInset<Content: View>(
        edge: HorizontalEdge,
        alignment: VerticalAlignment = .center,
        spacing: CGFloat? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        _safeAreaInset(
            edge: edge == .leading ? Edge.Set.leading : .trailing,
            alignment: Alignment(horizontal: .center, vertical: alignment),
            spacing: spacing.map(Double.init),
            content: content
        )
    }

    /// Adds padding within this view's safe area along the given edges.
    public func safeAreaPadding(_ edges: Edge.Set = .all, _ amount: Double) -> some View {
        padding(edges, amount)
    }
}
