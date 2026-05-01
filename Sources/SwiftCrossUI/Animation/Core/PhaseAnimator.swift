/// A view that renders content for a sequence of phases.
public struct PhaseAnimator<Phase: Equatable, Content: View>: TypeSafeView {
    typealias Children = PhaseAnimatorChildren

    public var body = EmptyView()
    private var phases: [Phase]
    private var trigger: AnyEquatableValue?
    private var content: (Phase) -> Content
    private var animation: (Phase) -> Animation?
    @State private var currentPhaseIndex = 0

    public init(
        _ phases: some Sequence<Phase>,
        trigger: some Equatable,
        @ViewBuilder content: @escaping (Phase) -> Content,
        animation: @escaping (Phase) -> Animation? = { _ in .default }
    ) {
        self.phases = Array(phases)
        self.trigger = AnyEquatableValue(trigger)
        self.content = content
        self.animation = animation
    }

    public init(
        _ phases: some Sequence<Phase>,
        @ViewBuilder content: @escaping (Phase) -> Content,
        animation: @escaping (Phase) -> Animation? = { _ in .default }
    ) {
        self.phases = Array(phases)
        self.trigger = nil
        self.content = content
        self.animation = animation
    }

    func children<Backend: AppBackend>(
        backend: Backend,
        snapshots: [ViewGraphSnapshotter.NodeSnapshot]?,
        environment: EnvironmentValues
    ) -> PhaseAnimatorChildren {
        PhaseAnimatorChildren(
            content: AnyView(content(currentPhase)),
            trigger: trigger,
            backend: backend,
            snapshot: snapshots?.first,
            environment: environment
        )
    }

    func asWidget<Backend: AppBackend>(
        _ children: PhaseAnimatorChildren,
        backend: Backend
    ) -> Backend.Widget {
        let container = backend.createContainer()
        backend.insert(children.node.getWidget().into(), into: container, at: 0)
        return container
    }

    func computeLayout<Backend: AppBackend>(
        _ widget: Backend.Widget,
        children: PhaseAnimatorChildren,
        proposedSize: ProposedViewSize,
        environment: EnvironmentValues,
        backend: Backend
    ) -> ViewLayoutResult {
        resetIfNeeded(children: children)
        let (_, result) = children.node.computeLayoutWithNewView(
            AnyView(content(currentPhase)),
            proposedSize,
            environment
        )
        return result
    }

    func commit<Backend: AppBackend>(
        _ widget: Backend.Widget,
        children: PhaseAnimatorChildren,
        layout: ViewLayoutResult,
        environment: EnvironmentValues,
        backend: Backend
    ) {
        _ = children.node.commit()
        backend.setSize(of: widget, to: layout.size.vector)
        backend.setPosition(ofChildAt: 0, in: widget, to: .zero)
        scheduleNextPhaseIfNeeded(
            children: children,
            environment: environment,
            backend: backend
        )
    }

    private var currentPhase: Phase {
        guard !phases.isEmpty else {
            fatalError("PhaseAnimator requires at least one phase")
        }
        return phases[min(currentPhaseIndex, phases.count - 1)]
    }

    private func resetIfNeeded(children: PhaseAnimatorChildren) {
        guard children.trigger != trigger else {
            return
        }
        children.trigger = trigger
        children.generation += 1
        currentPhaseIndex = 0
    }

    private func scheduleNextPhaseIfNeeded<Backend: AppBackend>(
        children: PhaseAnimatorChildren,
        environment: EnvironmentValues,
        backend: Backend
    ) {
        guard phases.count > 1, children.scheduledGeneration != children.generation else {
            return
        }
        children.scheduledGeneration = children.generation
        scheduleNextPhase(
            children: children,
            generation: children.generation,
            environment: environment,
            backend: backend
        )
    }

    private func scheduleNextPhase<Backend: AppBackend>(
        children: PhaseAnimatorChildren,
        generation: Int,
        environment: EnvironmentValues,
        backend: Backend
    ) {
        let nextIndex = (currentPhaseIndex + 1) % phases.count
        let nextPhase = phases[nextIndex]
        let duration = animation(nextPhase)?.estimatedDuration ?? 0.35
        let transaction = Transaction(animation: animation(nextPhase))

        guard let graphUpdateHost = environment.graphUpdateHost else {
            backend.runInMainThread {
                guard children.generation == generation else {
                    return
                }
                withTransaction(transaction) {
                    currentPhaseIndex = nextIndex
                }
                if trigger == nil {
                    children.scheduledGeneration = nil
                }
            }
            return
        }

        graphUpdateHost.enqueueAfter(
            backend: backend,
            delay: duration,
            transaction: transaction,
            key: AnyHashable(ObjectIdentifier(children))
        ) {
            guard children.generation == generation else {
                return
            }
            currentPhaseIndex = nextIndex
            if trigger == nil {
                children.scheduledGeneration = nil
            }
        }
    }
}

class PhaseAnimatorChildren: ViewGraphNodeChildren {
    var node: ErasedViewGraphNode
    var trigger: AnyEquatableValue?
    var generation = 0
    var scheduledGeneration: Int?

    var widgets: [AnyWidget] {
        [node.getWidget()]
    }

    var erasedNodes: [ErasedViewGraphNode] {
        [node]
    }

    init<Backend: AppBackend>(
        content: AnyView,
        trigger: AnyEquatableValue?,
        backend: Backend,
        snapshot: ViewGraphSnapshotter.NodeSnapshot?,
        environment: EnvironmentValues
    ) {
        self.trigger = trigger
        node = ErasedViewGraphNode(
            for: content,
            backend: backend,
            snapshot: snapshot,
            environment: environment,
        )
    }
}

struct AnyEquatableValue: Equatable {
    private let value: Any
    private let equals: (Any) -> Bool

    init<Value: Equatable>(_ value: Value) {
        self.value = value
        self.equals = { other in
            guard let other = other as? Value else {
                return false
            }
            return other == value
        }
    }

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.equals(rhs.value)
    }
}

extension View {
    public func phaseAnimator<Phase: Equatable>(
        _ phases: some Sequence<Phase>,
        trigger: some Equatable,
        @ViewBuilder content: @escaping (PlaceholderContentView<Self>, Phase) -> some View,
        animation: @escaping (Phase) -> Animation? = { _ in .default }
    ) -> some View {
        PhaseAnimator(phases, trigger: trigger) { phase in
            content(PlaceholderContentView(self), phase)
        } animation: { phase in
            animation(phase)
        }
    }

    public func phaseAnimator<Phase: Equatable>(
        _ phases: some Sequence<Phase>,
        @ViewBuilder content: @escaping (PlaceholderContentView<Self>, Phase) -> some View,
        animation: @escaping (Phase) -> Animation? = { _ in .default }
    ) -> some View {
        PhaseAnimator(phases) { phase in
            content(PlaceholderContentView(self), phase)
        } animation: { phase in
            animation(phase)
        }
    }
}
