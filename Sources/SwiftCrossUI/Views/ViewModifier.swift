/// A modifier that you apply to a view or another view modifier, producing a
/// different version of the original value.
public protocol ViewModifier {
    /// The type of view representing the body of the modified content.
    associatedtype Body: View

    /// Gets the current body of the modifier.
    @ViewBuilder @MainActor func body(content: _ViewModifier_Content<Self>) -> Body
}

extension ViewModifier {
    /// The content passed to the modifier's body.
    public typealias Content = _ViewModifier_Content<Self>
}

/// The content view passed to a ``ViewModifier``'s `body(content:)` method.
public struct _ViewModifier_Content<Modifier: ViewModifier>: View {
    /// The view the modifier was applied to.
    var wrappedView: AnyView

    init(wrappedView: AnyView) {
        self.wrappedView = wrappedView
    }

    public var body: some View {
        wrappedView
    }
}

/// A value and a set of changes to apply to the value.
public struct ModifiedContent<Content: View, Modifier: ViewModifier>: View {
    /// The content that the modifier transforms into a new view.
    public private(set) var content: Content

    /// The modifier to apply to the content.
    public private(set) var modifier: Modifier

    /// Creates an instance that applies a modifier to a view.
    public init(content: Content, modifier: Modifier) {
        self.content = content
        self.modifier = modifier
    }

    public var body: some View {
        modifier.body(content: Modifier.Content(wrappedView: AnyView(content)))
    }
}

extension View {
    /// Applies a modifier to a view and returns a new view.
    public func modifier<T: ViewModifier>(_ modifier: T) -> ModifiedContent<Self, T> {
        ModifiedContent(content: self, modifier: modifier)
    }
}

/// A view type that holds dynamic properties (such as `@State` and
/// `@Environment`) within stored sub-values rather than directly in its own
/// stored properties.
///
/// `ViewGraphNode` updates a view's own dynamic properties, but it cannot see
/// properties nested inside fields such as ``ModifiedContent``'s `modifier`,
/// which never becomes a view graph node of its own. Conforming types let the
/// node update those nested properties alongside its own.
protocol _NestedDynamicProperties {
    /// Updates dynamic properties nested inside the value's stored properties.
    ///
    /// - Parameters:
    ///   - environment: The environment the value is being updated within.
    ///   - previousValue: The previous instance of this value, if any. Used to
    ///     carry over state between updates.
    @MainActor func _updateNestedDynamicProperties(
        with environment: EnvironmentValues,
        previousValue: Any?
    )

    /// Visits each nested observable property so that the view graph can
    /// observe it for changes.
    @MainActor func _forEachNestedObservableProperty(
        _ body: (any ObservableProperty) -> Void
    )
}

extension ModifiedContent: _NestedDynamicProperties {
    // The modifier never becomes a view graph node, so its dynamic properties
    // (e.g. `@Environment`) must be updated by the `ModifiedContent` node.
    // The content gets its own node and is therefore not updated here.
    @MainActor func _updateNestedDynamicProperties(
        with environment: EnvironmentValues,
        previousValue: Any?
    ) {
        DynamicPropertyUpdater(for: modifier).update(
            modifier,
            with: environment,
            previousValue: (previousValue as? Self)?.modifier
        )
    }

    @MainActor func _forEachNestedObservableProperty(
        _ body: (any ObservableProperty) -> Void
    ) {
        forEachField(of: modifier) { _, _, fieldValue in
            if let property = fieldValue as? any ObservableProperty {
                body(property)
            }
        }
    }
}
