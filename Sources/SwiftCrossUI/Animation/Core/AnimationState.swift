/// A key used to store animation-local state.
public protocol AnimationStateKey {
    associatedtype Value

    static var defaultValue: Value { get }
}

/// Storage for state owned by a custom animation.
public struct AnimationState<Value: VectorArithmetic> {
    private var values: [ObjectIdentifier: Any] = [:]

    public init() {}

    public subscript<K: AnimationStateKey>(key: K.Type) -> K.Value {
        get {
            values[ObjectIdentifier(key), default: K.defaultValue] as! K.Value
        }
        set {
            values[ObjectIdentifier(key)] = newValue
        }
    }
}

/// Per-run context passed to custom animations.
public struct AnimationContext<Value: VectorArithmetic> {
    public var state: AnimationState<Value>
    public var isLogicallyComplete: Bool

    private let environmentStorage: EnvironmentValues?

    @MainActor
    public var environment: EnvironmentValues {
        guard let environmentStorage else {
            fatalError("AnimationContext.environment used without a view environment")
        }
        return environmentStorage
    }

    init(
        state: AnimationState<Value> = AnimationState(),
        isLogicallyComplete: Bool = false,
        environment: EnvironmentValues? = nil
    ) {
        self.state = state
        self.isLogicallyComplete = isLogicallyComplete
        self.environmentStorage = environment
    }

    public func withState<T: VectorArithmetic>(
        _ state: AnimationState<T>
    ) -> AnimationContext<T> {
        AnimationContext<T>(
            state: state,
            isLogicallyComplete: isLogicallyComplete,
            environment: environmentStorage
        )
    }
}
