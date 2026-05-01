import Dispatch
import Foundation

/// A type that produces valueless observations.
public class Publisher {
    /// The id for the next observation (ids are used to cancel observations).
    private var nextObservationId = 0
    /// All current observations keyed by their id (ids are used to cancel observations).
    private var observations: [Int: () -> Void] = [:]
    /// Human-readable tag for debugging purposes.
    private var tag: String?

    /// We guard this against data races, with `serialUpdateHandlingQueue`, and
    /// with our lives.
    private class UpdateStatistics: @unchecked Sendable {
        /// The time at which the last update merging event occurred in
        /// `observeOnMainThreadAvoidingStarvation`.
        var lastUpdateMergeTime: TimeInterval = 0
        /// The amount of time taken per state update, exponentially averaged over time.
        var exponentiallySmoothedUpdateLength: Double = 0
    }

    private let updateStatistics = UpdateStatistics()

    private let serialUpdateHandlingQueue = DispatchQueue(
        label: "serial update handling"
    )
    private let semaphore = DispatchSemaphore(value: 1)

    /// Creates a new independent publisher.
    public init() {}

    /// Publishes a change to all observers serially on the current thread.
    public func send() {
        for observation in self.observations.values {
            observation()
        }
    }

    /// Registers a handler to observe future events.
    public func observe(with closure: @escaping () -> Void) -> Cancellable {
        let id = nextObservationId
        observations[id] = closure
        nextObservationId += 1

        return Cancellable { [weak self] in
            guard let self else { return }
            self.observations[id] = nil
        }
        .tag(with: tag)
    }

    /// Links the publisher to an upstream, meaning that observations from the upstream
    /// effectively get forwarded to all observers of this publisher as well.
    public func link(toUpstream publisher: Publisher) -> Cancellable {
        let cancellable = publisher.observe(with: {
            self.send()
        })
        cancellable.tag(with: "\(tag ?? "no tag") <-> \(cancellable.tag ?? "no tag")")
        return cancellable
    }

    @discardableResult
    func tag(with tag: @autoclosure () -> String?) -> Self {
        #if DEBUG
            self.tag = tag()
        #endif
        return self
    }

    /// A specialized version of ``observe(with:)`` designed to mitigate main thread
    /// starvation issues observed on weaker systems when using the Gtk3Backend.
    ///
    /// If observations are produced faster than the update handler (`closure`) can
    /// run, then the main thread quickly saturates and there's not enough time
    /// between view state updates for the backend to re-render the affected UI
    /// elements.
    ///
    /// This method ensures that only one update can queue up at a time. When an
    /// observation arrives while an update is already queued, the observation's
    /// resulting update gets 'merged' (which just means dropped, but unlike a
    /// dropped frame, a dropped update has no detrimental effects).
    ///
    /// When updates are getting merged often, this generally means that the
    /// update handler is still running constantly (since there's always going to
    /// be a new update waiting before the the running update completes). In this
    /// situation we introduce a sleep after handling each update to give the backend
    /// time to catch up. Heuristically I've found that a delay of 1.5x the length of
    /// the update is required on my old Linux laptop using ``Gtk3Backend``, so I'm
    /// going with that for now. Importantly, this delay is only used whenever updates
    /// start running back-to-back with no gap so it shouldn't affect fast systems
    /// like my Mac under any usual circumstances.
    ///
    /// If the provided backend has the notion of a main thread, then the update
    /// handler will end up on that thread, but regardless of backend it's
    /// guaranteed that updates will always run serially.
    func observeAsUIUpdater<Backend: AppBackend>(
        backend: Backend,
        action: @escaping @MainActor @Sendable () -> Void
    ) -> Cancellable {
        let semaphore = self.semaphore
        let serialUpdateHandlingQueue = self.serialUpdateHandlingQueue
        let updateStatistics = self.updateStatistics
        return observe {
            let transaction = StateMutationContext.currentTransaction
                .overlaid(by: TransactionContext.current)
            // Only allow one update to wait at a time.
            guard semaphore.wait(timeout: .now()) == .success else {
                // It's a bit of a hack but we just reuse the serial update handling queue
                // for synchronisation since updating this variable isn't super time sensitive
                // as long as it happens within the next update or two.
                let mergeTime = ProcessInfo.processInfo.systemUptime
                serialUpdateHandlingQueue.async {
                    updateStatistics.lastUpdateMergeTime = mergeTime
                }
                return
            }

            let runUpdate: @Sendable () -> Void = {
                backend.runInMainThread {
                    // Now that we're about to start, let another update queue up. If we
                    // instead waited until we're finished the update, we'd introduce the
                    // possibility of dropping updates that would've affected views that
                    // we've already processed, leading to stale view contents.
                    semaphore.signal()

                    // Run the closure and while we're at it measure how long it takes
                    // so that we can use it when throttling if updates start backing up.
                    let start = ProcessInfo.processInfo.systemUptime
                    withTransaction(transaction) {
                        StateMutationContext.withTransaction(transaction) {
                            action()
                        }
                    }
                    let elapsed = ProcessInfo.processInfo.systemUptime - start

                    // I chose exponential smoothing because it's simple to compute, doesn't
                    // require storing a window of previous values, and quickly converges to
                    // a sensible value when the average moves, while still somewhat ignoring
                    // outliers.
                    updateStatistics.exponentiallySmoothedUpdateLength =
                        elapsed / 2 + updateStatistics.exponentiallySmoothedUpdateLength / 2
                }
            }

            // Run the first update without an extra dispatch hop. The private
            // queue is only used when updates are already merging and we need to
            // throttle to avoid starving slower backends.
            if ProcessInfo.processInfo.systemUptime - updateStatistics.lastUpdateMergeTime < 1 {
                serialUpdateHandlingQueue.async {
                    runUpdate()
                    if ProcessInfo.processInfo.systemUptime
                        - updateStatistics.lastUpdateMergeTime < 1
                    {
                        // The factor of 1.5 was determined empirically. This
                        // algorithm is open for improvements since it's purely
                        // here to reduce the risk of UI freezes.
                        let throttlingDelay =
                            updateStatistics.exponentiallySmoothedUpdateLength * 1.5
                        Thread.sleep(forTimeInterval: throttlingDelay)
                    }
                }
            } else {
                runUpdate()
            }
        }
    }
}
