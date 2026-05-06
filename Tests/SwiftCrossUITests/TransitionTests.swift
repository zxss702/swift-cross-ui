import Testing

import DummyBackend
@testable import SwiftCrossUI

@Suite("Testing structural transitions")
struct TransitionTests {
    @MainActor
    @Test("Optional transition survives ViewBuilder single-child wrapping")
    func optionalTransitionSurvivesSingleChildWrapping() {
        let backend = DummyBackend()
        let window = backend.createSurface(withDefaultSize: nil as SIMD2<Int>?)
        let environment = EnvironmentValues(backend: backend)
            .with(\.window, window)
            .with(\.transaction, Transaction(animation: .linear(duration: 1)))

        let node = ViewGraphNode(
            for: OptionalTransitionProbe(isVisible: true),
            backend: backend,
            environment: environment
        )
        _ = node.computeLayout(proposedSize: .unspecified, environment: environment)
        _ = node.commit()

        _ = node.computeLayout(
            with: OptionalTransitionProbe(isVisible: false),
            proposedSize: .unspecified,
            environment: environment
        )
        _ = node.commit()

        #expect(!node.widget.getChildren().isEmpty)
    }
}

private struct OptionalTransitionProbe: View {
    var isVisible: Bool

    var body: some View {
        if isVisible {
            Text("visible")
                .transition(.opacity)
        }
    }
}
