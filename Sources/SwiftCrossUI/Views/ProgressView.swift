import Foundation

/// A progress indicator; either a bar or a spinner.
public struct ProgressView<Label: View>: View {
    /// The label for this progress view.
    private var label: Label
    /// The current progress, if this is a progress bar.
    private var progress: Double?
    private var kind: Kind
    private var isSpinnerResizable: Bool = false

    private enum Kind {
        case spinner
        case bar
    }

    public var body: some View {
        if label as? EmptyView == nil {
            progressIndicator
            label
        } else {
            progressIndicator
        }
    }

    @ViewBuilder
    private var progressIndicator: some View {
        switch kind {
            case .spinner:
                ProgressSpinnerView(isResizable: isSpinnerResizable)
            case .bar:
                ProgressBarView(value: progress)
        }
    }

    /// Creates an indeterminate progress view (a spinner).
    ///
    /// - Parameter label: The label for this progress view.
    public init(_ label: Label) {
        self.label = label
        self.kind = .spinner
    }

    /// Creates a progress bar.
    ///
    /// - Parameters:
    ///   - label: The label for this progress view.
    ///   - progress: The current progress.
    public init(_ label: Label, _ progress: Progress) {
        self.label = label
        self.kind = .bar

        if !progress.isIndeterminate {
            self.progress = progress.fractionCompleted
        }
    }

    /// Creates a progress bar.
    ///
    /// - Parameters:
    ///   - label: The label for this progress view.
    ///   - value: The current progress. If `nil`, an indeterminate progress bar
    ///     will be shown.
    public init<Value: BinaryFloatingPoint>(_ label: Label, value: Value?) {
        self.label = label
        self.kind = .bar
        self.progress = value.map { Double($0) }
    }

    /// Makes the `ProgressView` resize to fit the available space.
    ///
    /// This only affects spinners.
    public func resizable(_ isResizable: Bool = true) -> Self {
        var progressView = self
        progressView.isSpinnerResizable = isResizable
        return progressView
    }
}

extension ProgressView where Label == EmptyView {
    /// Creates an indeterminate progress view (a spinner).
    public init() {
        self.label = EmptyView()
        self.kind = .spinner
    }

    /// Creates a progress bar.
    ///
    /// - Parameters:
    ///   - progress: The current progress.
    public init(_ progress: Progress) {
        self.label = EmptyView()
        self.kind = .bar

        if !progress.isIndeterminate {
            self.progress = progress.fractionCompleted
        }
    }

    /// Creates a progress bar.
    ///
    /// - Parameters:
    ///   - value: The current progress. If `nil`, an indeterminate progress bar
    ///     will be shown.
    public init<Value: BinaryFloatingPoint>(value: Value?) {
        self.label = EmptyView()
        self.kind = .bar
        self.progress = value.map { Double($0) }
    }

    /// Creates a progress bar for tracking a task with a defined total amount
    /// of work, as in SwiftUI.
    ///
    /// - Parameters:
    ///   - value: The completed progress of the task so far.
    ///   - total: The total amount of work required to complete the task.
    public init<Value: BinaryFloatingPoint>(value: Value, total: Value) {
        self.label = EmptyView()
        self.kind = .bar
        self.progress = Double(value / total)
    }
}

extension ProgressView where Label == Text {
    /// Creates an indeterminate progress view (a spinner).
    ///
    /// - Parameter label: The label for this progress view.
    public init(_ label: String) {
        self.label = Text(label)
        self.kind = .spinner
    }

    /// Creates a progress bar.
    ///
    /// - Parameters:
    ///   - label: The label for this progress view.
    ///   - progress: The current progress.
    public init(_ label: String, _ progress: Progress) {
        self.label = Text(label)
        self.kind = .bar

        if !progress.isIndeterminate {
            self.progress = progress.fractionCompleted
        }
    }

    /// Creates a progress bar.
    ///
    /// - Parameters:
    ///   - label: The label for this progress view.
    ///   - value: The current progress. If `nil`, an indeterminate progress bar
    ///     will be shown.
    public init<Value: BinaryFloatingPoint>(_ label: String, value: Value?) {
        self.label = Text(label)
        self.kind = .bar
        self.progress = value.map { Double($0) }
    }
}

struct ProgressSpinnerView: ElementaryView {
    let isResizable: Bool

