/// A property wrapper that creates ``Binding`` values for reference type properties.
///
/// This is primarily intended for use with models observed through Swift's
/// Observation framework, mirroring SwiftUI's `@Bindable`.
@dynamicMemberLookup
@propertyWrapper
public struct Bindable<Value: AnyObject>: DynamicProperty {
    public var wrappedValue: Value

    public var projectedValue: Self {
        self
    }

    public init(wrappedValue: Value) {
        self.wrappedValue = wrappedValue
    }

    public init(_ wrappedValue: Value) {
        self.wrappedValue = wrappedValue
    }

    public init(projectedValue: Self) {
        self = projectedValue
    }

    public subscript<Subject>(
        dynamicMember keyPath: ReferenceWritableKeyPath<Value, Subject>
    ) -> Binding<Subject> {
        Binding(
            get: {
                wrappedValue[keyPath: keyPath]
            },
            set: { newValue in
                wrappedValue[keyPath: keyPath] = newValue
            }
        )
    }

    public func update(with environment: EnvironmentValues, previousValue: Bindable<Value>?) {}
}
