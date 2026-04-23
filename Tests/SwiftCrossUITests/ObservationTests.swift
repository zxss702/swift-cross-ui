import Testing

import DummyBackend
@testable import SwiftCrossUI

#if canImport(Observation)
    import Observation

    @available(macOS 14.0, iOS 17.0, tvOS 17.0, watchOS 10.0, *)
    private final class TestObservationModel: Observation.Observable {
        private let registrar = ObservationRegistrar()
        private var _count = 0
        private var _name = "Initial"

        var count: Int {
            get {
                registrar.access(self, keyPath: \.count)
                return _count
            }
            set {
                registrar.withMutation(of: self, keyPath: \.count) {
                    _count = newValue
                }
            }
        }

        var name: String {
            get {
                registrar.access(self, keyPath: \.name)
                return _name
            }
            set {
                registrar.withMutation(of: self, keyPath: \.name) {
                    _name = newValue
                }
            }
        }
    }

    @available(macOS 14.0, iOS 17.0, tvOS 17.0, watchOS 10.0, *)
    private struct StateBackedObservationView: View {
        @State var model = TestObservationModel()

        var body: some View {
            VStack {
                Text("Count: \(model.count)")
                Button("Increment") {
                    model.count += 1
                }
            }
        }
    }

    @available(macOS 14.0, iOS 17.0, tvOS 17.0, watchOS 10.0, *)
    private struct EnvironmentBackedObservationView: View {
        @Environment(TestObservationModel.self) var model

        var body: some View {
            Text("Count: \(model.count)")
        }
    }

    @Suite("Observation support")
    struct ObservationTests: Sendable {
        @Test("@Bindable projects writable bindings for reference models")
        @available(macOS 14.0, iOS 17.0, tvOS 17.0, watchOS 10.0, *)
        func bindableProjectsBindings() {
            let model = TestObservationModel()
            let bindable = Bindable(wrappedValue: model)
            let nameBinding = bindable.projectedValue.name

            #expect(nameBinding.wrappedValue == "Initial")

            nameBinding.wrappedValue = "Updated"

            #expect(model.name == "Updated")
        }

        @MainActor
        @Test("@State forwards Observation-driven model changes into view updates")
        @available(macOS 14.0, iOS 17.0, tvOS 17.0, watchOS 10.0, *)
        func stateSupportsObservationModels() async throws {
            let backend = DummyBackend()
            let window = backend.createWindow(withDefaultSize: nil)
            let environment = EnvironmentValues(backend: backend)
                .with(\.window, window)

            let viewGraph = ViewGraph(
                for: StateBackedObservationView(),
                backend: backend,
                environment: environment
            )
            _ = viewGraph.computeLayout(
                proposedSize: .unspecified,
                environment: environment
            )
            viewGraph.commit()

            let rootWidget: DummyBackend.Widget = viewGraph.rootNode.widget.into()
            let textView = try #require(rootWidget.firstWidget(ofType: DummyBackend.TextView.self))
            let button = try #require(rootWidget.firstWidget(ofType: DummyBackend.Button.self))

            #expect(textView.content == "Count: 0")

            button.action?()
            try await Task.sleep(nanoseconds: 100_000_000)

            #expect(textView.content == "Count: 1")
        }

        @MainActor
        @Test("@Environment can read Observation-driven models from the environment")
        @available(macOS 14.0, iOS 17.0, tvOS 17.0, watchOS 10.0, *)
        func environmentSupportsObservationModels() async throws {
            let backend = DummyBackend()
            let window = backend.createWindow(withDefaultSize: nil)
            let environment = EnvironmentValues(backend: backend)
                .with(\.window, window)
            let model = TestObservationModel()

            let viewGraph = ViewGraph(
                for: EnvironmentBackedObservationView().environment(model),
                backend: backend,
                environment: environment
            )
            _ = viewGraph.computeLayout(
                proposedSize: .unspecified,
                environment: environment
            )
            viewGraph.commit()

            let rootWidget: DummyBackend.Widget = viewGraph.rootNode.widget.into()
            let textView = try #require(rootWidget.firstWidget(ofType: DummyBackend.TextView.self))

            #expect(textView.content == "Count: 0")

            model.count = 2
            try await Task.sleep(nanoseconds: 100_000_000)

            #expect(textView.content == "Count: 2")
        }
    }
#endif
