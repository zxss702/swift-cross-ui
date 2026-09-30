import Foundation
/// Type to indicate the root of the NavigationStack. This is internal to prevent root accidentally showing instead
/// of a detail view.
struct NavigationStackRootPath: Codable {}

/// A view that displays a root view and enables you to present additional views
/// over the root view.
///
/// Use ``navigationDestination(for:destination:)`` on this view instead of its
/// children, unlike Apple's SwiftUI API.
public struct NavigationStack<Detail: View>: View {
    @Environment(\.navigationDestinations) private var destinations
    @Environment(\.windowChrome) private var windowChrome
    @State private var unmanagedPath = NavigationPath()

    public var body: some View {
        let inner: AnyView
        if let element = elements.last {
            if let entry = element as? NavigationViewLinkEntry,
                let view = destinations.viewDestinations[entry.id]
            {
                inner = view()
            } else if let content = child(element) {
                inner = AnyView(content)
            } else if let resolver = destinations.resolvers[ObjectIdentifier(type(of: element))],
                let content = resolver(element)
            {
                inner = content
            } else {
                fatalError(
                    "Failed to find detail view for \"\(element)\", make sure you have called .navigationDestination for this type."
                )
            }
        } else {
            inner = AnyView(Text("Empty navigation path"))
        }
        let content = EnvironmentModifier(inner) { environment in
            environment.with(\.navigationPath, path)
        }
        // Render a lightweight inline navigation bar with a back button once
        // the stack is deeper than the root, matching SwiftUI's chrome. On
        // backends with integrated window chrome the back action is published
        // into the title-bar strip instead of an inline row.
        if windowChrome != nil {
            return AnyView(
                VStack(alignment: .leading, spacing: 0) {
                    WindowChromeBackAttachment(
                        content: content,
                        canGoBack: elements.count > 1
                    ) {
                        path.wrappedValue.removeLast()
                    }
                }
            )
        }
        return AnyView(
            VStack(alignment: .leading, spacing: 0) {
                if elements.count > 1 {
                    Button {
                        path.wrappedValue.removeLast()
                    } label: {
                        Text("‹")
                            .font(.system(size: 28))
                            .padding(.horizontal, 8)
                    }
                    .buttonStyle(.borderless)
                    .padding(4)
                }
                content
            }
        )
    }

    /// A binding to the current navigation path.
    var path: Binding<NavigationPath>
    /// The types handled by each destination (in the same order as their
    /// corresponding views in the stack).
    var destinationTypes: [any Codable.Type]
    /// Gets a recursive ``EitherView`` structure which will have a single view
    /// visible suitable for displaying the given path element (based on its
    /// type).
    ///
    /// It's implemented as a recursive structure because that's the best way to keep this
    /// typesafe without introducing some crazy generated pseudo-variadic storage types of
    /// some sort. This way we can easily have unlimited navigation destinations and there's
    /// just a single simple method for adding a navigation destination.
    var child: (any Codable) -> Detail?
    /// The elements of the navigation path. The result can depend on
    /// ``NavigationStack/destinationTypes`` which determines how the keys are
    /// decoded if they haven't yet been decoded (this happens if they're loaded
    /// from disk for persistence).
    var elements: [any Codable] {
        let resolvedPath = path.wrappedValue.path(
            destinationTypes: destinationTypes
        )
        return [NavigationStackRootPath()] + resolvedPath
    }

    /// Creates a navigation stack with heterogeneous navigation state that you
    /// can control.
    ///
    /// - Parameters:
    ///   - path: A ``Binding`` to the navigation state for this stack.
    ///   - root: The view to display when the stack is empty.
    public init(
        path: Binding<NavigationPath>,
        @ViewBuilder _ root: @escaping () -> Detail
    ) {
        self.path = path
        destinationTypes = []
        child = { element in
            if element is NavigationStackRootPath {
                return root()
            } else {
                return nil
            }
        }
    }

    /// Creates a navigation stack with homogeneous navigation state that you
    /// can control, as in SwiftUI.
    ///
    /// - Parameters:
    ///   - path: A ``Binding`` to an array of path elements.
    ///   - root: The view to display when the stack is empty.
    public init<Element: Hashable & Codable>(
        path elements: Binding<[Element]>,
        @ViewBuilder _ root: @escaping () -> Detail
    ) {
        self.path = Binding<NavigationPath>(
            get: {
                var path = NavigationPath()
                for element in elements.wrappedValue {
                    path.append(element)
                }
                return path
            },
            set: { newPath in
                let resolved = newPath.path(destinationTypes: [Element.self])
                elements.wrappedValue = resolved.compactMap { $0 as? Element }
            }
        )
        destinationTypes = [Element.self]
        child = { element in
            if element is NavigationStackRootPath {
                return root()
            } else {
                return nil
            }
        }
    }

    /// Creates a navigation stack with an internally managed navigation path.
    ///
    /// - Parameter root: The view to display when the stack is empty.
    public init(
        @ViewBuilder _ root: @escaping () -> Detail
    ) {
        _unmanagedPath = State(initialValue: NavigationPath())
        self.path = _unmanagedPath.projectedValue
        destinationTypes = []
        child = { element in
            if element is NavigationStackRootPath {
                return root()
            } else {
                return nil
            }
        }
    }

    /// Associates a destination view with a presented data type for use within
    /// a navigation stack.
    ///
    /// Add this view modifer to describe the view that the stack displays when
    /// presenting a particular kind of data. Use a ``NavigationLink`` to
    /// present the data. You can add more than one navigation destination
    /// modifier to the stack if it needs to present more than one kind of data.
    ///
    /// - Parameters:
    ///   - data: The type of data that this destination matches.
    ///   - destination: A view builder that defines a view to display when the
    ///     stack's navigation state contains a value of type data. The closure
    ///     takes one argument, which is the value of the data to present.
    public func navigationDestination<D: Codable, C: View>(
        for data: D.Type,
        @ViewBuilder destination: @escaping (D) -> C
    ) -> NavigationStack<EitherView<Detail, C>> {
        // Adds another detail view by adding to the recursive structure of either views created
        // to display details in a type-safe manner. See NavigationStack.child for details.
        return NavigationStack<EitherView<Detail, C>>(
            previous: self,
            destination: destination
        )
    }

    /// Add a destination for a specific path element (by adding another layer of ``EitherView``).
    private init<PreviousDetail: View, NewDetail: View, Component: Codable>(
        previous: NavigationStack<PreviousDetail>,
        destination: @escaping (Component) -> NewDetail?
    ) where Detail == EitherView<PreviousDetail, NewDetail> {
        path = previous.path
        destinationTypes = previous.destinationTypes + [Component.self]
        child = {
            if let previous = previous.child($0) {
                // Either root or previously defined destination returned a view
                return EitherView(previous)
            } else if let component = $0 as? Component, let new = destination(component) {
                // This destination returned a detail view for the current element
                return EitherView(new)
            } else {
                // Possibly a future .navigationDestination will handle this path element
                return nil
            }
        }
    }

    /// Attempts to compute the detail view for the given element (the type of
    /// the element decides which detail is shown). Crashes if no suitable detail
    /// view is found.
    func childOrCrash(for element: some Codable) -> Detail {
        guard let child = child(element) else {
            fatalError(
                "Failed to find detail view for \"\(element)\", make sure you have called .navigationDestination for this type."
            )
        }

        return child
    }
}
