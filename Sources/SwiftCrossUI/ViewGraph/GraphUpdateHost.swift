import Dispatch
import Foundation

/// Owns the transaction and render-frame lifecycle for a SwiftCrossUI graph.
///
/// This deliberately mirrors SwiftUI/OpenSwiftUI's graph-host boundary: state
/// and observation changes enqueue graph mutations, then the host flushes those
/// mutations in a transaction. Backends only provide a way to run work on the UI
/// thread; they do not decide whether the graph is dirty or how animation frames
/// advance.
@MainActor
final class GraphUpdateHost: @unchecked Sendable {
    private final class DelayedMutation: @unchecked Sendable {
        private let action: @MainActor () -> Void

        init(_ action: @escaping @MainActor () -> Void) {
            self.action = action
        }

        @MainActor
        func apply() {
            action()
        }
    }

    @MainActor
    private final class FrameClock {
        private var hasScheduledFrame = false

        func requestFrame<Backend: AppBackend>(
            backend: Backend,
            action: @escaping @MainActor @Sendable (DispatchTime) -> Void
        ) {
            guard !hasScheduledFrame else {
                return
            }
            hasScheduledFrame = true

            let delay = 1.0 / clampedFramesPerSecond(backend.preferredFramesPerSecond)
            DispatchQueue.global(qos: .userInteractive).asyncAfter(
                deadline: .now() + delay
            ) { [weak self] in
                backend.runInMainThread { [weak self] in
                    guard let self else {
                        return
                    }
                    self.hasScheduledFrame = false
                    action(DispatchTime.now())
                }
            }
        }

        private func clampedFramesPerSecond(_ value: Double) -> Double {
            guard value.isFinite else {
                return 60
            }
            return min(max(value, 1), 240)
        }
    }

    private struct PendingMutation {
        var transaction: Transaction
        var action: @MainActor () -> Void
    }

    private struct PendingRenderFrame {
        var transaction: Transaction
        var action: @MainActor () -> Void
    }

    private var pendingMutations: [AnyHashable: PendingMutation] = [:]
    private var pendingMutationKeys: [AnyHashable] = []
    private var hasScheduledTransactionFlush = false
    private var isFlushingTransactions = false
    private var lastTransactionFlushRequest: (@MainActor () -> Void)?
    private var deferredTransactionFlush: (@MainActor () -> Void)?

    private var pendingRenderFrames: [AnyHashable: PendingRenderFrame] = [:]
    private var pendingRenderKeys: [AnyHashable] = []
    private var hasScheduledRenderFlush = false
    private var lastRenderFlushRequest: (@MainActor () -> Void)?
    private var deferredRenderFlush: (@MainActor () -> Void)?
    private let frameClock = FrameClock()

    private var hasPendingTransactions: Bool {
        !pendingMutationKeys.isEmpty
    }

    func enqueue<Backend: AppBackend>(
        backend: Backend,
        transaction: Transaction,
        key: AnyHashable,
        action: @escaping @MainActor () -> Void
    ) {
        if var pending = pendingMutations[key] {
            pending.transaction = pending.transaction.mergedQueuedMutation(by: transaction)
            pending.action = action
            pendingMutations[key] = pending
        } else {
            pendingMutationKeys.append(key)
            pendingMutations[key] = PendingMutation(
                transaction: transaction,
                action: action
            )
        }

        requestTransactionFlush(backend: backend)
    }

    func enqueueRenderFrame<Backend: AppBackend>(
        backend: Backend,
        transaction: Transaction,
        key: AnyHashable,
        action: @escaping @MainActor () -> Void
    ) {
        if var pending = pendingRenderFrames[key] {
            pending.transaction = transaction
            pending.action = action
            pendingRenderFrames[key] = pending
        } else {
            pendingRenderKeys.append(key)
            pendingRenderFrames[key] = PendingRenderFrame(
                transaction: transaction,
                action: action
            )
        }

        requestRenderFlush(backend: backend)
    }

    func enqueueAfter<Backend: AppBackend>(
        backend: Backend,
        delay: TimeInterval,
        transaction: Transaction,
        key: AnyHashable,
        action: @escaping @MainActor () -> Void
    ) {
        guard delay > 0 else {
            enqueue(
                backend: backend,
                transaction: transaction,
                key: key,
                action: action
            )
            return
        }

        let mutation = DelayedMutation { [weak self, backend] in
            guard let self else {
                return
            }
            self.enqueue(
                backend: backend,
                transaction: transaction,
                key: key,
                action: action
            )
        }

        DispatchQueue.global(qos: .userInteractive).asyncAfter(
            deadline: .now() + delay
        ) {
            backend.runInMainThread {
                mutation.apply()
            }
        }
    }

