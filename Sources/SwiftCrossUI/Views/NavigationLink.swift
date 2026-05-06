/// A navigation primitive that appends a value to the current navigation path on click.
///
/// A link can use the nearest enclosing ``NavigationStack`` automatically, or
/// it can append to an explicit ``NavigationPath`` binding.
public struct NavigationLink: View {
    @Environment(\.navigationPathBinding) private var environmentPath

    public var body: some View {
        let path = resolvedPath
        Button(label) {
            path.wrappedValue.append(value)
        }
    }

    /// The label to display on the button.
    private let label: String
    /// The value to append to the navigation path when clicked.
    private let value: any Codable
    /// The navigation path to append to when clicked.
    private let explicitPath: Binding<NavigationPath>?

    /// Creates a navigation link that presents the view corresponding to a
    /// value in the nearest enclosing ``NavigationStack``.
    ///
    /// - Parameters:
    ///   - label: The label to display on the button.
    ///   - value: The value to append to the current navigation path when clicked.
    public init(_ label: String, value: some Codable) {
        self.label = label
        self.value = value
        self.explicitPath = nil
    }

    /// Creates a navigation link that presents the view corresponding to a value.
    /// The link is handled by whichever ``NavigationStack`` is sharing the
    /// supplied navigation path.
    ///
    /// - Parameters:
    ///   - label: The label to display on the button.
    ///   - value: The value to append to the navigation path when clicked.
    ///   - path: The navigation path to append to when clicked.
    public init(_ label: String, value: some Codable, path: Binding<NavigationPath>) {
        self.label = label
        self.value = value
        self.explicitPath = path
    }

    private var resolvedPath: Binding<NavigationPath> {
        guard let path = explicitPath ?? environmentPath else {
            fatalError(
                """
                NavigationLink requires either an explicit path binding or an \
                enclosing NavigationStack.
                """
            )
        }
        return path
    }
}
