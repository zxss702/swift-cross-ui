import Dispatch
import Foundation

/// A view that renders content using values produced by keyframes.
public struct KeyframeAnimator<Value, KeyframePath: Keyframes, Content: View>: TypeSafeView
where KeyframePath.Value == Value {
    typealias Children = KeyframeAnimatorChildren

    public var body = EmptyView()
    private var initialValue: Value
    private var trigger: AnyEquatableValue?
    private var repeats: Bool
    private var content: (Value) -> Content
    private var keyframes: (Value) -> KeyframePath

    public init(
        initialValue: Value,
        trigger: some Equatable,
        @ViewBuilder content: @escaping (Value) -> Content,
        @KeyframesBuilder<Value> keyframes: @escaping (Value) -> KeyframePath
    ) {
        self.initialValue = initialValue
        self.trigger = AnyEquatableValue(trigger)
        self.repeats = false
        self.content = content
        self.keyframes = keyframes
    }

    public init(
        initialValue: Value,
        repeating: Bool = true,
        @ViewBuilder content: @escaping (Value) -> Content,
        @KeyframesBuilder<Value> keyframes: @escaping (Value) -> KeyframePath
    ) {
        self.initialValue = initialValue
        self.trigger = nil
        self.repeats = repeating
        self.content = content
        self.keyframes = keyframes
    }

    func children<Backend: AppBackend>(
        backend: Backend,
        snapshots: [ViewGraphSnapshotter.NodeSnapshot]?,
        environment: EnvironmentValues
    ) -> KeyframeAnimatorChildren {
        KeyframeAnimatorChildren(
            content: AnyView(content(initialValue)),
            trigger: trigger,
            shouldRun: trigger == nil,
            backend: backend,
            snapshot: snapshots?.first,
            environment: environment
        )
    }

    func asWidget<Backend: AppBackend>(
        _ children: KeyframeAnimatorChildren,
        backend: Backend
    ) -> Backend.Widget {
        let container = backend.createContainer()
        backend.insert(children.node.getWidget().into(), into: container, at: 0)
        return container
    }

    func computeLayout<Backend: AppBackend>(
        _ widget: Backend.Widget,
        children: KeyframeAnimatorChildren,
        proposedSize: ProposedViewSize,
        environment: EnvironmentValues,
        backend: Backend
    ) -> ViewLayoutResult {
        resetIfNeeded(children: children)
        let timeline = makeTimeline()
        children.duration = timeline.duration
        children.proposedSize = proposedSize
        let keyframeEnvironment = keyframeRenderEnvironment(environment)
        let (_, result) = children.node.computeLayoutWithNewView(
            AnyView(content(sampledValue(from: timeline, children: children))),
            proposedSize,
            keyframeEnvironment
        )
        return result
    }

    func commit<Backend: AppBackend>(
        _ widget: Backend.Widget,
        children: KeyframeAnimatorChildren,
        layout: ViewLayoutResult,
        environment: EnvironmentValues,
        backend: Backend
    ) {
        let layout = updatedRenderLayoutIfNeeded(
            children: children,
            layout: layout,
            environment: environment
        )
        _ = children.node.commit()
        backend.setSize(of: widget, to: layout.size.vector)
        backend.setPosition(ofChildAt: 0, in: widget, to: .zero)
        scheduleNextFrameIfNeeded(children: children, environment: environment)
    }

    private func makeTimeline() -> KeyframeTimeline<Value> {
        makeKeyframeTimeline(
            from: keyframes(initialValue),
            initialValue: initialValue
        )
    }

    private func sampledValue(
        from timeline: KeyframeTimeline<Value>,
        children: KeyframeAnimatorChildren
    ) -> Value {
        let duration = timeline.duration
        guard duration > 0 else {
            return timeline.value(time: 0)
        }
        return timeline.value(time: min(max(children.elapsedTime, 0), duration))
    }

    private func resetIfNeeded(children: KeyframeAnimatorChildren) {
        guard children.trigger != trigger else {
            return
        }
        children.trigger = trigger
        children.generation += 1
        children.scheduledGeneration = nil
        children.startTime = nil
        children.shouldRun = true
        children.elapsedTime = 0
    }

    private func scheduleNextFrameIfNeeded(
        children: KeyframeAnimatorChildren,
        environment: EnvironmentValues
    ) {
        guard children.shouldRun, children.scheduledGeneration == nil else {
            return
        }
        guard children.duration > 0 else {
            finishInstantAnimation(children: children)
            return
        }
        let generation = children.generation
        children.scheduledGeneration = generation
        scheduleNextFrame(
            requestFrame: environment.requestRenderFrame
        )
    }

    private func finishInstantAnimation(children: KeyframeAnimatorChildren) {
        children.shouldRun = false
    }

    private func scheduleNextFrame(
        requestFrame: @escaping @MainActor (Transaction) -> Void
    ) {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        requestFrame(transaction)
    }

    private func updatedRenderLayoutIfNeeded(
        children: KeyframeAnimatorChildren,
        layout: ViewLayoutResult,
        environment: EnvironmentValues
    ) -> ViewLayoutResult {
        guard RenderFrameContext.isRendering else {
            return layout
        }

        if children.scheduledGeneration == children.generation {
            children.scheduledGeneration = nil
        }

        let timeline = makeTimeline()
        children.duration = timeline.duration
        updateElapsedTime(
            children: children,
            duration: timeline.duration,
            startsIfNeeded: true
        )

        let keyframeEnvironment = keyframeRenderEnvironment(environment)
        let (_, result) = children.node.computeLayoutWithNewView(
            AnyView(content(sampledValue(from: timeline, children: children))),
            children.proposedSize,
            keyframeEnvironment
        )
        return result
    }

    private func keyframeRenderEnvironment(_ environment: EnvironmentValues) -> EnvironmentValues {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        return environment.withCurrentTransaction(transaction)
    }

    private func updateElapsedTime(
        children: KeyframeAnimatorChildren,
        duration: TimeInterval,
        startsIfNeeded: Bool
    ) {
        guard children.shouldRun, duration > 0 else {
            return
        }

        let now = RenderFrameContext.currentTime
        guard let startTime = children.startTime else {
            if startsIfNeeded {
                children.startTime = now
            }
            children.elapsedTime = 0
            return
        }

        let elapsed = now.secondsSince(startTime)
        if elapsed >= duration {
            if repeats {
                children.startTime = now
                children.elapsedTime = 0
            } else {
                children.shouldRun = false
                children.startTime = nil
                children.elapsedTime = duration
            }
        } else {
            children.elapsedTime = elapsed
        }
    }
}