    private func requestTransactionFlush<Backend: AppBackend>(backend: Backend) {
        let request: @MainActor () -> Void = { [weak self, backend] in
            guard let self else {
                return
            }
            self.requestTransactionFlush(backend: backend)
        }
        lastTransactionFlushRequest = request

        if isFlushingTransactions {
            deferredTransactionFlush = request
            return
        }

        guard !hasScheduledTransactionFlush else {
            return
        }
        hasScheduledTransactionFlush = true

        backend.runInMainThread { [weak self] in
            guard let self else {
                return
            }
            self.hasScheduledTransactionFlush = false
            self.flushTransactions()
        }
    }

    private func requestRenderFlush<Backend: AppBackend>(backend: Backend) {
        let schedule: @MainActor () -> Void = { [weak self, backend] in
            guard let self else {
                return
            }
            self.scheduleRenderFlush(backend: backend)
        }
        lastRenderFlushRequest = schedule

        if isFlushingTransactions || hasPendingTransactions {
            deferredRenderFlush = schedule
            return
        }

        schedule()
    }

    private func scheduleRenderFlush<Backend: AppBackend>(backend: Backend) {
        guard !hasScheduledRenderFlush else {
            return
        }
        hasScheduledRenderFlush = true

        frameClock.requestFrame(backend: backend) { [weak self] time in
            guard let self else {
                return
            }
            self.hasScheduledRenderFlush = false
            self.flushRenderFrames(at: time)
        }
    }

    private func flushTransactions() {
        guard hasPendingTransactions, !isFlushingTransactions else {
            return
        }

        isFlushingTransactions = true
        var passCount = 0

        while hasPendingTransactions && passCount < 8 {
            passCount += 1
            let keys = pendingMutationKeys
            let mutations = pendingMutations
            pendingMutationKeys = []
            pendingMutations = [:]

            GraphUpdateContext.withMutationTracking {
                for key in keys {
                    guard let mutation = mutations[key] else {
                        continue
                    }

                    if GraphUpdateContext.hasUpdated(key: key) {
                        continue
                    }

                    GraphUpdateContext.markUpdated(key: key)
                    runTransaction(mutation.transaction, body: mutation.action)
                }
            }
        }

        isFlushingTransactions = false

        if hasPendingTransactions,
            let request = deferredTransactionFlush ?? lastTransactionFlushRequest
        {
            deferredTransactionFlush = nil
            request()
            return
        }

        deferredTransactionFlush = nil

        if !pendingRenderKeys.isEmpty,
            let request = deferredRenderFlush ?? lastRenderFlushRequest
        {
            deferredRenderFlush = nil
            request()
        }
    }

    private func flushRenderFrames(at time: DispatchTime) {
        if hasPendingTransactions {
            flushTransactions()
            guard !hasPendingTransactions else {
                return
            }
        }

        guard !pendingRenderKeys.isEmpty else {
            return
        }

        let keys = pendingRenderKeys
        let frames = pendingRenderFrames
        pendingRenderKeys = []
        pendingRenderFrames = [:]

        for (offset, key) in keys.enumerated() {
            guard let frame = frames[key] else {
                continue
            }

            runRenderTransaction(frame.transaction) {
                RenderFrameContext.withRendering(at: time) {
                    frame.action()
                }
            }

            if hasPendingTransactions {
                for remainingKey in keys.dropFirst(offset + 1) {
                    guard pendingRenderFrames[remainingKey] == nil,
                        let frame = frames[remainingKey]
                    else {
                        continue
                    }
                    pendingRenderKeys.append(remainingKey)
                    pendingRenderFrames[remainingKey] = frame
                }

                if let request = lastTransactionFlushRequest {
                    request()
                }
                deferredRenderFlush = lastRenderFlushRequest
                return
            }
        }
    }

    private func runTransaction(
        _ transaction: Transaction,
        body: @MainActor () -> Void
    ) {
        withTransaction(transaction) {
            StateMutationContext.withTransaction(transaction) {
                GraphUpdateContext.withUpdating {
                    body()
                }
            }
        }
    }

    private func runRenderTransaction(
        _ transaction: Transaction,
        body: @MainActor () -> Void
    ) {
        withTransaction(transaction) {
            StateMutationContext.withTransaction(transaction) {
                body()
            }
        }
    }
}
