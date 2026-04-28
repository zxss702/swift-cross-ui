import Testing

import DummyBackend
@testable import SwiftCrossUI

private final class CommitProbe: @unchecked Sendable {
    var count = 0
    var transactions: [Transaction] = []
}

private struct CoalescedStateUpdateView: View {
    @State var left = 0
    @State var right = 0
    let probe: CommitProbe

    var body: some View {
        VStack {
            Button("Mutate") {
                withAnimation(.easeOut(duration: 0.2)) {
                    left += 1
                    right += 1
                }
            }
            Text("\(left)-\(right)")
        }
        .onCommit {
            probe.count += 1
            probe.transactions.append(Transaction.current)
        }
    }
}

private struct ExplicitNilAnimationView: View {
    @State var faded = false

    var body: some View {
        VStack {
            Button("No animation") {
                withAnimation(nil) {
                    faded.toggle()
                }
            }
            Color.blue
                .opacity(faded ? 0.2 : 1)
                .animation(.linear(duration: 1))
        }
    }
}

@Suite("Animation tests")
struct AnimationTests: Sendable {
    @Test("withAnimation installs the current transaction")
    func withAnimationSetsCurrentTransaction() {
        #expect(Transaction.current.animation == nil)
        #expect(!Transaction.current.disablesAnimations)

        let observed = withAnimation(.easeIn(duration: 0.25)) {
            Transaction.current
        }

        #expect(observed.animation == .easeIn(duration: 0.25))
        #expect(!observed.disablesAnimations)
        #expect(Transaction.current.animation == nil)
    }

    @Test("withAnimation(nil) disables animations")
    func withAnimationNilDisablesAnimations() {
        let observed = withAnimation(nil) {
            Transaction.current
        }

        #expect(observed.animation == nil)
        #expect(observed.disablesAnimations)
    }

    @Test("Internal disabled transaction is explicit")
    func internalDisabledTransactionIsExplicit() {
        let transaction = Transaction.disablingAnimations

        #expect(transaction.animation == nil)
        #expect(transaction.disablesAnimations)
        #expect(transaction.isExplicit)
    }

    @MainActor
    @Test("AnimationRuntime clamps backend size and transform values")
    func animationRuntimeClampsBackendValues() {
        let backend = DummyBackend()
        let widget = backend.createContainer()
        let environment = EnvironmentValues(backend: backend)
            .with(\.transaction, Transaction.disablingAnimations)

        AnimationRuntime.setSize(
            of: widget,
            to: SIMD2(-12, 8),
            environment: environment,
            backend: backend
        )
        #expect(widget.size == SIMD2(0, 8))

        AnimationRuntime.setTransform(
            of: widget,
            to: ViewTransform(
                scale: SIMD2(-1, 2),
                translation: SIMD2(10, -4),
                anchor: .center
            ),
            environment: environment,
            backend: backend
        )
        #expect(widget.scale == SIMD2(0, 2))
        #expect(widget.translation == SIMD2(10, -4))
    }

    @Test("Publisher forwards transactions through linked publishers")
    func publisherForwardsTransactions() {
        let upstream = Publisher()
        let downstream = Publisher()
        let cancellable = downstream.link(toUpstream: upstream)
        _ = cancellable

        var observed: Transaction?
        let observation = downstream.observe { transaction in
            observed = transaction
        }
        _ = observation

        withAnimation(.snappy) {
            upstream.send()
        }

        #expect(observed?.animation == .snappy)
        #expect(observed?.disablesAnimations == false)
    }

    @Test("Animation repeat progress follows autoreverse cycles")
    func animationRepeatProgress() {
        let animation = Animation.linear(duration: 1)
            .repeatCount(2, autoreverses: true)

        #expect(animation.value(at: 0) == 0)
        #expect(animation.value(at: 0.5) == 0.5)
        #expect(animation.value(at: 1.25) == 0.75)
        #expect(animation.value(at: 2) == 0)
        #expect(animation.isComplete(at: 1.9) == false)
        #expect(animation.isComplete(at: 2) == true)
    }

