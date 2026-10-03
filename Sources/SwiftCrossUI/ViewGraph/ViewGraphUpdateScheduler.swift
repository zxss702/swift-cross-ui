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
/// Coverage is tracked via ``ViewGraphNode/updateGeneration``: `computeLayout`
/// stamps every node it visits with the flush's generation counter, so queued
/// descendants of an already-updated node are cheaply detected. Nodes whose
/// layout was elided (equal `.equatable()` values) don't stamp their children,
/// so a dirty descendant's queued update still runs.
@MainActor
enum ViewGraphUpdateScheduler {
    /// A node queued for a bottom-up update.
    private struct Entry {
        /// The node's approximate depth in the view graph (root = 1). Used to
        /// process ancestor updates before descendants: an ancestor's commit
        /// covers its whole subtree, so shallower entries running first let
        /// queued descendants be skipped via ``isCovered``.
        var depth: Int
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

    /// Queues a node for a bottom-up update, scheduling a flush on the main
    /// thread if one isn't already queued. Enqueueing is idempotent per node
    /// per flush.
    ///
    /// - Parameter dispatch: `backend.runInMainThread` — used to schedule the
    ///   flush without this type knowing the backend.
    static func enqueue(
        _ node: AnyObject & Sendable,
        depth: Int,
        isCovered: @escaping () -> Bool,
        run: @escaping () -> Void,
        dispatch: (@escaping @MainActor () -> Void) -> Void
    ) {
        let id = ObjectIdentifier(node)
        guard pendingIDs.insert(id).inserted else { return }
        pending.append(Entry(depth: depth, isCovered: isCovered, run: run))
        guard !isFlushScheduled else { return }
        isFlushScheduled = true
        dispatch {
            flush()
        }
    }

    private static func flush() {
        isFlushScheduled = false
        generation &+= 1
        // Ancestors first: a shallower node's commit stamps its whole subtree
        // with the current generation, letting deeper queued entries be
        // skipped instead of each recomputing its own subtree from scratch.
        let entries = pending.enumerated().sorted {
            ($0.element.depth, $0.offset) < ($1.element.depth, $1.offset)
        }.map(\.element)
        pending.removeAll()
        pendingIDs.removeAll()
        for entry in entries {
            if !entry.isCovered() {
                entry.run()
            }
        }
    }
}
