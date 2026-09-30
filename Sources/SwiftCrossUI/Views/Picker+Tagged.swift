/// An option shown by a ``Picker``: the value that gets selected plus an
/// optional display label.
public struct PickerOption<Value: Equatable>: Equatable {
    /// The value stored into the picker's selection binding.
    public var value: Value
    /// The option's display label. Defaults to `String(describing: value)`
    /// when `nil`.
    public var label: String?

    public init(value: Value, label: String? = nil) {
        self.value = value
        self.label = label
    }
}

/// A view tagged with a value, used by ``Picker``'s content-builder form to
/// associate each option's label with the value it selects.
public struct TaggedView<Tag: Hashable, Content: View>: View {
    public var content: Content
    public var tag: Tag

    public init(content: Content, tag: Tag) {
        self.content = content
        self.tag = tag
    }

    public var body: some View { content }
}

extension View {
    /// Sets a tag identifying this view to the nearest enclosing picker or
    /// other tag-consuming container.
    public func tag<V: Hashable>(_ tag: V) -> TaggedView<V, Self> {
        TaggedView(content: self, tag: tag)
    }
}

/// Internal protocol enabling ``Picker`` to find tagged views within its
/// content without depending on the concrete view types involved.
protocol _TaggedViewCollectable {
    func _collectTags(into options: inout [(tag: AnyHashable, label: any View)])
}

extension TaggedView: _TaggedViewCollectable {
    func _collectTags(into options: inout [(tag: AnyHashable, label: any View)]) {
        options.append((tag: AnyHashable(tag), label: content))
    }
}

extension ForEach: _TaggedViewCollectable where Child: View {
    func _collectTags(into options: inout [(tag: AnyHashable, label: any View)]) {
        for element in elements {
            _collect(child(element), into: &options)
        }
    }
}

extension TupleView1: _TaggedViewCollectable {
    func _collectTags(into options: inout [(tag: AnyHashable, label: any View)]) {
        _collect(view0, into: &options)
    }
}

extension TupleView2: _TaggedViewCollectable {
    func _collectTags(into options: inout [(tag: AnyHashable, label: any View)]) {
        _collect(view0, into: &options)
        _collect(view1, into: &options)
    }
}

extension TupleView3: _TaggedViewCollectable {
    func _collectTags(into options: inout [(tag: AnyHashable, label: any View)]) {
        _collect(view0, into: &options)
        _collect(view1, into: &options)
        _collect(view2, into: &options)
    }
}

extension TupleView4: _TaggedViewCollectable {
    func _collectTags(into options: inout [(tag: AnyHashable, label: any View)]) {
        _collect(view0, into: &options)
        _collect(view1, into: &options)
        _collect(view2, into: &options)
        _collect(view3, into: &options)
    }
}

extension TupleView5: _TaggedViewCollectable {
    func _collectTags(into options: inout [(tag: AnyHashable, label: any View)]) {
        _collect(view0, into: &options)
        _collect(view1, into: &options)
        _collect(view2, into: &options)
        _collect(view3, into: &options)
        _collect(view4, into: &options)
    }
}

extension TupleView6: _TaggedViewCollectable {
    func _collectTags(into options: inout [(tag: AnyHashable, label: any View)]) {
        _collect(view0, into: &options)
        _collect(view1, into: &options)
        _collect(view2, into: &options)
        _collect(view3, into: &options)
        _collect(view4, into: &options)
        _collect(view5, into: &options)
    }
}

/// Collects tagged options from a view that may itself be collectable.
func _collect(_ view: any View, into options: inout [(tag: AnyHashable, label: any View)]) {
    if let collectable = view as? _TaggedViewCollectable {
        collectable._collectTags(into: &options)
    }
}

/// Extracts a display string from a tagged option's label view.
func _pickerLabel(of view: any View) -> String? {
    if let text = view as? Text {
        return text.string
    }
    if let tagged = view as? _TaggedViewLabelSource {
        return tagged._labelText
    }
    return nil
}

protocol _TaggedViewLabelSource {
    var _labelText: String? { get }
}

extension TaggedView: _TaggedViewLabelSource {
    var _labelText: String? {
        _pickerLabel(of: content)
    }
}

extension Picker {
    /// Creates a picker with a title and tagged content options, matching
    /// SwiftUI's `Picker(_:selection:content:)`.
    ///
    /// The content is inspected for ``TaggedView``s; each tag becomes a
    /// selectable option whose label is extracted from the tagged view.
    public init<Content: View>(
        _ title: String,
        selection: Binding<Value>,
        @ViewBuilder content: () -> Content
    ) {
        var collected: [(tag: AnyHashable, label: any View)] = []
        _collect(content(), into: &collected)
        self.init(
            labeledOptions: collected.compactMap { tag, label in
                guard let value = tag.base as? Value else { return nil }
                return PickerOption(value: value, label: _pickerLabel(of: label))
            },
            title: title,
            selection: selection
        )
    }

    /// Creates a picker with tagged content options.
    public init<Content: View>(
        selection: Binding<Value>,
        @ViewBuilder content: () -> Content
    ) {
        self.init("", selection: selection, content: content)
    }

    init(
        labeledOptions: [PickerOption<Value>],
        title: String,
        selection: Binding<Value>
    ) {
        self.init(
            of: labeledOptions,
            selection: Binding<Value?>(
                get: { selection.wrappedValue },
                set: { newValue in
                    if let newValue {
                        selection.wrappedValue = newValue
                    }
                }
            )
        )
    }
}