    @MainActor
    @Test("AnimationRuntime can interrupt an in-flight opacity animation")
    func animationRuntimeInterruptsInFlightAnimation() async throws {
        let backend = DummyBackend()
        let widget = backend.createContainer()
        let environment = EnvironmentValues(backend: backend)
            .with(
                \.transaction,
                Transaction(animation: .linear(duration: 0.25))
            )

        backend.setOpacity(of: widget, to: 1)
        AnimationRuntime.setOpacity(
            of: widget,
            to: 0,
            environment: environment,
            backend: backend
        )

        try await Task.sleep(nanoseconds: 80_000_000)
        let interruptedOpacity = widget.opacity
        #expect(interruptedOpacity < 1)
        #expect(interruptedOpacity > 0)

        AnimationRuntime.setOpacity(
            of: widget,
            to: 1,
            environment: environment,
            backend: backend
        )
        #expect(widget.opacity == interruptedOpacity)

        try await Task.sleep(nanoseconds: 320_000_000)
        #expect(widget.opacity == 1)
    }

    @MainActor
    @Test("withAnimation nil cancels in-flight runtime animations")
    func withAnimationNilCancelsInFlightRuntimeAnimations() async throws {
        let backend = DummyBackend()
        let widget = backend.createContainer()
        let animatedEnvironment = EnvironmentValues(backend: backend)
            .with(\.transaction, Transaction(animation: .linear(duration: 1)))
        let disabledEnvironment = EnvironmentValues(backend: backend)
            .with(\.transaction, Transaction.disablingAnimations)

        backend.setOpacity(of: widget, to: 1)
        AnimationRuntime.setOpacity(
            of: widget,
            to: 0,
            environment: animatedEnvironment,
            backend: backend
        )

        try await Task.sleep(nanoseconds: 80_000_000)
        #expect(widget.opacity < 1)
        #expect(widget.opacity > 0)

        AnimationRuntime.setOpacity(
            of: widget,
            to: 1,
            environment: disabledEnvironment,
            backend: backend
        )

        #expect(widget.opacity == 1)
        try await Task.sleep(nanoseconds: 120_000_000)
        #expect(widget.opacity == 1)
    }

    @MainActor
    @Test("View updates coalesce multiple state changes in one action")
    func viewUpdatesCoalesceMultipleStateChanges() async throws {
        let backend = DummyBackend()
        let window = backend.createWindow(withDefaultSize: nil)
        let environment = EnvironmentValues(backend: backend).with(\.window, window)
        let probe = CommitProbe()
        let viewGraph = ViewGraph(
            for: CoalescedStateUpdateView(probe: probe),
            backend: backend,
            environment: environment
        )

        _ = viewGraph.computeLayout(proposedSize: .unspecified, environment: environment)
        viewGraph.commit()

        let baselineCommitCount = probe.count
        let rootWidget: DummyBackend.Widget = viewGraph.rootNode.widget.into()
        let button = try #require(rootWidget.firstWidget(ofType: DummyBackend.Button.self))
        let text = try #require(rootWidget.firstWidget(ofType: DummyBackend.TextView.self))

        button.action?()
        try await Task.sleep(nanoseconds: 100_000_000)

        #expect(text.content == "1-1")
        #expect(probe.count == baselineCommitCount + 1)
        #expect(probe.transactions.last?.animation == .easeOut(duration: 0.2))
    }

    @MainActor
    @Test("Explicit withAnimation nil overrides ambient animation modifiers")
    func explicitNilAnimationOverridesAmbientAnimationModifier() async throws {
        let backend = DummyBackend()
        let window = backend.createWindow(withDefaultSize: nil)
        let environment = EnvironmentValues(backend: backend).with(\.window, window)
        let viewGraph = ViewGraph(
            for: ExplicitNilAnimationView(),
            backend: backend,
            environment: environment
        )

        _ = viewGraph.computeLayout(proposedSize: .unspecified, environment: environment)
        viewGraph.commit()

        let rootWidget: DummyBackend.Widget = viewGraph.rootNode.widget.into()
        let button = try #require(rootWidget.firstWidget(ofType: DummyBackend.Button.self))

        button.action?()
        try await Task.sleep(nanoseconds: 100_000_000)

        let opacities = Self.allWidgets(from: rootWidget).map(\.opacity)
        #expect(opacities.contains { abs($0 - 0.2) < 0.000_1 })
    }

    private static func allWidgets(from root: DummyBackend.Widget) -> [DummyBackend.Widget] {
        var widgets = [root]
        var index = 0
        while index < widgets.count {
            widgets.append(contentsOf: widgets[index].getChildren())
            index += 1
        }
        return widgets
    }
}
