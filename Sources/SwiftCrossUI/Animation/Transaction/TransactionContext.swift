import Foundation

enum TransactionContext {
    private static let key = "SwiftCrossUI.Transaction.current"

    static var current: Transaction {
        get {
            Thread.current.threadDictionary[key] as? Transaction ?? Transaction()
        }
        set {
            Thread.current.threadDictionary[key] = newValue
        }
    }
}

/// Performs `body` with the supplied transaction as the current transaction.
public func withTransaction<Result>(
    _ transaction: Transaction,
    _ body: () throws -> Result
) rethrows -> Result {
    let previous = TransactionContext.current
    TransactionContext.current = transaction
    defer {
        TransactionContext.current = previous
    }
    return try body()
}

/// Performs `body` after changing one transaction value.
public func withTransaction<R, V>(
    _ keyPath: WritableKeyPath<Transaction, V>,
    _ value: V,
    _ body: () throws -> R
) rethrows -> R {
    var transaction = TransactionContext.current
    transaction[keyPath: keyPath] = value
    return try withTransaction(transaction, body)
}

/// Performs `body` with the supplied animation in the current transaction.
public func withAnimation<Result>(
    _ animation: Animation? = .default,
    _ body: () throws -> Result
) rethrows -> Result {
    try withTransaction(Transaction(animation: animation), body)
}

/// Performs `body` with an animation and registers a completion.
public func withAnimation<Result>(
    _ animation: Animation? = .default,
    completionCriteria: AnimationCompletionCriteria = .logicallyComplete,
    _ body: () throws -> Result,
    completion: @escaping @Sendable () -> Void
) rethrows -> Result {
    var transaction = Transaction(animation: animation)
    transaction.addAnimationCompletion(criteria: completionCriteria, completion)
    return try withTransaction(transaction, body)
}
