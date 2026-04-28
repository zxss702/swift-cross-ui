/// A key for custom values carried by a ``Transaction``.
public protocol TransactionKey {
    associatedtype Value
    static var defaultValue: Value { get }
    static func valuesEqual(_ lhs: Value, _ rhs: Value) -> Bool
}

extension TransactionKey {
    public static func valuesEqual(_ lhs: Value, _ rhs: Value) -> Bool {
        false
    }
}

extension TransactionKey where Value: Equatable {
    public static func valuesEqual(_ lhs: Value, _ rhs: Value) -> Bool {
        lhs == rhs
    }
}

private struct AnimationTransactionKey: TransactionKey {
    static let defaultValue: Animation? = nil
}

private struct DisablesAnimationsTransactionKey: TransactionKey {
    static let defaultValue = false
}

/// Context attached to a state change and propagated through view updates.
public struct Transaction: Sendable {
    private var values: [ObjectIdentifier: AnySendable]
    var isExplicit: Bool

    public init(animation: Animation? = nil, disablesAnimations: Bool = false) {
        values = [:]
        isExplicit = false
        self.animation = animation
        self.disablesAnimations = disablesAnimations
    }

    public subscript<Key: TransactionKey>(key: Key.Type) -> Key.Value {
        get {
            values[ObjectIdentifier(Key.self)]?.value as? Key.Value ?? Key.defaultValue
        }
        set {
            values[ObjectIdentifier(Key.self)] = AnySendable(newValue)
        }
    }

    public var animation: Animation? {
        get { self[AnimationTransactionKey.self] }
        set { self[AnimationTransactionKey.self] = newValue }
    }

    public var disablesAnimations: Bool {
        get { self[DisablesAnimationsTransactionKey.self] }
        set { self[DisablesAnimationsTransactionKey.self] = newValue }
    }

    public static var current: Transaction {
        TransactionContext.current
    }

    static var disablingAnimations: Transaction {
        var transaction = Transaction(animation: nil, disablesAnimations: true)
        transaction.isExplicit = true
        return transaction
    }

    var effectiveAnimation: Animation? {
        disablesAnimations ? nil : animation
    }

    mutating func merge(_ other: Transaction) {
        for (key, value) in other.values {
            values[key] = value
        }
        isExplicit = isExplicit || other.isExplicit
    }
}

extension Transaction: Equatable {
    public static func == (lhs: Transaction, rhs: Transaction) -> Bool {
        lhs.animation == rhs.animation
            && lhs.disablesAnimations == rhs.disablesAnimations
            && lhs.isExplicit == rhs.isExplicit
    }
}

private struct AnySendable: @unchecked Sendable {
    var value: Any

    init(_ value: Any) {
        self.value = value
    }
}

enum TransactionContext {
    @TaskLocal static var current = Transaction()
}

@discardableResult
public func withTransaction<Result>(
    _ transaction: Transaction,
    _ body: () throws -> Result
) rethrows -> Result {
    var merged = Transaction.current
    merged.merge(transaction)
    return try TransactionContext.$current.withValue(merged) {
        try body()
    }
}

@discardableResult
public func withTransaction<Result, Value>(
    _ keyPath: WritableKeyPath<Transaction, Value>,
    _ value: Value,
    _ body: () throws -> Result
) rethrows -> Result {
    var transaction = Transaction()
    transaction[keyPath: keyPath] = value
    return try withTransaction(transaction, body)
}

@discardableResult
public func withAnimation<Result>(
    _ animation: Animation? = .default,
    _ body: () throws -> Result
) rethrows -> Result {
    var transaction = Transaction()
    transaction.animation = animation
    transaction.disablesAnimations = animation == nil
    transaction.isExplicit = true
    return try withTransaction(transaction, body)
}
