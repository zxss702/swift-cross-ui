/// A transition that leaves content unchanged.
public struct IdentityTransition: Transition {
    public init() {}

    public func body(content: Content, phase: TransitionPhase) -> some View {
        content
    }
}

/// A transition that fades content in and out.
public struct OpacityTransition: Transition {
    public init() {}

    public func body(content: Content, phase: TransitionPhase) -> some View {
        content.opacity(phase.isIdentity ? 1 : 0)
    }
}

/// A transition that scales content in and out.
public struct ScaleTransition: Transition {
    public var scale: Double
    public var anchor: UnitPoint

    public init(scale: Double = 0, anchor: UnitPoint = .center) {
        self.scale = scale
        self.anchor = anchor
    }

    public func body(content: Content, phase: TransitionPhase) -> some View {
        content.scaleEffect(phase.isIdentity ? 1 : scale, anchor: anchor)
    }
}

/// A transition that moves content from an edge.
public struct MoveTransition: Transition {
    public static let properties = TransitionProperties(hasMotion: true)

    public var edge: Edge

    public init(edge: Edge) {
        self.edge = edge
    }

    public func body(content: Content, phase: TransitionPhase) -> some View {
        let offset = phase.isIdentity ? ViewSize.zero : edge.transitionOffset
        content.offset(offset)
    }
}

/// A transition that offsets content by a fixed amount.
public struct OffsetTransition: Transition {
    public static let properties = TransitionProperties(hasMotion: true)

    public var offset: ViewSize

    public init(offset: ViewSize) {
        self.offset = offset
    }

    public func body(content: Content, phase: TransitionPhase) -> some View {
        content.offset(phase.isIdentity ? .zero : offset)
    }
}

/// A transition that slides content horizontally.
public struct SlideTransition: Transition {
    public static let properties = TransitionProperties(hasMotion: true)

    public init() {}

    public func body(content: Content, phase: TransitionPhase) -> some View {
        content.offset(x: phase.value * 100, y: 0)
    }
}

/// A transition that pushes content from an edge.
public struct PushTransition: Transition {
    public static let properties = TransitionProperties(hasMotion: true)

    public var edge: Edge

    public init(edge: Edge) {
        self.edge = edge
    }

    public func body(content: Content, phase: TransitionPhase) -> some View {
        let offset = phase.isIdentity
            ? ViewSize.zero
            : edge.transitionOffset.scaled(by: -phase.value)
        content.offset(offset)
    }
}

/// A transition that blurs and fades content.
public struct BlurReplaceTransition: Transition {
    public enum Configuration: Hashable, Sendable {
        case downUp
        case upUp
    }

    public var configuration: Configuration

    public init(_ configuration: Configuration = .downUp) {
        self.configuration = configuration
    }

    public func body(content: Content, phase: TransitionPhase) -> some View {
        content
            .blur(radius: phase.isIdentity ? 0 : 8)
            .opacity(phase.isIdentity ? 1 : 0)
    }
}

/// A transition with distinct insertion and removal behavior.
public struct AsymmetricTransition: Transition {
    public var insertion: AnyTransition
    public var removal: AnyTransition

    public init(insertion: AnyTransition, removal: AnyTransition) {
        self.insertion = insertion
        self.removal = removal
    }

    public func body(content: Content, phase: TransitionPhase) -> some View {
        removal.applyTransition(
            insertion.applyTransition(
                AnyView(content),
                phase == .didDisappear ? .identity : phase
            ),
            phase == .didDisappear ? phase : .identity
        )
    }
}

struct ModifierTransition<Modifier: ViewModifier>: Transition {
    var active: Modifier
    var identity: Modifier

    func body(content: Content, phase: TransitionPhase) -> some View {
        content.modifier(phase.isIdentity ? identity : active)
    }
}

struct CombinedAnyTransition: Transition {
    var first: AnyTransition
    var second: AnyTransition

    func body(content: Content, phase: TransitionPhase) -> some View {
        second.applyTransition(first.applyTransition(AnyView(content), phase), phase)
    }
}

struct AnimationScopedAnyTransition: Transition {
    var base: AnyTransition
    var animation: Animation?

    func body(content: Content, phase: TransitionPhase) -> some View {
        base.applyTransition(AnyView(content), phase)
            .transaction { transaction in
                if !transaction.disablesAnimations {
                    transaction.animation = animation
                }
            }
    }
}

extension Edge {
    fileprivate var transitionOffset: ViewSize {
        switch self {
            case .top:
                ViewSize(0, -100)
            case .bottom:
                ViewSize(0, 100)
            case .leading:
                ViewSize(-100, 0)
            case .trailing:
                ViewSize(100, 0)
        }
    }
}

private extension ViewSize {
    func scaled(by factor: Double) -> ViewSize {
        ViewSize(width * factor, height * factor)
    }
}
