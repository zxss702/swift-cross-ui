/// A namespace for matching geometry effects, mirroring SwiftUI's
/// `@Namespace` property wrapper.
///
/// Geometry interpolation lands with animation support; the property
/// wrapper supplies stable namespace identities today.
@propertyWrapper
public struct Namespace: Sendable {
    /// A namespace identity.
    public struct ID: Hashable, Sendable {
        let id: Int
    }

    private nonisolated(unsafe) static var nextID = 0
    private static func makeID() -> ID {
        defer { nextID += 1 }
        return ID(id: nextID)
    }

    public var wrappedValue: ID

    public init() {
        wrappedValue = Namespace.makeID()
    }
}

/// Properties of a ``MatchedGeometryEffect``.
public struct MatchedGeometryProperties: OptionSet, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    /// The view's frame position.
    public static let position = MatchedGeometryProperties(rawValue: 1 << 0)
    /// The view's frame size.
    public static let size = MatchedGeometryProperties(rawValue: 1 << 1)
    /// Both position and size.
    public static let frame: MatchedGeometryProperties = [.position, .size]
}

extension EnvironmentValues {
    /// A matched-geometry registration. Playback of geometry-matching
    /// animations lands with animation support; the association between
    /// matched views is recorded in the environment.
    @Entry public var matchedGeometry:
        (id: AnyHashable, namespace: Namespace.ID, isSource: Bool)?
}

extension View {
    /// Marks this view as a matched-geometry source or target.
    public func matchedGeometryEffect<ID: Hashable>(
        id: ID,
        in namespace: Namespace.ID,
        properties: MatchedGeometryProperties = .frame,
        anchor: UnitPoint = .center,
        isSource: Bool = true
    ) -> some View {
        EnvironmentModifier(self) { environment in
            environment.with(
                \.matchedGeometry,
                (id: AnyHashable(id), namespace: namespace, isSource: isSource)
            )
        }
    }
}
