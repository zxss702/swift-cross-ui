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

    var animatesContentChange: Bool {
        switch kind {
            case .identity:
                false
            case .interpolate, .opacity, .numericText, .numericTextValue:
                true
        }
    }

    var changeToken: String {
        switch kind {
            case .identity:
                "identity"
            case .interpolate:
                "interpolate"
            case .opacity:
                "opacity"
            case .numericText(let countsDown):
                "numericText:\(countsDown == true)"
            case .numericTextValue(let value):
                "numericTextValue:\(value)"
        }
    }

    func numericDirection(previousValue: Double?) -> Double? {
        switch kind {
            case .numericText(let countsDown):
                return countsDown == true ? -1 : 1
            case .numericTextValue(let value):
                guard let previousValue, value != previousValue else {
                    return 1
                }
                return value > previousValue ? 1 : -1
            case .identity, .interpolate, .opacity:
                return nil
        }
    }

    var numericValue: Double? {
        if case .numericTextValue(let value) = kind {
            value
        } else {
            nil
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
        let view = AnyView(body.view0)
        return ContentTransitionChildren(
            content: view,
            fingerprint: contentTransitionFingerprint(body.view0),
            transitionToken: transition.changeToken,
            numericValue: transition.numericValue,
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
        let transitionToken = transition.changeToken
        let changed = children.fingerprint != fingerprint
            || children.transitionToken != transitionToken
        let previousNumericValue = children.numericValue
        let shouldTransition = changed
            && transition.animatesContentChange
            && environment.transaction.animation != nil
            && !environment.transaction.disablesAnimations

        if shouldTransition {
            children.startTransition(
                outgoingContent: children.currentContent,
                direction: transition.numericDirection(previousValue: previousNumericValue),
                backend: backend,
                environment: environment.with(\.contentTransition, transition)
            )
        } else {
            children.transitionPhase = 1
            if changed {
                children.outgoingCleanupRequested = true
            }
        }

        children.fingerprint = fingerprint
        children.transitionToken = transitionToken
        children.numericValue = transition.numericValue
        children.currentContent = AnyView(body.view0)
        children.pendingTransition = shouldTransition

        let phase = children.pendingTransition ? 0.0 : children.transitionPhase
        let (_, result) = children.node.computeLayoutWithNewView(
            renderedIncomingContent(AnyView(body.view0), phase: phase, children: children),
            proposedSize,
            environment.with(\.contentTransition, transition)
        )
        if let outgoingNode = children.outgoingNode,
            let outgoingContent = children.outgoingContent
        {
            _ = outgoingNode.computeLayoutWithNewView(
                renderedOutgoingContent(outgoingContent, phase: phase, children: children),
                proposedSize,
                environment.with(\.contentTransition, transition)
            )
        }
        return result
    }

    func commit<Backend: AppBackend>(
        _ widget: Backend.Widget,
        children: ContentTransitionChildren,
        layout: ViewLayoutResult,
        environment: EnvironmentValues,
        backend: Backend
    ) {
        syncOutgoingWidget(widget, children: children, backend: backend)
        _ = children.node.commit()
        if let outgoingNode = children.outgoingNode {
            _ = outgoingNode.commit()
        }
        backend.setSize(of: widget, to: layout.size.vector)
        backend.setPosition(ofChildAt: 0, in: widget, to: .zero)
        if children.outgoingWidgetInserted {
            backend.setPosition(ofChildAt: 1, in: widget, to: .zero)
        }
        completeTransitionIfNeeded(
            widget,
            children: children,
            environment: environment,
            backend: backend
        )
        cleanupOutgoingIfNeeded(widget, children: children, backend: backend)
    }

    private func renderedIncomingContent(
        _ content: AnyView,
        phase: Double,
        children: ContentTransitionChildren
    ) -> AnyView {
        guard transition.animatesContentChange else {
            return content
        }
        if let direction = children.transitionDirection {
            return AnyView(
                content
                    .opacity(phase)
                    .offset(y: (1 - phase) * direction * children.numericOffset)
            )
        }
        return AnyView(content.opacity(phase))
    }

    private func renderedOutgoingContent(
        _ content: AnyView,
        phase: Double,
        children: ContentTransitionChildren
    ) -> AnyView {
        if let direction = children.transitionDirection {
            return AnyView(
                content
                    .opacity(1 - phase)
                    .offset(y: -phase * direction * children.numericOffset)
            )
        }
        return AnyView(content.opacity(1 - phase))
    }

    private func syncOutgoingWidget<Backend: AppBackend>(
        _ widget: Backend.Widget,
        children: ContentTransitionChildren,
        backend: Backend
    ) {
        if children.outgoingWidgetNeedsReplacement && children.outgoingWidgetInserted {
            backend.remove(childAt: 1, from: widget)
            children.outgoingWidgetInserted = false
        }
        children.outgoingWidgetNeedsReplacement = false

        guard let outgoingNode = children.outgoingNode else {
            return
        }
        if !children.outgoingWidgetInserted {
            backend.insert(outgoingNode.getWidget().into(), into: widget, at: 1)
            children.outgoingWidgetInserted = true
        }
    }

    @MainActor
    private func completeTransitionIfNeeded<Backend: AppBackend>(
        _ widget: Backend.Widget,
        children: ContentTransitionChildren,
        environment: EnvironmentValues,
        backend: Backend
    ) {
        guard children.pendingTransition else {
            return
        }

        children.pendingTransition = false
        var transaction = environment.transaction
        if transaction.animation != nil && !transaction.disablesAnimations {
            transaction.addAnimationCompletion { [weak children] in
                MainActor.assumeIsolated {
                    children?.outgoingCleanupRequested = true
                }
            }
        } else {
            children.outgoingCleanupRequested = true
        }
        let updateEnvironment = environment
            .withCurrentTransaction(transaction)
            .with(\.contentTransition, transition)
        let update: @MainActor () -> Void = {
            children.transitionPhase = 1
            updateEnvironment.onResize(.zero)
        }

        guard let graphUpdateHost = environment.graphUpdateHost else {
            backend.runInMainThread {
                withTransaction(transaction) {
                    StateMutationContext.withTransaction(transaction) {
                        update()
                    }
                }
            }
            return
        }

        graphUpdateHost.enqueue(
            backend: backend,
            transaction: transaction,
            key: AnyHashable(ObjectIdentifier(children)),
            action: update
        )
    }

    private func cleanupOutgoingIfNeeded<Backend: AppBackend>(
        _ widget: Backend.Widget,
        children: ContentTransitionChildren,
        backend: Backend
    ) {
        guard children.outgoingCleanupRequested else {
            return
        }
        children.outgoingCleanupRequested = false
        children.outgoingNode = nil
        children.outgoingContent = nil
        if children.outgoingWidgetInserted {
            backend.remove(childAt: 1, from: widget)
            children.outgoingWidgetInserted = false
        }
    }
}

final class ContentTransitionChildren: ViewGraphNodeChildren, @unchecked Sendable {
    var node: ErasedViewGraphNode
    var fingerprint: String
    var transitionToken: String
    var numericValue: Double?
    var currentContent: AnyView
    var outgoingNode: ErasedViewGraphNode?
    var outgoingContent: AnyView?
    var proposedSize = ProposedViewSize.zero
    var pendingTransition = false
    var transitionPhase = 1.0
    var transitionDirection: Double?
    let numericOffset = 24.0
    var outgoingWidgetInserted = false
    var outgoingWidgetNeedsReplacement = false
    var outgoingCleanupRequested = false

    var widgets: [AnyWidget] {
        if let outgoingNode {
            [node.getWidget(), outgoingNode.getWidget()]
        } else {
            [node.getWidget()]
        }
    }

    var erasedNodes: [ErasedViewGraphNode] {
        if let outgoingNode {
            [node, outgoingNode]
        } else {
            [node]
        }
    }

    init<Backend: AppBackend>(
        content: AnyView,
        fingerprint: String,
        transitionToken: String,
        numericValue: Double?,
        backend: Backend,
        snapshot: ViewGraphSnapshotter.NodeSnapshot?,
        environment: EnvironmentValues
    ) {
        currentContent = content
        self.fingerprint = fingerprint
        self.transitionToken = transitionToken
        self.numericValue = numericValue
        node = ErasedViewGraphNode(
            for: content,
            backend: backend,
            snapshot: snapshot,
            environment: environment
        )
    }

    func startTransition<Backend: AppBackend>(
        outgoingContent: AnyView,
        direction: Double?,
        backend: Backend,
        environment: EnvironmentValues
    ) {
        if outgoingNode != nil {
            outgoingWidgetNeedsReplacement = true
        }
        self.outgoingContent = outgoingContent
        outgoingNode = ErasedViewGraphNode(
            for: outgoingContent,
            backend: backend,
            environment: environment
        )
        transitionPhase = 0
        transitionDirection = direction
        outgoingCleanupRequested = false
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
