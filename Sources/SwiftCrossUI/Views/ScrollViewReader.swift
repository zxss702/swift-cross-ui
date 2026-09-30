/// A request to scroll a target into view, delivered through the environment.
///
/// `ScrollView`s consume ``pending`` targets when backend scroll-to-position
/// support lands; the plumbing (proxy → box → environment → scroll view) is
/// live today.
public final class ScrollTargetBox: @unchecked Sendable {
    /// The most recent scroll request, cleared once consumed.
    public var pending: (id: AnyHashable, anchor: UnitPoint?)?
}

/// A proxy able to request scrolling of the enclosing scroll view.
public struct ScrollViewProxy: Sendable {
    var box: ScrollTargetBox

    /// Scrolls the view identified by `id` so that the given anchor is
    /// visible.
    public func scrollTo<ID: Hashable>(_ id: ID, anchor: UnitPoint? = nil) {
        box.pending = (AnyHashable(id), anchor)
    }
}

/// A view providing a ``ScrollViewProxy`` for programmatic scrolling,
/// mirroring SwiftUI's `ScrollViewReader`.
public struct ScrollViewReader<Content: View>: View {
    var content: (ScrollViewProxy) -> Content

    @State private var box = ScrollTargetBox()

    /// Creates a scroll view reader.
    public init(@ViewBuilder content: @escaping (ScrollViewProxy) -> Content) {
        self.content = content
    }

    public var body: some View {
        content(ScrollViewProxy(box: box))
            .environment(\.scrollTargetBox, box)
    }
}

extension EnvironmentValues {
    /// The scroll-target box of the enclosing ``ScrollViewReader``.
    @Entry public var scrollTargetBox: ScrollTargetBox?
}