    init(isResizable: Bool = false) {
        self.isResizable = isResizable
    }

    func asWidget<Backend: BaseAppBackend>(backend: Backend) -> Backend.Widget {
        backend.createProgressSpinner()
    }

    func computeLayout<Backend: BaseAppBackend>(
        _ widget: Backend.Widget,
        proposedSize: ProposedViewSize,
        environment: EnvironmentValues,
        backend: Backend
    ) -> ViewLayoutResult {
        let naturalSize = backend.naturalSize(of: widget)

        guard isResizable else {
            return ViewLayoutResult.leafView(size: ViewSize(naturalSize))
        }

        let dimension: Double

        if let proposedWidth = proposedSize.width, let proposedHeight = proposedSize.height {
            dimension = min(proposedWidth, proposedHeight)
        } else if let proposedWidth = proposedSize.width {
            dimension = proposedWidth
        } else if let proposedHeight = proposedSize.height {
            dimension = proposedHeight
        } else {
            dimension = Double(min(naturalSize.x, naturalSize.y))
        }

        return ViewLayoutResult.leafView(
            size: ViewSize(dimension, dimension)
        )
    }

    func commit<Backend: BaseAppBackend>(
        _ widget: Backend.Widget,
        layout: ViewLayoutResult,
        environment: EnvironmentValues,
        backend: Backend
    ) {
        // Doesn't change the rendered size of ProgressSpinner
        // on UIKitBackend, but still sets container size to
        // (width: n, height: n) n = min(proposedSize.x, proposedSize.y)
        backend.setSize(ofProgressSpinner: widget, to: layout.size.vector)
    }
}

struct ProgressBarView: ElementaryView {
    /// The ideal width of a ProgressBarView.
    static let idealWidth: Double = 100

    var value: Double?

    init(value: Double?) {
        self.value = value
    }

    func asWidget<Backend: BaseAppBackend>(backend: Backend) -> Backend.Widget {
        backend.createProgressBar()
    }

    func computeLayout<Backend: BaseAppBackend>(
        _ widget: Backend.Widget,
        proposedSize: ProposedViewSize,
        environment: EnvironmentValues,
        backend: Backend
    ) -> ViewLayoutResult {
        let height = backend.naturalSize(of: widget).y
        let size = ViewSize(
            proposedSize.width ?? Self.idealWidth,
            Double(height)
        )

        return ViewLayoutResult.leafView(size: size)
    }

    func commit<Backend: BaseAppBackend>(
        _ widget: Backend.Widget,
        layout: ViewLayoutResult,
        environment: EnvironmentValues,
        backend: Backend
    ) {
        backend.updateProgressBar(widget, progressFraction: value, environment: environment)
        backend.setSize(of: widget, to: layout.size.vector)
    }
}

/// A type that applies a custom appearance to progress views, as in SwiftUI.
public protocol ProgressViewStyle: Sendable {}

/// A progress view style that renders as a spinning indicator.
public struct CircularProgressViewStyle: ProgressViewStyle {
    public init() {}
}

/// A progress view style that renders as a bar.
public struct LinearProgressViewStyle: ProgressViewStyle {
    public init() {}
}

/// The default progress view style for the current context.
public struct AutomaticProgressViewStyle: ProgressViewStyle {
    public init() {}
}

extension ProgressViewStyle where Self == CircularProgressViewStyle {
    /// The circular progress view style.
    public static var circular: CircularProgressViewStyle { .init() }
}

extension ProgressViewStyle where Self == LinearProgressViewStyle {
    /// The linear progress view style.
    public static var linear: LinearProgressViewStyle { .init() }
}

extension ProgressViewStyle where Self == AutomaticProgressViewStyle {
    /// The automatic progress view style.
    public static var automatic: AutomaticProgressViewStyle { .init() }
}

extension ProgressView {
    /// Sets the style for progress views within this view.
    ///
    /// Applied directly to this progress view; views nested deeper are
    /// unaffected (environmental style propagation is pending).
    public func progressViewStyle<S: ProgressViewStyle>(_ style: S) -> ProgressView<Label> {
        var copy = self
        if style is LinearProgressViewStyle {
            copy.kind = .bar
        } else if style is CircularProgressViewStyle {
            copy.kind = .spinner
        }
        return copy
    }
}
