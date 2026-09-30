/// A view pairing a title with an icon, mirroring SwiftUI's `Label`.
///
/// The label's visibility is controlled by
/// ``EnvironmentValues/labelsHidden``: when set, only the icon renders.
public struct Label<Title: View, Icon: View>: View {
    var title: Title
    var icon: Icon

    @Environment(\.labelsHidden) private var labelsHidden

    /// Creates a label from title and icon views.
    public init(@ViewBuilder title: () -> Title, @ViewBuilder icon: () -> Icon) {
        self.title = title()
        self.icon = icon()
    }

    public var body: some View {
        if labelsHidden {
            icon
        } else {
            HStack(spacing: 4) {
                icon
                title
            }
        }
    }
}

extension Label where Title == Text, Icon == Image {
    /// Creates a label with a text title and a symbol image.
    public init(_ title: String, systemImage name: String) {
        self.title = Text(title)
        self.icon = Image(systemName: name)
    }
}

extension Label where Title == Text {
    /// Creates a label with a text title and a custom icon.
    public init(_ title: String, @ViewBuilder icon: () -> Icon) {
        self.title = Text(title)
        self.icon = icon()
    }
}

extension Label where Icon == Image {
    /// Creates a label with a symbol icon and a custom title.
    public init(systemImage name: String, @ViewBuilder title: () -> Title) {
        self.title = title()
        self.icon = Image(systemName: name)
    }
}