class KeyframeAnimatorChildren: ViewGraphNodeChildren {
    var node: ErasedViewGraphNode
    var trigger: AnyEquatableValue?
    var shouldRun: Bool
    var duration: TimeInterval = 0
    var elapsedTime: TimeInterval = 0
    var generation = 0
    var scheduledGeneration: Int?
    var startTime: DispatchTime?
    var proposedSize = ProposedViewSize.zero

    var widgets: [AnyWidget] {
        [node.getWidget()]
    }

    var erasedNodes: [ErasedViewGraphNode] {
        [node]
    }

    init<Backend: AppBackend>(
        content: AnyView,
        trigger: AnyEquatableValue?,
        shouldRun: Bool,
        backend: Backend,
        snapshot: ViewGraphSnapshotter.NodeSnapshot?,
        environment: EnvironmentValues
    ) {
        self.trigger = trigger
        self.shouldRun = shouldRun
        node = ErasedViewGraphNode(
            for: content,
            backend: backend,
            snapshot: snapshot,
            environment: environment
        )
    }
}

extension DispatchTime {
    func secondsSince(_ start: DispatchTime) -> TimeInterval {
        guard uptimeNanoseconds >= start.uptimeNanoseconds else {
            return 0
        }
        return TimeInterval(uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000_000
    }
}

extension View {
    public func keyframeAnimator<Value>(
        initialValue: Value,
        trigger: some Equatable,
        @ViewBuilder content: @escaping (PlaceholderContentView<Self>, Value) -> some View,
        @KeyframesBuilder<Value> keyframes: @escaping (Value) -> some Keyframes<Value>
    ) -> some View {
        KeyframeAnimator(initialValue: initialValue, trigger: trigger) { value in
            content(PlaceholderContentView(self), value)
        } keyframes: { value in
            keyframes(value)
        }
    }

    public func keyframeAnimator<Value>(
        initialValue: Value,
        repeating: Bool = true,
        @ViewBuilder content: @escaping (PlaceholderContentView<Self>, Value) -> some View,
        @KeyframesBuilder<Value> keyframes: @escaping (Value) -> some Keyframes<Value>
    ) -> some View {
        KeyframeAnimator(initialValue: initialValue, repeating: repeating) { value in
            content(PlaceholderContentView(self), value)
        } keyframes: { value in
            keyframes(value)
        }
    }
}
