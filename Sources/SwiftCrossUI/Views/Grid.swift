/// A view that arranges subviews in a grid.
///
/// Rows are laid out as a ``VStack`` of ``GridRow`` ``HStack``s. Column
/// alignment across rows is not yet implemented; `horizontalSpacing` and
/// `gridColumnAlignment` are propagated to rows via the environment.
public struct Grid<Content: View>: View {
    private var alignment: Alignment
    private var horizontalSpacing: Double?
    private var verticalSpacing: Double?
    private var content: Content

    /// Creates a grid with the given spacing and alignment.
    public init(
        alignment: Alignment = .center,
        horizontalSpacing: Double? = nil,
        verticalSpacing: Double? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.alignment = alignment
        self.horizontalSpacing = horizontalSpacing
        self.verticalSpacing = verticalSpacing
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: alignment.horizontal, spacing: verticalSpacing) {
            content
        }
        .environment(\.gridHorizontalSpacing, horizontalSpacing)
    }
}

/// A row within a ``Grid``.
///
/// Rendered as an ``HStack`` whose spacing comes from the enclosing
/// ``Grid``'s `horizontalSpacing` via the environment.
public struct GridRow<Content: View>: View {
    @Environment(\.gridHorizontalSpacing) private var horizontalSpacing

    private var alignment: VerticalAlignment?
    private var content: Content

    /// Creates a grid row.
    public init(
        alignment: VerticalAlignment? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.alignment = alignment
        self.content = content()
    }

    public var body: some View {
        HStack(alignment: alignment ?? .center, spacing: horizontalSpacing) {
            content
        }
    }
}

extension View {
    /// Associates a horizontal alignment guide with the grid column
    /// containing this view.
    ///
    /// Expands the cell to fill the available column width and aligns its
    /// content. True column-width tracking across rows is not yet
    /// implemented.
    public func gridColumnAlignment(_ guide: HorizontalAlignment) -> some View {
        frame(maxWidth: .infinity, alignment: Alignment(horizontal: guide, vertical: .center))
    }
}
