@MainActor
final class ViewUpdateScheduler {
    typealias ScheduledAction = @MainActor () -> Void

    private let schedule: (@escaping ScheduledAction) -> Void
    private let flush: (Transaction) -> Void

    private var pendingTransaction: Transaction?
    private var isScheduled = false
    private var isFlushing = false

    init(
        schedule: @escaping (@escaping ScheduledAction) -> Void,
        flush: @escaping (Transaction) -> Void
    ) {
        self.schedule = schedule
        self.flush = flush
    }

    func invalidate(transaction: Transaction) {
        pendingTransaction = transaction

        guard !isScheduled && !isFlushing else {
            return
        }

        scheduleFlush()
    }

    private func scheduleFlush() {
        isScheduled = true
        schedule { [weak self] in
            self?.flushPendingUpdate()
        }
    }

    private func flushPendingUpdate() {
        guard let transaction = pendingTransaction else {
            isScheduled = false
            return
        }

        pendingTransaction = nil
        isScheduled = false
        isFlushing = true
        flush(transaction)
        isFlushing = false

        if pendingTransaction != nil {
            scheduleFlush()
        }
    }
}
