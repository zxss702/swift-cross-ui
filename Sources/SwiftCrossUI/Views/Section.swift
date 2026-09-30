/// A section of content within a container, with optional header and footer,
/// mirroring SwiftUI's `Section`.
public struct Section<Content: View, Header: View, Footer: View>: View {
    var content: Content
    var header: Header
    var footer: Footer

    /// Creates a section with content, header, and footer.
    public init(
        @ViewBuilder content: () -> Content,
        @ViewBuilder header: () -> Header,
        @ViewBuilder footer: () -> Footer
    ) {
        self.content = content()
        self.header = header()
        self.footer = footer()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            content
            footer
        }
    }
}

extension Section where Header == EmptyView, Footer == EmptyView {
    /// Creates a section with content only.
    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
        self.header = EmptyView()
        self.footer = EmptyView()
    }
}

extension Section where Footer == EmptyView {
    /// Creates a section with content and a header.
    public init(
        @ViewBuilder content: () -> Content,
        @ViewBuilder header: () -> Header
    ) {
        self.content = content()
        self.header = header()
        self.footer = EmptyView()
    }
}

extension Section where Header == EmptyView {
    /// Creates a section with content and a footer.
    public init(
        @ViewBuilder content: () -> Content,
        @ViewBuilder footer: () -> Footer
    ) {
        self.content = content()
        self.header = EmptyView()
        self.footer = footer()
    }
}

extension Section where Header == Text, Footer == EmptyView {
    /// Creates a section with a text header.
    public init(_ title: String, @ViewBuilder content: () -> Content) {
        self.content = content()
        self.header = Text(title)
        self.footer = EmptyView()
    }
}
