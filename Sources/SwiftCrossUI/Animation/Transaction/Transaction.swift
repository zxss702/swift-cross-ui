import Foundation

/// A key for storing custom values in a transaction.
public protocol TransactionKey {
    associatedtype Value

    static var defaultValue: Value { get }
}

/// Context that travels with a state mutation.
public struct Transaction: @unchecked Sendable {
    private var values: [ObjectIdentifier: Any] = [:]
    private var animationCompletionStorages: [AnimationCompletionStorage] = []
    private var hasAnimationOverride = false
    private var animationStorage: Animation?

    public var animation: Animation? {
        get {
            animationStorage
        }
        set {
            animationStorage = newValue
            hasAnimationOverride = true
        }
    }
    public var disablesAnimations: Bool
    public var disablesContentTransitions: Bool
    public var isContinuous: Bool
    public var tracksVelocity: Bool
    public var scrollTargetAnchor: UnitPoint?
    public var scrollPositionUpdatePreservesVelocity: Bool
    public var scrollContentOffsetAdjustmentBehavior: ScrollContentOffsetAdjustmentBehavior

    public init() {
        animationStorage = nil
        disablesAnimations = false
        disablesContentTransitions = false
        isContinuous = false
        tracksVelocity = false
        scrollTargetAnchor = nil
        scrollPositionUpdatePreservesVelocity = false
        scrollContentOffsetAdjustmentBehavior = .automatic
    }

    public init(animation: Animation?) {
        self.init()
        animationStorage = animation
        hasAnimationOverride = true
    }

    public subscript<K: TransactionKey>(key: K.Type) -> K.Value {
        get {
            values[ObjectIdentifier(key), default: K.defaultValue] as! K.Value
        }
        set {
            values[ObjectIdentifier(key)] = newValue
        }
    }

    public mutating func addAnimationCompletion(
        criteria: AnimationCompletionCriteria = .logicallyComplete,
        _ completion: @escaping @Sendable () -> Void
    ) {
        let storage = AnimationCompletionStorage()
        storage.add(criteria: criteria, completion)
        animationCompletionStorages.append(storage)
    }

    func runCompletions(matching criteria: AnimationCompletionCriteria) {
        for storage in animationCompletionStorages {
            storage.run(matching: criteria)
        }
    }

    var hasOverrides: Bool {
        !values.isEmpty
            || !animationCompletionStorages.isEmpty
            || hasAnimationOverride
            || disablesAnimations
            || disablesContentTransitions
            || isContinuous
            || tracksVelocity
            || scrollTargetAnchor != nil
            || scrollPositionUpdatePreservesVelocity
            || scrollContentOffsetAdjustmentBehavior != .automatic
    }

    func overlaid(by override: Transaction) -> Transaction {
        guard override.hasOverrides else {
            return self
        }

        var transaction = self
        for (key, value) in override.values {
            transaction.values[key] = value
        }
        if override.hasAnimationOverride || override.disablesAnimations {
            transaction.animation = override.animation
        }
        transaction.disablesAnimations = transaction.disablesAnimations
            || override.disablesAnimations
        transaction.disablesContentTransitions = transaction.disablesContentTransitions
            || override.disablesContentTransitions
        transaction.isContinuous = transaction.isContinuous || override.isContinuous
        transaction.tracksVelocity = transaction.tracksVelocity || override.tracksVelocity
        transaction.scrollTargetAnchor = override.scrollTargetAnchor
            ?? transaction.scrollTargetAnchor
        transaction.scrollPositionUpdatePreservesVelocity =
            transaction.scrollPositionUpdatePreservesVelocity
            || override.scrollPositionUpdatePreservesVelocity
        if override.scrollContentOffsetAdjustmentBehavior != .automatic {
            transaction.scrollContentOffsetAdjustmentBehavior =
                override.scrollContentOffsetAdjustmentBehavior
        }
        transaction.mergeAnimationCompletions(from: override)
        return transaction
    }

    func mergedQueuedMutation(by override: Transaction) -> Transaction {
        var transaction = overlaid(by: override)
        if override.hasOverrides {
            transaction.disablesAnimations = override.disablesAnimations
            transaction.disablesContentTransitions = override.disablesContentTransitions
        }
        return transaction
    }

    private mutating func mergeAnimationCompletions(from override: Transaction) {
        guard !override.animationCompletionStorages.isEmpty else {
            return
        }

        var existing = Set(animationCompletionStorages.map(ObjectIdentifier.init))
        for storage in override.animationCompletionStorages
        where existing.insert(ObjectIdentifier(storage)).inserted {
            animationCompletionStorages.append(storage)
        }
    }
}

private final class AnimationCompletionStorage: @unchecked Sendable {
    private var completions: [(AnimationCompletionCriteria, @Sendable () -> Void)] = []
    private var completedCriteria = Set<AnimationCompletionCriteria>()

    func add(
        criteria: AnimationCompletionCriteria,
        _ completion: @escaping @Sendable () -> Void
    ) {
        completions.append((criteria, completion))
    }

    func run(matching criteria: AnimationCompletionCriteria) {
        guard completedCriteria.insert(criteria).inserted else {
            return
        }
        for (completionCriteria, completion) in completions
        where completionCriteria == criteria {
            completion()
        }
    }
}

/// A fallback model for scroll offset transaction behavior.
public enum ScrollContentOffsetAdjustmentBehavior: Hashable, Sendable {
    case automatic
    case never
    case always
}
