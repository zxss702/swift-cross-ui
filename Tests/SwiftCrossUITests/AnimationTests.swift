import Testing

import DummyBackend
@testable import SwiftCrossUI

@Suite("Testing SwiftUI-style animation APIs")
struct AnimationTests {
    @Test("Binding writes carry their transaction")
    func bindingTransactionPropagation() {
        var value = 0
        var observedTransaction = Transaction()
        let binding = Binding(
            get: { value },
            set: { newValue, transaction in
                value = newValue
                observedTransaction = transaction
            }
        )
        .animation(.linear(duration: 2))

        binding.wrappedValue = 4

        #expect(value == 4)
        #expect(observedTransaction.animation?.estimatedDuration == 2)
    }

    @Test("Keyframe tracks combine into one root timeline")
    func keyframeTimelineCombinesTracks() {
        let timeline = makeKeyframeTimeline(
            from: CombinedKeyframes<KeyframePoint>(
                components: [
                    AnyKeyframes(
                        KeyframeTrack(\KeyframePoint.x) {
                            LinearKeyframe(10, duration: 1)
                        }
                    ),
                    AnyKeyframes(
                        KeyframeTrack(\KeyframePoint.y) {
                            LinearKeyframe(20, duration: 1)
                        }
                    ),
                ]
            ),
            initialValue: KeyframePoint(x: 0, y: 0)
        )

        let midpoint = timeline.value(time: 0.5)

        #expect(midpoint.x.isApproximatelyEqual(to: 5))
        #expect(midpoint.y.isApproximatelyEqual(to: 10))
    }

    @Test("Unit curves and repeated animations sample expected values")
    func animationSampling() {
        var context = AnimationContext<Double>()
        let value = Animation.linear(duration: 2).animate(
            value: 10,
            time: 1,
            context: &context
        )

        #expect(value?.isApproximatelyEqual(to: 5) == true)
        #expect(!context.isLogicallyComplete)

        let completed = Animation.linear(duration: 2).animate(
            value: 10,
            time: 2,
            context: &context
        )

        #expect(completed?.isApproximatelyEqual(to: 10) == true)
        #expect(context.isLogicallyComplete)
    }

    @Test("Transaction completion overlay is idempotent")
    func transactionCompletionOverlayIsIdempotent() {
        let completionCounter = CompletionCounter()
        var transaction = Transaction(animation: .linear(duration: 1))
        transaction.addAnimationCompletion {
            completionCounter.runs += 1
        }

        var combined = Transaction()
        for _ in 0..<100 {
            combined = combined.overlaid(by: transaction)
        }

        combined.runCompletions(matching: .logicallyComplete)
        combined.runCompletions(matching: .logicallyComplete)

        #expect(completionCounter.runs == 1)
    }

    @Test("Repeat forever has no finite logical duration")
    func repeatForeverHasNoFiniteLogicalDuration() {
        let animation = Animation.linear(duration: 0.2).repeatForever()
        var context = AnimationContext<Double>()
        _ = animation.animate(value: 1, time: 0.2, context: &context)

        #expect(animation.estimatedDuration == .infinity)
        #expect(!context.isLogicallyComplete)
    }

    @Test("Smooth springs do not overshoot their target")
    func smoothSpringDoesNotOvershoot() {
        let animation = Animation.smooth(duration: 0.65)

        #expect(animation.estimatedDuration.isApproximatelyEqual(to: 0.65))

        for step in 0...60 {
            var context = AnimationContext<Double>()
            let time = animation.estimatedDuration * Double(step) / 60
            let value = animation.animate(
                value: 1,
                time: time,
                context: &context
            )

            #expect((value ?? 0) >= 0)
            #expect((value ?? 0) <= 1.001)
        }
    }

    @Test("Presentation frame requests are coalesced")
    @MainActor
    func presentationFrameRequestsAreCoalesced() async throws {
        let backend = DummyBackend()
        let counter = RenderFrameCounter()
        let environment = EnvironmentValues(backend: backend)
            .with(\.requestRenderFrame) { _ in
                counter.count += 1
            }
        let transaction = Transaction(animation: .linear(duration: 1))
        let animation = PresentationAnimation<Double>()

        _ = animation.value(
            for: 0,
            transaction: Transaction(),
            environment: environment
        ) { transaction in
            environment.requestRenderFrame(transaction)
        }
        _ = animation.value(
            for: 10,
            transaction: transaction,
            environment: environment
        ) { transaction in
            environment.requestRenderFrame(transaction)
        }
        _ = animation.value(
            for: 20,
            transaction: transaction,
            environment: environment
        ) { transaction in
            environment.requestRenderFrame(transaction)
        }

        try await Task.sleep(nanoseconds: 50_000_000)

        #expect(counter.count == 1)
    }

