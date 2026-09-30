/// Alignment of items layed out along the vertical axis.
public enum VerticalAlignment: Sendable, Hashable {
    /// Top alignment.
    case top
    /// Center alignment.
    case center
    /// Bottom alignment.
    case bottom
    /// Alignment along the first text baseline. Currently treated like
    /// ``bottom`` during stack layout; font-metric-aware baseline alignment
    /// is planned for a future release.
    case firstTextBaseline
    /// Alignment along the last text baseline. Currently treated like
    /// ``bottom`` during stack layout.
    case lastTextBaseline

    /// Converts this value to a ``StackAlignment``.
    var asStackAlignment: StackAlignment {
        switch self {
            case .top:
                .leading
            case .center:
                .center
            case .bottom, .firstTextBaseline, .lastTextBaseline:
                .trailing
        }
    }

    /// Gets the position of a child of a given height in a frame of a given
    /// height using the alignment.
    /// - Parameter childHeight: The height of the child.
    /// - Parameter frameHeight: The height of the frame.
    /// - Returns: The position of the child.
    func position(ofChild childHeight: Double, in frameHeight: Double) -> Double {
        switch self {
            case .top: 0
            case .center: (frameHeight - childHeight) / 2
            case .bottom, .firstTextBaseline, .lastTextBaseline:
                frameHeight - childHeight
        }
    }
}
