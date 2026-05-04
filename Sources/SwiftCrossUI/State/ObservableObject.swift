import Foundation

/// An object that can be observed for changes.
///
/// The default implementation only publishes changes made to properties that
/// have been wrapped with the ``Published`` property wrapper. Even properties
/// that themselves conform to ``ObservableObject`` must be wrapped with the
/// ``Published`` property wrapper for clarity.
///
/// ```swift
/// class NestedState: ObservableObject {
///     // Both `startIndex` and `endIndex` will have their changes published to `NestedState`'s
///     // `didChange` publisher.
///     @Published
///     var startIndex = 0
///
///     @Published
///     var endIndex = 0
/// }
///
/// class CounterState: ObservableObject {
///     // Only changes to `count` will be published (it is the only property with `@Published`)
///     @Published
///     var count = 0
///
///     var otherCount = 0
///
///     // Even though `nested` is `ObservableObject`, its changes won't be
///     // published because if you could have observed properties without
///     // `@Published` things would get pretty messy and you'd always have to
///     // check the definition of the type of each property to know exactly
///     // what would and wouldn't cause updates.
///     var nested = NestedState()
/// }
/// ```
///
/// To use an observable object as part of a view's state, use the ``State`` property
/// wrapper. It'll detect that it's been given an observable and will forward any
/// observations published by the object's ``ObservableObject/didChange`` publisher.
///
/// ```swift
/// class CounterState: ObservableObject {
///     @Published var count = 0
/// }
///
/// struct CounterView: View {
///     @State var state = CounterState()
///
///     var body: some View {
///         HStack {
///             Button("-") {
///                 state.count -= 1
///             }
///             Text("Count: \(state.count)")
///             Button("+") {
///                 state.count += 1
///             }
///         }
///     }
/// }
/// ```
public protocol ObservableObject: AnyObject {
    /// A publisher which publishes changes made to the object. Only publishes changes made to
    /// ``Published`` properties by default.
    var didChange: Publisher { get }
}

extension ObservableObject {
    public var didChange: Publisher {
        observableObjectPublisherStore.publisher(for: self)
    }
}

private let observableObjectPublisherStore = ObservableObjectPublisherStore()

private final class ObservableObjectPublisherStore: @unchecked Sendable {
    private final class Entry {
        weak var owner: AnyObject?
        let publisher: Publisher
        var cancellables: [Cancellable]

        init(
            owner: AnyObject,
            publisher: Publisher,
            cancellables: [Cancellable]
        ) {
            self.owner = owner
            self.publisher = publisher
            self.cancellables = cancellables
        }
    }

    private var entries: [ObjectIdentifier: Entry] = [:]
    private let lock = NSLock()

    func publisher(for object: any ObservableObject) -> Publisher {
        let key = ObjectIdentifier(object)

        lock.lock()
        if let entry = entries[key], entry.owner != nil {
            let publisher = entry.publisher
            lock.unlock()
            return publisher
        }
        lock.unlock()

        let entry = makeEntry(for: object)

        lock.lock()
        entries = entries.filter { $0.value.owner != nil }
        entries[key] = entry
        lock.unlock()

        return entry.publisher
    }

    private func makeEntry(for object: any ObservableObject) -> Entry {
        let publisher = Publisher()
            .tag(with: String(describing: type(of: object)))
        var cancellables: [Cancellable] = []

        var mirror: Mirror? = Mirror(reflecting: object)
        while let aClass = mirror {
            for (_, property) in aClass.children {
                guard
                    property is PublishedMarkerProtocol,
                    let property = property as? ObservableObject
                else {
                    continue
                }

                cancellables.append(publisher.link(toUpstream: property.didChange))
            }
            mirror = aClass.superclassMirror
        }

        return Entry(
            owner: object,
            publisher: publisher,
            cancellables: cancellables
        )
    }
}

protocol OptionalObservableObject {
    var didChange: Publisher? { get }
}

extension Optional: OptionalObservableObject where Wrapped: ObservableObject {
    var didChange: SwiftCrossUI.Publisher? {
        switch self {
            case .some(let object):
                object.didChange
            case .none:
                nil
        }
    }
}

/// Automatically observes all public noncomputed variables with public getter and setter
@attached(memberAttribute)
@attached(extension, conformances: ObservableObject)
public macro ObservableObject() =
    #externalMacro(
        module: "SwiftCrossUIMacrosPlugin",
        type: "ObservableObjectMacro"
    )

/// Apply to a member inside your `@ObservableObject` class to opt out of observation.
/// Use the standard `Observation.ObservationIgnored` when you are adopting `@Observable`.
@attached(accessor)
public macro ObservableObjectIgnored() =
    #externalMacro(
        module: "SwiftCrossUIMacrosPlugin",
        type: "ObservableObjectIgnoredMacro"
    )
