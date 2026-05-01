/// The phase of a transition.
public enum TransitionPhase: Hashable, Sendable {
    case willAppear
    case identity
    case didDisappear

    public var isIdentity: Bool {
        self == .identity
    }

    public var value: Double {
        switch self {
            case .willAppear:
                -1
            case .identity:
                0
            case .didDisappear:
                1
        }
    }
}

/// Static properties describing a transition.
public struct TransitionProperties: Hashable, Sendable {
    public var hasMotion: Bool

    public init(hasMotion: Bool = false) {
        self.hasMotion = hasMotion
    }
}
