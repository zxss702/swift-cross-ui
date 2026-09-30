import Foundation

/// Coalesces view graph updates triggered by state/observable changes.
///
/// When a single observable change is read by many views, each affected node's
/// ``ViewGraphNode`` would otherwise run its own `bottomUpUpdate` — every one
/// relayouts and commits its whole subtree, so overlapping subtrees get
/// recomputed and re-committed many times per state change. This scheduler
/// instead collects all nodes dirtied within a dispatcher tick and processes
/// them in a single flush: a node whose subtree was already committed during
/// an ancestor's update in the same flush is skipped entirely.
///
/// Coverage is tracked via ``ViewGraphNode/commitGeneration``: `commit()`
/// stamps every node it visits (commit recurses through the subtree) with the
/// flush's generation counter, so queued descendants of an already-updated
/// node are cheaply detected.
@MainActor
enum ViewGraphUpdateScheduler {
    /// A node queued for a bottom-up update.
    private struct Entry {
        /// Whether the node's subtree was already committed during the
        /// current flush (i.e. an ancestor processed earlier covered it).
        var isCovered: () -> Bool
        /// Performs the node's bottom-up update (recompute + commit).
        var run: () -> Void
    }

    /// The current flush generation. Incremented once per flush; nodes stamped
    /// with the current generation have already been committed this flush.
    static var generation: UInt64 = 0

    private static var pending: [Entry] = []
    private static var pendingIDs: Set<ObjectIdentifier> = []
    private static var isFlushScheduled = false

    /// Counters for diagnosing update storms (read via ``statistics()``).
    private(set) static var flushCount = 0
    private(set) static var updatesRun = 0
    private(set) static var updatesSkipped = 0

    /// Queues a node for a bottom-up update, scheduling a flush on the main
    /// thread if one isn't already queued. Enqueueing is idempotent per node
    /// per flush.
    ///
    /// - Parameter dispatch: `backend.runInMainThread` — used to schedule the
    ///   flush without this type knowing the backend.
    static func enqueue(
        _ node: AnyObject & Sendable,
        isCovered: @escaping () -> Bool,
        run: @escaping () -> Void,
        dispatch: (@escaping @MainActor () -> Void) -> Void
    ) {
        let id = ObjectIdentifier(node)
        guard pendingIDs.insert(id).inserted else { return }
        pending.append(Entry(isCovered: isCovered, run: run))
        guard !isFlushScheduled else { return }
        isFlushScheduled = true
        dispatch {
            flush()
        }
    }

    private static func flush() {
        isFlushScheduled = false
        generation &+= 1
        flushCount += 1
        let entries = pending
        pending.removeAll()
        pendingIDs.removeAll()
        for entry in entries {
            if entry.isCovered() {
                updatesSkipped += 1
            } else {
                updatesRun += 1
                entry.run()
            }
        }
    }

    /// `(flushes, updates run, updates skipped)`.
    static func statistics() -> (Int, Int, Int) {
        (flushCount, updatesRun, updatesSkipped)
    }
}