    @Test("Delayed first presentation sample starts at the current presentation")
    @MainActor
    func delayedFirstPresentationSampleStartsAtCurrentPresentation() async throws {
        let backend = DummyBackend()
        let environment = EnvironmentValues(backend: backend)
        let transaction = Transaction(animation: .linear(duration: 0.01))
        let animation = PresentationAnimation<Double>()

        _ = animation.value(
            for: 0,
            transaction: Transaction(),
            environment: environment
        ) { _ in }
        let initialPresentation = animation.value(
            for: 10,
            transaction: transaction,
            environment: environment
        ) { _ in }

        try await Task.sleep(nanoseconds: 50_000_000)

        let delayedFirstSample = animation.value(
            for: 10,
            transaction: transaction,
            environment: environment
        ) { _ in }

        #expect(initialPresentation.isApproximatelyEqual(to: 0))
        #expect(delayedFirstSample.isApproximatelyEqual(to: 0))
    }

    @Test("Multiple State writes in one action coalesce into one graph update")
    @MainActor
    func multipleStateWritesCoalesceIntoOneGraphUpdate() async throws {
        let backend = DummyBackend()
        let window = backend.createSurface(withDefaultSize: nil as SIMD2<Int>?)
        let environment = EnvironmentValues(backend: backend)
            .with(\.window, window)
        let counter = BodyCounter()
        let viewGraph = ViewGraph(
            for: BatchedStateProbe(counter: counter),
            backend: backend,
            environment: environment
        )

        _ = viewGraph.computeLayout(
            proposedSize: ProposedViewSize(200, 200),
            environment: environment
        )
        viewGraph.commit()

        let initialBodyRuns = counter.runs
        let rootWidget: DummyBackend.Widget = viewGraph.rootNode.widget.into()
        let button = try #require(rootWidget.firstWidget(ofType: DummyBackend.Button.self))
        button.action?()

        try await Task.sleep(nanoseconds: 50_000_000)

        #expect(counter.runs == initialBodyRuns + 1)
    }

    @Test("Unread State writes do not invalidate the graph")
    @MainActor
    func unreadStateWritesDoNotInvalidateGraph() async throws {
        let backend = DummyBackend()
        let window = backend.createSurface(withDefaultSize: nil as SIMD2<Int>?)
        let environment = EnvironmentValues(backend: backend)
            .with(\.window, window)
        let counter = BodyCounter()
        let viewGraph = ViewGraph(
            for: UnreadStateProbe(counter: counter),
            backend: backend,
            environment: environment
        )

        _ = viewGraph.computeLayout(
            proposedSize: ProposedViewSize(200, 200),
            environment: environment
        )
        viewGraph.commit()

        let initialBodyRuns = counter.runs
        let rootWidget: DummyBackend.Widget = viewGraph.rootNode.widget.into()
        let button = try #require(rootWidget.firstWidget(ofType: DummyBackend.Button.self))
        button.action?()

        try await Task.sleep(nanoseconds: 50_000_000)

        #expect(counter.runs == initialBodyRuns)
    }

    @Test("Multiple Published writes in one action coalesce into one graph update")
    @MainActor
    func multiplePublishedWritesCoalesceIntoOneGraphUpdate() async throws {
        let backend = DummyBackend()
        let window = backend.createSurface(withDefaultSize: nil as SIMD2<Int>?)
        let environment = EnvironmentValues(backend: backend)
            .with(\.window, window)
        let counter = BodyCounter()
        let viewGraph = ViewGraph(
            for: BatchedObservableProbe(counter: counter),
            backend: backend,
            environment: environment
        )

        _ = viewGraph.computeLayout(
            proposedSize: ProposedViewSize(200, 200),
            environment: environment
        )
        viewGraph.commit()

        let initialBodyRuns = counter.runs
        let rootWidget: DummyBackend.Widget = viewGraph.rootNode.widget.into()
        let button = try #require(rootWidget.firstWidget(ofType: DummyBackend.Button.self))
        button.action?()

        try await Task.sleep(nanoseconds: 50_000_000)

        #expect(counter.runs == initialBodyRuns + 1)
    }

