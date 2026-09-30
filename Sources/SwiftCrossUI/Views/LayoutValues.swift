/// A key for accessing a layout value associated with a view.
///
/// Layout values travel with a view so that custom layouts can read them.
/// SwiftCrossUI's layout protocol isn't implemented yet; values are stored
/// on the view and become observable once custom layout support lands.
public protocol LayoutValueKey {
    /// The type of value this key holds.
    associatedtype Value

    /// The default value for views that don't set a value for this key.
    static var defaultValue: Value { get }
}

/// A view that stores layout values alongside its content.
struct LayoutValuesView<Content: View>: View {
    var content: Content
    var values: [ObjectIdentifier: Any]

    var body: some View {
        content
    }
}

extension View {
    /// Sets a layout value for this view.
    ///
    /// The value is stored on the view and will be readable by custom layouts
    /// once SwiftCrossUI's layout protocol lands.
    public func layoutValue<K: LayoutValueKey>(key: K.Type, value: K.Value) -> some View {
        var values: [ObjectIdentifier: Any]
        if let existing = self as? LayoutValuesView<AnyView> {
            values = existing.values
        } else {
            values = [:]
        }
        values[ObjectIdentifier(K.self)] = value
        return LayoutValuesView(content: AnyView(self), values: values)
    }
}

/// The dimensions and explicit alignment guides of a view, passed to
/// ``View/alignmentGuide(_:computeValue:)``.
public struct ViewDimensions: Sendable {
    /// The view's width.
    public var width: Double = 0

    /// The view's height.
    public var height: Double = 0

    /// Explicit horizontal guide values, keyed by alignment kind.
    var explicitHorizontal: [HorizontalAlignment: Double] = [:]

    /// Explicit vertical guide values, keyed by alignment kind.
    var explicitVertical: [VerticalAlignment: Double] = [:]

    /// Returns the guide's implicit value if the view doesn't have an
    /// explicit value for it.
    public subscript(guide: HorizontalAlignment) -> Double {
        explicitHorizontal[guide] ?? defaultValue(for: guide)
    }

    /// Returns the guide's implicit value if the view doesn't have an
    /// explicit value for it.
    public subscript(guide: VerticalAlignment) -> Double {
        explicitVertical[guide] ?? defaultValue(for: guide)
    }

    /// Returns the view's explicit value for the guide, or `nil` if the view
    /// doesn't have one.
    public subscript(explicit guide: HorizontalAlignment) -> Double? {
        explicitHorizontal[guide]
    }

    /// Returns the view's explicit value for the guide, or `nil` if the view
    /// doesn't have one.
    public subscript(explicit guide: VerticalAlignment) -> Double? {
        explicitVertical[guide]
    }

    /// The geometric default for an alignment guide.
    private func defaultValue(for guide: HorizontalAlignment) -> Double {
        guide.position(ofChild: width, in: width)
    }

    /// The geometric default for an alignment guide.
    private func defaultValue(for guide: VerticalAlignment) -> Double {
        guide.position(ofChild: height, in: height)
    }
}

/// A view that records an explicit alignment guide for its content.
struct AlignmentGuideView<Content: View>: View {
    var content: Content
    var horizontal: HorizontalAlignment?
    var vertical: VerticalAlignment?
    var computeValue: (ViewDimensions) -> Double

    var body: some View {
        content
    }
}

extension View {
    /// Sets an explicit horizontal alignment guide for this view.
    ///
    /// The computed value is recorded with the view; consumption by stack
    /// and custom layouts is planned for a future release.
    public func alignmentGuide(
        _ guide: HorizontalAlignment,
        computeValue: @escaping (ViewDimensions) -> Double
    ) -> some View {
        AlignmentGuideView(
            content: self,
            horizontal: guide,
            vertical: nil,
            computeValue: computeValue
        )
    }

    /// Sets an explicit vertical alignment guide for this view.
    ///
    /// The computed value is recorded with the view; consumption by stack
    /// and custom layouts is planned for a future release.
    public func alignmentGuide(
        _ guide: VerticalAlignment,
        computeValue: @escaping (ViewDimensions) -> Double
    ) -> some View {
        AlignmentGuideView(
            content: self,
            horizontal: nil,
            vertical: guide,
            computeValue: computeValue
        )
    }
}
