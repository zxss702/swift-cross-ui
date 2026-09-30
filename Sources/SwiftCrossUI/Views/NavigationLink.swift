// TODO: This documentation could probably be clarified a bit more (potentially with
//   some practical examples).
import Foundation

/// A navigation primitive that appends a value to the current navigation path on click.
///
/// Unlike Apple's SwiftUI API, a `NavigationLink` can be outside of a `NavigationStack`
/// as long as they share the same `NavigationPath`.
public struct NavigationLink: View {
    @Environment(\.navigationPath) private var environmentPath
    @Environment(\.navigationDestinations) private var destinations

    public var body: some View {
        if let labelView {
            Button(
                action: pushDestination,
                label: { labelView() }
            )
        } else {
            Button(label) {
                if let environmentPath {
                    environmentPath.wrappedValue.append(value)
                } else {
                    path.wrappedValue.append(value)
                }
            }
        }
    }

    /// The label to display on the button.
    private let label: String
    /// The value to append to the navigation path when clicked.
    private let value: any Codable
    /// The navigation path to append to when clicked.
    private let path: Binding<NavigationPath>
    /// A destination view to push when clicked.
    private let destination: (() -> AnyView)?
    /// A custom view label.
    private let labelView: (() -> AnyView)?

    /// Creates a navigation link that presents the view corresponding to a value.
    /// The link is handled by whatever ``NavigationStack`` is sharing the same
    /// navigation path.
    ///
    /// - Parameters:
    ///   - label: The label to display on the button.
    ///   - value: The value to append to the navigation path when clicked.
    ///   - path: The navigation path to append to when clicked.
    public init(_ label: String, value: some Codable, path: Binding<NavigationPath>) {
        self.label = label
        self.value = value
        self.path = path
        self.destination = nil
        self.labelView = nil
    }

    /// Creates a navigation link that presents the view corresponding to a
    /// value, using the path of the nearest enclosing ``NavigationStack``.
    ///
    /// - Parameters:
    ///   - label: The label to display on the button.
    ///   - value: The value to append to the navigation path when clicked.
    public init(_ label: String, value: some Codable) {
        self.init(label, value: value, path: .constant(NavigationPath()))
    }

    /// Creates a navigation link that presents a destination view, using the
    /// path of the nearest enclosing ``NavigationStack``.
    ///
    /// - Parameters:
    ///   - destination: The view to present when clicked.
    ///   - label: The label to display on the button.
    @MainActor
    public init<Destination: View, LabelContent: View>(
        @ViewBuilder destination: @escaping () -> Destination,
        @ViewBuilder label: @escaping () -> LabelContent
    ) {
        self.label = ""
        self.value = NavigationStackRootPath()
        self.path = .constant(NavigationPath())
        self.destination = { AnyView(destination()) }
        self.labelView = { AnyView(label()) }
    }

    /// Pushes this link's view destination onto the nearest stack's path.
    private func pushDestination() {
        guard let destination else { return }
        let id = destinations.register { destination() }
        environmentPath?.wrappedValue.append(NavigationViewLinkEntry(id: id))
    }
}
