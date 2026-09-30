/// A path element representing a pushed view destination (created by
/// ``NavigationLink/init(destination:label:)``).
struct NavigationViewLinkEntry: Codable {
    var id: Int
}

/// Shared navigation state used to implement destination-view navigation
/// links and view-level `navigationDestination` modifiers.
///
/// The environment provides a single shared instance; navigation stacks
/// publish their path binding into the environment so that
/// ``NavigationLink`` instances don't need an explicit path parameter.
public final class NavigationDestinations {
    /// Views pushed by destination-view navigation links, keyed by entry id.
    var viewDestinations: [Int: () -> AnyView] = [:]
    /// Resolvers registered by ``View/navigationDestination(item:destination:)``.
    var resolvers: [ObjectIdentifier: @MainActor (any Codable) -> AnyView?] = [:]
    /// The id to assign to the next pushed view destination.
    var nextViewDestinationId = 0

    /// Registers a pushed view destination and returns its entry id.
    @MainActor
    func register(_ view: @escaping () -> AnyView) -> Int {
        let id = nextViewDestinationId
        nextViewDestinationId += 1
        viewDestinations[id] = view
        return id
    }
}

private struct NavigationDestinationsKey: EnvironmentKey {
    nonisolated(unsafe) static let defaultValue = NavigationDestinations()
}

private struct NavigationPathKey: EnvironmentKey {
    nonisolated(unsafe) static let defaultValue: Binding<NavigationPath>? = nil
}

extension EnvironmentValues {
    /// The shared navigation destination registry.
    public var navigationDestinations: NavigationDestinations {
        get { self[NavigationDestinationsKey.self] }
        set { self[NavigationDestinationsKey.self] = newValue }
    }

    /// The binding of the nearest enclosing ``NavigationStack``.
    public var navigationPath: Binding<NavigationPath>? {
        get { self[NavigationPathKey.self] }
        set { self[NavigationPathKey.self] = newValue }
    }
}

extension View {
    /// Registers a destination view for the presented item and pushes it when
    /// `item` becomes non-`nil`.
    ///
    /// The destination is resolved through the shared
    /// ``EnvironmentValues/navigationDestinations`` registry, so this works
    /// on any view within a ``NavigationStack``.
    public func navigationDestination<Item, Destination: View>(
        item: Binding<Item?>,
        @ViewBuilder destination: @escaping (Item) -> Destination
    ) -> some View {
        _NavigationItemDestination(
            content: self,
            item: item,
            destination: destination
        )
    }

    /// Registers a destination view for a presented data type within an
    /// enclosing ``NavigationStack``, as in SwiftUI.
    ///
    /// The destination is resolved through the shared
    /// ``EnvironmentValues/navigationDestinations`` registry whenever a path
    /// element of type `D` is pushed.
    ///
    /// - Parameters:
    ///   - data: The type of data that this destination matches.
    ///   - destination: A view builder that produces the view to display for
    ///     a presented value of type `D`.
    public func navigationDestination<D: Codable, Destination: View>(
        for data: D.Type,
        @ViewBuilder destination: @escaping (D) -> Destination
    ) -> some View {
        EnvironmentModifier(self) { environment in
            environment.navigationDestinations.resolvers[ObjectIdentifier(D.self)] = { element in
                guard let value = element as? D else {
                    return nil
                }
                return AnyView(destination(value))
            }
            return environment
        }
    }
}

/// Drives ``View/navigationDestination(item:destination:)`` by pushing a
/// registered view destination onto the enclosing stack's path whenever
/// `item` becomes non-`nil`.
private struct _NavigationItemDestination<Content: View, Item, Destination: View>: View {
    @Environment(\.navigationPath) var navigationPath
    @Environment(\.navigationDestinations) var destinations
    @State var pushedEntryId: Int?

    var content: Content
    var item: Binding<Item?>
    var destination: (Item) -> Destination

    var body: some View {
        content
            .onChange(of: item.wrappedValue != nil, initial: true) { _, isPresented in
                if isPresented, let value = item.wrappedValue {
                    let id = destinations.register { AnyView(destination(value)) }
                    pushedEntryId = id
                    navigationPath?.wrappedValue.append(NavigationViewLinkEntry(id: id))
                } else if !isPresented, pushedEntryId != nil {
                    pushedEntryId = nil
                    navigationPath?.wrappedValue.removeLast()
                }
            }
    }
}
