/// A transition applied when a view's rendered content changes.
public struct ContentTransition: Hashable, Sendable {
    public static let identity = Self(kind: .identity)
    public static let interpolate = Self(kind: .interpolate)
    public static let opacity = Self(kind: .opacity)

    private enum Kind: Hashable, Sendable {
        case identity
        case interpolate
        case opacity
        case numericText(countsDown: Bool?)
        case numericTextValue(Double)
    }

    private var kind: Kind

    private init(kind: Kind) {
        self.kind = kind
    }

    var isIdentity: Bool {
        kind == .identity
    }

    var usesCharacterFragments: Bool {
        switch kind {
            case .numericText, .numericTextValue:
                true
            case .identity, .interpolate, .opacity:
                false
        }
    }

    var numericValue: Double? {
        if case .numericTextValue(let value) = kind {
            value
        } else {
            nil
        }
    }

    func transition(previousValue: Double?) -> AnyTransition {
        switch kind {
            case .identity:
                return .identity
            case .opacity, .interpolate:
                return .opacity
            case .numericText, .numericTextValue:
                let down = numericDirection(previousValue: previousValue) < 0
                return .asymmetric(
                    insertion: AnyTransition(
                        ContentFocusTransition(anchor: down ? .topLeading : .bottomLeading)
                    ),
                    removal: AnyTransition(
                        ContentFocusTransition(anchor: down ? .bottomTrailing : .topTrailing)
                    )
                )
        }
    }

    private func numericDirection(previousValue: Double?) -> Double {
        switch kind {
            case .numericText(let countsDown):
                return countsDown == true ? -1 : 1
            case .numericTextValue(let value):
                guard let previousValue, value != previousValue else {
                    return 1
                }
                return value > previousValue ? 1 : -1
            case .identity, .interpolate, .opacity:
                return 1
        }
    }

    public static func numericText(countsDown: Bool = false) -> Self {
        Self(kind: .numericText(countsDown: countsDown))
    }

    public static func numericText(value: Double) -> Self {
        Self(kind: .numericTextValue(value))
    }
}

extension EnvironmentValues {
    @Entry public var contentTransition: ContentTransition = .identity
}

extension View {
    /// Sets the content transition for this view branch.
    public func contentTransition(_ transition: ContentTransition) -> some View {
        environment(\.contentTransition, transition)
    }
}

private struct ContentFocusTransition: Transition {
    var anchor: UnitPoint

    func body(content: Content, phase: TransitionPhase) -> some View {
        content
            .blur(radius: phase.isIdentity ? 0 : 4)
            .scaleEffect(phase.isIdentity ? 1 : 0, anchor: anchor)
            .opacity(phase.isIdentity ? 1 : 0)
    }
}