    @Test("Triggered PhaseAnimator advances through all phases")
    @MainActor
    func triggeredPhaseAnimatorAdvancesThroughAllPhases() async throws {
        let backend = DummyBackend()
        let window = backend.createSurface(withDefaultSize: nil as SIMD2<Int>?)
        let environment = EnvironmentValues(backend: backend)
            .with(\.window, window)

        func makeView(trigger: Int) -> some View {
            PhaseAnimator([0, 1, 2], trigger: trigger) { phase in
                Text("\(phase)")
            } animation: { _ in
                .linear(duration: 0.01)
            }
        }

        let viewGraph = ViewGraph(
            for: makeView(trigger: 0),
            backend: backend,
            environment: environment
        )
        _ = viewGraph.computeLayout(
            proposedSize: ProposedViewSize(200, 200),
            environment: environment
        )
        viewGraph.commit()

        _ = viewGraph.computeLayout(
            with: makeView(trigger: 1),
            proposedSize: ProposedViewSize(200, 200),
            environment: environment
        )
        viewGraph.commit()

        try await Task.sleep(nanoseconds: 100_000_000)

        let rootWidget: DummyBackend.Widget = viewGraph.rootNode.widget.into()
        let textView = try #require(
            rootWidget.firstWidget(ofType: DummyBackend.TextView.self)
        )
        #expect(textView.content == "2")
    }

    @Test("SwiftUI-style animation declarations compile")
    @MainActor
    func swiftUIStyleDeclarationsCompile() {
        _ = AnimationAPICompilationView(flag: true)
    }
}

private final class CompletionCounter: @unchecked Sendable {
    var runs = 0
}

@MainActor
private final class RenderFrameCounter {
    var count = 0
}

@MainActor
private final class BodyCounter {
    var runs = 0

    func record() {
        runs += 1
    }
}

private struct BatchedStateProbe: View {
    @State private var first = 0
    @State private var second = 0
    @State private var third = 0

    var counter: BodyCounter

    var body: some View {
        let _ = counter.record()
        VStack {
            Button("Mutate") {
                first += 1
                second += 1
                third += 1
            }
            Text("\(first),\(second),\(third)")
        }
    }
}

private struct UnreadStateProbe: View {
    @State private var hidden = 0

    var counter: BodyCounter

    var body: some View {
        let _ = counter.record()
        Button("Mutate") {
            hidden += 1
        }
    }
}

private final class BatchedObservableModel: SwiftCrossUI.ObservableObject {
    @SwiftCrossUI.Published var first = 0
    @SwiftCrossUI.Published var second = 0
    @SwiftCrossUI.Published var third = 0
}

private struct BatchedObservableProbe: View {
    @State private var model = BatchedObservableModel()

    var counter: BodyCounter

    var body: some View {
        let _ = counter.record()
        VStack {
            Button("Mutate") {
                model.first += 1
                model.second += 1
                model.third += 1
            }
            Text("\(model.first),\(model.second),\(model.third)")
        }
    }
}

private struct KeyframePoint: Animatable, Equatable {
    var x: Double
    var y: Double

    var animatableData: AnimatablePair<Double, Double> {
        get {
            AnimatablePair(x, y)
        }
        set {
            x = newValue.first
            y = newValue.second
        }
    }
}

private struct AnimationAPICompilationView: View {
    var flag: Bool

    var body: some View {
        VStack {
            if flag {
                Text("Visible")
                    .transition(
                        .asymmetric(
                            insertion: .scale.combined(with: .opacity),
                            removal: .move(edge: .top).animation(.easeInOut)
                        )
                    )
            }

            Text("Phase")
                .phaseAnimator([false, true], trigger: flag) { content, phase in
                    content.opacity(phase ? 1 : 0.25)
                } animation: { _ in
                    .snappy(duration: 0.2)
                }

            Text("Keyframe")
                .keyframeAnimator(initialValue: 0.0, trigger: flag) { content, value in
                    content
                        .offset(x: value, y: 0)
                        .scaleEffect(x: 1 + value / 100, y: 1, anchor: .topLeading)
                        .blur(radius: value / 20)
                        .blur(radius: value / 30, opaque: true)
                } keyframes: { _ in
                    LinearKeyframe(20.0, duration: 0.2)
                    CubicKeyframe(0.0, duration: 0.2)
                }
        }
        .transition(.blurReplace)
        .transition(.blurReplace(.upUp))
        .animation(.spring(duration: 0.3, bounce: 0.2), value: flag)
        .transaction { transaction in
            transaction.isContinuous = true
        }
        .rotationEffect(.zero)
    }
}

private extension Double {
    func isApproximatelyEqual(to other: Double) -> Bool {
        abs(self - other) < 0.01
    }
}
