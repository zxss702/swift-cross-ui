import Foundation
import PerceptionCore

// TODO: This could possibly be renamed to ``SceneGraph`` now that that's basically the role
//   it has taken on since introducing scenes.
/// A top-level wrapper providing an entry point for the app. Exists to be able to persist
/// the view graph alongside the app (we can't do that on a user's ``App`` implementation because
/// we can only add computed properties).
@MainActor
class _App<AppRoot: App>: ViewModelObserver {
    /// The app being run.
    let app: AppRoot
    /// An instance of the app's selected backend.
    let backend: AppRoot.Backend
    /// The root of the app's scene graph.
    var sceneGraphRoot: AppRoot.Body.Node?
    /// Cancellables for observations of the app's state properties.
    var cancellables: [Cancellable]
    /// The root level environment.
    var environment: EnvironmentValues
    let graphUpdateHost = GraphUpdateHost()
    /// The dynamic property updater for ``app``.
    var dynamicPropertyUpdater: DynamicPropertyUpdater<AppRoot>
    
    /// Used by the `ViewModelObserver` protocol to prevent duplicate view updates.
    var currentViewModelObservationID: UUID?

    /// Wraps a user's app implementation.
    init(_ app: AppRoot) {
        backend = app.backend
        self.app = app
        self.environment = EnvironmentValues(backend: backend)
            .with(\.graphUpdateHost, graphUpdateHost)
        self.cancellables = []

        dynamicPropertyUpdater = DynamicPropertyUpdater(for: app)
    }

    func refreshSceneGraph() {
        // TODO: Do we have to update dynamic properties on state changes?
        //   We can probably get away with only doing it when the root
        //   environment changes.
        dynamicPropertyUpdater.update(app, with: environment, previousValue: nil)

        if let sceneGraphRoot {
            let body = self.observe(in: backend) { app.body }
            let result = sceneGraphRoot.updateNode(body, environment: environment)
            backend.setApplicationMenu(
                result.preferences.commands.resolve(),
                environment: environment
            )
            sceneGraphRoot.update(
                backend: backend,
                environment: environment
            )
        }
    }
    
    func viewModelDidChange<Backend: AppBackend>(backend: Backend) {
        enqueueRefreshSceneGraph(
            backend: backend,
            transaction: StateMutationContext.currentTransaction
                .overlaid(by: TransactionContext.current)
        )
    }

    func enqueueObservedChange<Backend: AppBackend>(
        backend: Backend,
        transaction: Transaction
    ) {
        enqueueRefreshSceneGraph(backend: backend, transaction: transaction)
    }

    private func enqueueRefreshSceneGraph<Backend: AppBackend>(
        backend: Backend,
        transaction: Transaction
    ) {
        graphUpdateHost.enqueue(
            backend: backend,
            transaction: transaction,
            key: "app-root"
        ) { [weak self] in
            self?.refreshSceneGraph()
        }
    }

    /// Runs the app using the app's selected backend.
    func run() {
        backend.runMainLoop { [self] in
            let baseEnvironment = EnvironmentValues(backend: backend)
                .with(\.graphUpdateHost, graphUpdateHost)
            environment = backend.computeRootEnvironment(
                defaultEnvironment: baseEnvironment
            ).with(\.graphUpdateHost, graphUpdateHost)

            dynamicPropertyUpdater.update(app, with: environment, previousValue: nil)

            let mirror = Mirror(reflecting: app)
            for property in mirror.children {
                if property.label == "state" && property.value is ObservableObject {
                    logger.warning(
                        """
                        the App.state protocol requirement has been removed in favour of \
                        SwiftUI-style @State annotations; decorate \(AppRoot.self).state \
                        with the @State property wrapper to restore previous behaviour
                        """
                    )
                }

                guard let value = property.value as? any ObservableProperty else {
                    continue
                }

                let cancellable = value.didChange.observe { [weak self] in
                    guard let self else {
                        return
                    }
                    let transaction = StateMutationContext.currentTransaction
                        .overlaid(by: TransactionContext.current)
                    self.enqueueRefreshSceneGraph(
                        backend: self.backend,
                        transaction: transaction
                    )
                }
                cancellables.append(cancellable)
            }

            let body = self.observe(in: backend) { app.body }
            let rootNode = AppRoot.Body.Node(
                from: body,
                backend: backend,
                environment: environment
            )

            backend.setRootEnvironmentChangeHandler {
                self.environment = self.backend.computeRootEnvironment(
                    defaultEnvironment: baseEnvironment
                ).with(\.graphUpdateHost, self.graphUpdateHost)
                self.enqueueRefreshSceneGraph(
                    backend: self.backend,
                    transaction: TransactionContext.current
                )
            }

            let result = rootNode.updateNode(nil, environment: environment)

            // Update application-wide menu
            if let backend = backend as? any BackendFeatures.ApplicationMenus {
                backend.setApplicationMenu(
                    result.preferences.commands.resolve(),
                    environment: environment
                )
            }

            rootNode.update(backend: backend, environment: environment)
            self.sceneGraphRoot = rootNode
        }
    }
}
