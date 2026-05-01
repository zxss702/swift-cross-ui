import Dispatch
import Foundation

/// A transaction-aware readable and writable state location.
protocol Location<Value>: AnyObject {
    associatedtype Value

    var value: Value { get set }

    func set(_ value: Value, transaction: Transaction)
}

extension Location {
    func set(_ value: Value, transaction: Transaction) {
        self.value = value
    }
}

/// A type-erased state location.
final class AnyLocation<Value> {
    private let getValue: () -> Value
    private let setValue: (Value, Transaction) -> Void

    init<L: Location>(_ location: L) where L.Value == Value {
        getValue = { location.value }
        setValue = { value, transaction in
            location.set(value, transaction: transaction)
        }
    }

    init(get: @escaping () -> Value, set: @escaping (Value, Transaction) -> Void) {
        self.getValue = get
        self.setValue = set
    }

    var value: Value {
        get {
            getValue()
        }
        set {
            set(newValue, transaction: TransactionContext.current)
        }
    }

    func set(_ value: Value, transaction: Transaction) {
        setValue(value, transaction)
    }
}

/// A basic stored location used by state wrappers.
final class StoredLocation<Value>: Location {
    var value: Value
    private let onSet: (Transaction) -> Void

    init(_ value: Value, onSet: @escaping (Transaction) -> Void = { _ in }) {
        self.value = value
        self.onSet = onSet
    }

    func set(_ value: Value, transaction: Transaction) {
        self.value = value
        onSet(transaction)
    }
}

enum StateMutationContext {
    private static let key = "SwiftCrossUI.StateMutation.transaction"

    static var currentTransaction: Transaction {
        Thread.current.threadDictionary[key] as? Transaction ?? Transaction()
    }

    static func record(_ transaction: Transaction) {
        Thread.current.threadDictionary[key] = transaction
    }

    static func withTransaction(_ transaction: Transaction, _ body: () -> Void) {
        let previous = Thread.current.threadDictionary[key]
        Thread.current.threadDictionary[key] = transaction
        defer {
            if let previous {
                Thread.current.threadDictionary[key] = previous
            } else {
                Thread.current.threadDictionary.removeObject(forKey: key)
            }
        }
        body()
    }
}

enum GraphUpdateContext {
    private static let key = "SwiftCrossUI.GraphUpdate.isUpdating"
    private static let updatedKeysKey = "SwiftCrossUI.GraphUpdate.updatedKeys"

    static var isUpdating: Bool {
        Thread.current.threadDictionary[key] as? Bool ?? false
    }

    static func withUpdating<Result>(_ body: () throws -> Result) rethrows -> Result {
        if isUpdating {
            return try body()
        }

        let previous = Thread.current.threadDictionary[key]
        Thread.current.threadDictionary[key] = true
        defer {
            if let previous {
                Thread.current.threadDictionary[key] = previous
            } else {
                Thread.current.threadDictionary.removeObject(forKey: key)
            }
        }
        return try body()
    }

    static func withMutationTracking<Result>(_ body: () throws -> Result) rethrows -> Result {
        if Thread.current.threadDictionary[updatedKeysKey] != nil {
            return try body()
        }

        let previous = Thread.current.threadDictionary[updatedKeysKey]
        Thread.current.threadDictionary[updatedKeysKey] = Set<AnyHashable>()
        defer {
            if let previous {
                Thread.current.threadDictionary[updatedKeysKey] = previous
            } else {
                Thread.current.threadDictionary.removeObject(forKey: updatedKeysKey)
            }
        }
        return try body()
    }

    static func hasUpdated(key: AnyHashable) -> Bool {
        updatedKeys.contains(key)
    }

    static func markUpdated(key: AnyHashable) {
        var keys = updatedKeys
        keys.insert(key)
        Thread.current.threadDictionary[updatedKeysKey] = keys
    }

    private static var updatedKeys: Set<AnyHashable> {
        Thread.current.threadDictionary[updatedKeysKey] as? Set<AnyHashable> ?? []
    }
}

enum RenderFrameContext {
    private static let key = "SwiftCrossUI.RenderFrame.isRendering"
    private static let timeKey = "SwiftCrossUI.RenderFrame.time"

    static var isRendering: Bool {
        Thread.current.threadDictionary[key] as? Bool ?? false
    }

    static var currentTime: DispatchTime {
        Thread.current.threadDictionary[timeKey] as? DispatchTime ?? DispatchTime.now()
    }

    static func withRendering<Result>(_ body: () throws -> Result) rethrows -> Result {
        try withRendering(at: DispatchTime.now()) {
            try body()
        }
    }

    static func withRendering<Result>(
        at time: DispatchTime,
        _ body: () throws -> Result
    ) rethrows -> Result {
        if isRendering {
            return try body()
        }

        let previous = Thread.current.threadDictionary[key]
        let previousTime = Thread.current.threadDictionary[timeKey]
        Thread.current.threadDictionary[key] = true
        Thread.current.threadDictionary[timeKey] = time
        defer {
            if let previous {
                Thread.current.threadDictionary[key] = previous
            } else {
                Thread.current.threadDictionary.removeObject(forKey: key)
            }
            if let previousTime {
                Thread.current.threadDictionary[timeKey] = previousTime
            } else {
                Thread.current.threadDictionary.removeObject(forKey: timeKey)
            }
        }
        return try body()
    }
}
