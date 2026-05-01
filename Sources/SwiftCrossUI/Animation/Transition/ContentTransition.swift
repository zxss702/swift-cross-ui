/// A transition applied when a view's rendered content changes.
public struct ContentTransition: Hashable, Sendable {
    public static let identity = Self(kind: .identity)
    public static let interpolate = Self(kind: .interpolate)
    public static let opacity = Self(kind: .opacity)

    private enum Kind: Hashable, Sendable {
        case identity
        case interpolate
        case opacity
        case numericText(countsDown: Bool?)
        case numericTextValue(Double)
    }

    private var kind: Kind

    private init(kind: Kind) {
        self.kind = kind
    }

    var animatesByOpacity: Bool {
        switch kind {
            case .identity:
                false
            case .interpolate, .opacity, .numericText, .numericTextValue:
                true
        }
    }

    public static func numericText(countsDown: Bool = false) -> Self {
        Self(kind: .numericText(countsDown: countsDown))
    }

    public static func numericText(value: Double) -> Self {
        Self(kind: .numericTextValue(value))
    }
}

extension EnvironmentValues {
    @Entry public var contentTransition: ContentTransition = .identity
}

extension View {
    /// Sets the content transition for this view branch.
    public func contentTransition(_ transition: ContentTransition) -> some View {
        ContentTransitionModifierView(content: self, transition: transition)
    }
}

protocol ContentTransitionFingerprintProvider {
    var contentTransitionFingerprint: String { get }
}

extension Text: ContentTransitionFingerprintProvider {
    var contentTransitionFingerprint: String {
        string
    }
}

struct ContentTransitionModifierView<Content: View>: TypeSafeView {
    typealias Children = ContentTransitionChildren

    var body: TupleView1<Content>
    var transition: ContentTransition

    init(content: Content, transition: ContentTransition) {
        body = TupleView1(content)
        self.transition = transition
    }

    func children<Backend: AppBackend>(
        backend: Backend,
        snapshots: [ViewGraphSnapshotter.NodeSnapshot]?,
        environment: EnvironmentValues
    ) -> ContentTransitionChildren {
        let view = renderedContent(phase: 1)
        return ContentTransitionChildren(
            content: view,
            fingerprint: contentTransitionFingerprint(body.view0),
            backend: backend,
            snapshot: snapshots?.first,
            environment: environment.with(\.contentTransition, transition)
        )
    }

    func asWidget<Backend: AppBackend>(
        _ children: ContentTransitionChildren,
        backend: Backend
    ) -> Backend.Widget {
        let container = backend.createContainer()
        backend.insert(children.node.getWidget().into(), into: container, at: 0)
        return container
    }

    func computeLayout<Backend: AppBackend>(
        _ widget: Backend.Widget,
        children: ContentTransitionChildren,
        proposedSize: ProposedViewSize,
        environment: EnvironmentValues,
        backend: Backend
    ) -> ViewLayoutResult {
        children.proposedSize = proposedSize
        let fingerprint = contentTransitionFingerprint(body.view0)
        let changed = children.fingerprint != fingerprint
        children.fingerprint = fingerprint
        children.pendingTransition = changed && transition.animatesByOpacity

        let phase = children.pendingTransition ? 0.0 : 1.0
        let (_, result) = children.node.computeLayoutWithNewView(
            renderedContent(phase: phase),
            proposedSize,
            environment.with(\.contentTransition, transition)
        )
        return result
    }

    func commit<Backend: AppBackend>(
        _ widget: Backend.Widget,
        children: ContentTransitionChildren,
        layout: ViewLayoutResult,
        environment: EnvironmentValues,
        backend: Backend
    ) {
        _ = children.node.commit()
        backend.setSize(of: widget, to: layout.size.vector)
        backend.setPosition(ofChildAt: 0, in: widget, to: .zero)
        completeTransitionIfNeeded(
            children: children,
            environment: environment,
            backend: backend
        )
    }

    private func renderedContent(phase: Double) -> AnyView {
        if transition.animatesByOpacity {
            AnyView(body.view0.opacity(phase))
        } else {
            AnyView(body.view0)
        }
    }

    @MainActor
    private func completeTransitionIfNeeded<Backend: AppBackend>(
        children: ContentTransitionChildren,
        environment: EnvironmentValues,
        backend: Backend
    ) {
        guard children.pendingTransition else {
            return
        }

        children.pendingTransition = false
        let transaction = environment.transaction
        let updateEnvironment = environment
            .withCurrentTransaction(transaction)
            .with(\.contentTransition, transition)
        let update: @MainActor () -> Void = {
            _ = children.node.computeLayoutWithNewView(
                renderedContent(phase: 1),
                children.proposedSize,
                updateEnvironment
            )
            _ = children.node.commit()
        }

        guard let graphUpdateHost = environment.graphUpdateHost else {
            backend.runInMainThread(action: update)
            return
        }

        graphUpdateHost.enqueue(
            backend: backend,
            transaction: transaction,
            key: AnyHashable(ObjectIdentifier(children)),
            action: update
        )
    }
}

final class ContentTransitionChildren: ViewGraphNodeChildren {
    var node: ErasedViewGraphNode
    var fingerprint: String
    var proposedSize = ProposedViewSize.zero
    var pendingTransition = false

    var widgets: [AnyWidget] {
        [node.getWidget()]
    }

    var erasedNodes: [ErasedViewGraphNode] {
        [node]
    }

    init<Backend: AppBackend>(
        content: AnyView,
        fingerprint: String,
        backend: Backend,
        snapshot: ViewGraphSnapshotter.NodeSnapshot?,
        environment: EnvironmentValues
    ) {
        self.fingerprint = fingerprint
        node = ErasedViewGraphNode(
            for: content,
            backend: backend,
            snapshot: snapshot,
            environment: environment
        )
    }
}

private func contentTransitionFingerprint(_ value: Any) -> String {
    if let provider = value as? ContentTransitionFingerprintProvider {
        return "\(type(of: value)):\(provider.contentTransitionFingerprint)"
    }

    let mirror = Mirror(reflecting: value)
    guard !mirror.children.isEmpty else {
        return "\(type(of: value)):\(String(describing: value))"
    }

    let children = mirror.children.compactMap { child -> String? in
        let label = child.label ?? "_"
        if label == "modification" {
            return nil
        }
        return "\(label)=\(contentTransitionFingerprint(child.value))"
    }
    return "\(type(of: value))(\(children.joined(separator: ",")))"
}
