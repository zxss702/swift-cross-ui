/// A key for values exposed by the currently focused view.
public protocol FocusedValueKey {
    /// The value type associated with this key.
    associatedtype Value
}

/// Values exposed by the currently focused view, read via
/// `@FocusedValue` and written via ``View/focusedValue(_:_:)``.
public struct FocusedValues: Sendable {
    var storage: [ObjectIdentifier: Any] = [:]

    /// Reads or writes the value for a focused value key.
    public subscript<Key: FocusedValueKey>(_ key: Key.Type) -> Key.Value? {
        get { storage[ObjectIdentifier(key)] as? Key.Value }
        set { storage[ObjectIdentifier(key)] = newValue }
    }
}

extension EnvironmentValues {
    /// Values propagated by focused views to their containing hierarchy.
    @Entry public var focusedValues = FocusedValues()
}

extension View {
    /// Exposes a value when this view (or a descendant) is focused.
    public func focusedValue<Value>(
        _ keyPath: WritableKeyPath<FocusedValues, Value?>,
        _ value: Value
    ) -> some View {
        EnvironmentModifier(self) { environment in
            var focusedValues = environment.focusedValues
            focusedValues[keyPath: keyPath] = value
            return environment.with(\.focusedValues, focusedValues)
        }
    }

    /// Exposes an object value when this view is focused.
    public func focusedValue<T: AnyObject>(
        _ object: T?
    ) -> some View {
        EnvironmentModifier(self) { environment in
            var focusedValues = environment.focusedValues
            if let object {
                focusedValues[FocusedObjectKey.self] = object
            }
            return environment.with(\.focusedValues, focusedValues)
        }
    }
}

/// The storage key used by ``View/focusedValue(_:)`` for object values.
struct FocusedObjectKey: FocusedValueKey {
    typealias Value = AnyObject
}

/// A property wrapper reading a value exposed by the focused view,
/// mirroring SwiftUI's `@FocusedValue`.
@propertyWrapper
public struct FocusedValue<Value>: DynamicProperty {
    private let keyPath: KeyPath<FocusedValues, Value?>
    @Environment(\.focusedValues) private var values

    /// Creates a focused value reader.
    public init(_ keyPath: KeyPath<FocusedValues, Value?>) {
        self.keyPath = keyPath
    }

    public func update(with environment: EnvironmentValues, previousValue: Self?) {
        _values.update(with: environment, previousValue: previousValue?._values)
    }

    public var wrappedValue: Value? {
        values[keyPath: keyPath]
    }
}
