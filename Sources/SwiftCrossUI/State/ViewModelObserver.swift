import Foundation
import Mutex
import PerceptionCore
#if canImport(Observation)
    import Observation
#endif

final class ObservationTrackingState: @unchecked Sendable {
    private let generation = Mutex(0)
    private let pendingUpdate = Mutex(false)

    func beginTracking() -> Int {
        generation.withLock { generation in
            generation &+= 1
            return generation
        }
    }

    func invalidate(_ observedGeneration: Int) -> Bool {
        generation.withLock { generation in
            guard generation == observedGeneration else {
                pendingUpdate.withLock { $0 = true }
                return false
            }
            generation &+= 1
            return true
        }
    }

    func hasPendingUpdate() -> Bool {
        pendingUpdate.withLock { $0 }
    }

    func clearPendingUpdate() {
        pendingUpdate.withLock { $0 = false }
    }
}

/// This protocol can be adopted by classes responsible for handling part of
/// the view hierarchy. It makes it easy to automatically update the view when
/// observable view models change.
///
/// The most important rule: Every computation of a view's `body` or custom
/// observation dependencies MUST be performed inside a call to `observe()`.
/// For example:
///
///     let body = self.observe(in: backend) { view.body }
///     // Use `body`
///
/// Then, `viewModelDidChange()` will automatically be called the next time a
/// view model conforming to `Observable` or `Perceptible` and used inside the
/// tracked computation changes.
///
/// - Important: `self` MUST only be used to observe a single view because
/// `viewModelDidChange()` will only be called for the most recent call to `observe()` in order to
/// prevent duplicate view updates.
@MainActor
protocol ViewModelObserver: AnyObject, Sendable {
    /// Used by the `ViewModelObserver` protocol to prevent duplicate view updates.
    var observationTrackingState: ObservationTrackingState { get }

    /// This method is called at most once after a call to `observe()` if an object conforming to
    /// `Observable` or `Perceptible` used in the `computation` closure of the last call to
    /// `observe()` has changed.
    ///
    /// When this method has been called, it will not be called again until the next call to `observe()`.
    ///
    /// - Parameter backend: The backend passed to the last call to `observe()`.
    func viewModelDidChange<Backend: BaseAppBackend>(backend: Backend)

    /// Enqueues an observed model change into the owning graph's transaction
    /// queue. Implementations that own a graph should override this instead of
    /// running a layout update directly on the backend main thread.
    func enqueueObservedChange<Backend: BaseAppBackend>(
        backend: Backend,
        transaction: Transaction
    )
}

extension ViewModelObserver {
    func enqueueObservedChange<Backend: BaseAppBackend>(
        backend: Backend,
        transaction: Transaction
    ) {
        withTransaction(transaction) {
            StateMutationContext.withTransaction(transaction) {
                self.viewModelDidChange(backend: backend)
            }
        }
    }

    /// Performs a computation and tracks accesses to properties of objects conforming to
    /// `Observable` or `Perceptible` inside the computation. The next time one of those
    /// properties changes, `viewModelDidChange()` will be called.
    ///
    /// If this method is called multiple times, only the last call will be tracked. The reason is that view
    /// updates may be caused by other triggers. If all of those would be tracked, view updates would
    /// multiply.
    ///
    /// - Parameters:
    ///   - backend: The backend used to schedule calls to `viewModelDidChange()` on the
    ///   main thread. A strong reference will be held until that call has been made.
    ///   - computation: The computation to be tracked. Usually, accesses to a
    ///   view's `body` property will be encapsulated in this closure, but
    ///   custom view wrappers can track any other dependency reads they need.
    /// - Returns: The result of the computation.
    @discardableResult
    func observe<Backend: BaseAppBackend, Result>(
        in backend: Backend,
        _ computation: () -> Result
    ) -> Result {
        if RenderFrameContext.isRendering {
            return computation()
        }

        let trackingState = observationTrackingState
        let trackingGeneration = trackingState.beginTracking()

        func trackWithPerception() -> Result {
            withPerceptionTracking {
                GraphUpdateContext.withUpdating {
                    computation()
                }
            } onChange: {
                let transaction = StateMutationContext.currentTransaction
                    .overlaid(by: TransactionContext.current)
                guard trackingState.invalidate(trackingGeneration) else {
                    return
                }
                backend.runInMainThread { [weak self] in
                    guard let self else { return }
                    self.enqueueObservedChange(
                        backend: backend,
                        transaction: transaction
                    )
                }
            }
        }

        let result: Result

        #if canImport(Observation)
        if #available(macOS 14.0, iOS 17.0, tvOS 17.0, watchOS 10.0, visionOS 1.0, *) {
            result = withObservationTracking(
                {
                    GraphUpdateContext.withUpdating {
                        computation()
                    }
                },
                onChange: {
                    let transaction = StateMutationContext.currentTransaction
                        .overlaid(by: TransactionContext.current)
                    guard trackingState.invalidate(trackingGeneration) else {
                        return
                    }
                    backend.runInMainThread { [weak self] in
                        guard let self else { return }
                        self.enqueueObservedChange(
                            backend: backend,
                            transaction: transaction
                        )
                    }
                }
            )
        } else {
            result = trackWithPerception()
        }
        #else
        result = trackWithPerception()
        #endif

        if trackingState.hasPendingUpdate() {
            trackingState.clearPendingUpdate()
            self.enqueueObservedChange(
                backend: backend,
                transaction: StateMutationContext.currentTransaction
                    .overlaid(by: TransactionContext.current)
            )
        }

        return result
    }
}
