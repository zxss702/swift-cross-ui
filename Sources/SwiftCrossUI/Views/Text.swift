import Foundation

/// A view the displays text.
///
/// ``Text`` truncates its content to fit within its proposed size. To wrap
/// without truncation, put the ``Text`` (or its enclosing view hierarchy) into
/// an ideal height context such as a ``ScrollView``. Alternatively, use
/// ``View/fixedSize(horizontal:vertical:)`` with `horizontal` set to false and
/// `vertical` set to true, but be aware that this may lead to unintuitive
/// minimum sizing behaviour when used within a window. Often when developers
/// use ``View/fixedSize()`` on text, what they really need is a ``ScrollView``.
///
/// To avoid wrapping and truncation entirely, use ``View/fixedSize()``.
///
/// ## Technical notes
///
/// The reason that ``Text`` truncates its content to fit its proposed size is
/// that SwiftCrossUI's layout system behaves rather unintuitively with views
/// that trade off width for height. The layout system used to support this
/// behaviour well, but when overhauling the layout system with performance in
/// mind, we discovered that it's not possible to handle minimum view sizing in
/// the intuitive way that we were, without a large performance cost or layout
/// system complexity cost.
///
/// With the current system, windows determine the minimum size of their content
/// by proposing a size of 0x0. A text view that doesn't truncate its content
/// would take on a width of 0 and then lay out each character on a new line (as
/// that's what most UI frameworks do when text is given a small width). This
/// leads to the window thinking that its minimum height is
/// `characterCount * lineHeight`, even though when given a width larger than
/// zero, the text view would be shorter than this 'minimum height'. The
/// underlying cause is the assumption that 'minimum size' is a sensible notion
/// for every view. A text view without truncation doesn't have a
/// 'minimum size'; are we minimizing width? height? width + height? area?
///
/// SwiftCrossUI's old layout system separated the concept of minimum size into
/// 'minimum width for current height', and 'minimum height for current width'.
/// This led to much more intuitive window sizing behaviour. If you had
/// non-truncating text inside a window, and resized the width of the window
/// such that the height of the text became taller than the window, then the
/// window would become taller, and if you resized the height of the window then
/// you'd reach the window's minimum height before the text could overflow the
/// window horizontally. Unfortunately this required a lot of book-keeping, and
/// was deemed to be unfeasible to do without significantly hurting performance
/// due to all the layout assumptions that we'd have to drop from our stack
/// layout algorithm.
///
/// The new layout system behaviour is in line with SwiftUI's layout behaviour.
public struct Text: Sendable {
    /// The string to be shown in the text view.
    var string: String

    /// Creates a new text view that displays a string.
    ///
    /// - Parameter string: The string to display.
    public init(_ string: String) {
        self.string = string
    }
}

extension Text: View {
    public var body: EmptyView {
        return EmptyView()
    }
}

extension Text: LayoutInputKeyProvider {
    var layoutInputKey: AnyHashable? {
        LayoutInputKeys.make(Self.self, values: [AnyHashable(string)])
    }
}

extension Text: TypeSafeView {
    typealias Children = TextChildren

    func children<Backend: BaseAppBackend>(
        backend: Backend,
        snapshots: [ViewGraphSnapshotter.NodeSnapshot]?,
        environment: EnvironmentValues
    ) -> TextChildren {
        TextChildren(backend: backend)
    }

    func asWidget<Backend: BaseAppBackend>(
        _ children: TextChildren,
        backend: Backend
    ) -> Backend.Widget {
        let container = backend.createContainer()
        children.rebuild(container: container, backend: backend)
        return container
    }

    func computeLayout<Backend: BaseAppBackend>(
        _ widget: Backend.Widget,
        children: TextChildren,
        proposedSize: ProposedViewSize,
        environment: EnvironmentValues,
        backend: Backend
    ) -> ViewLayoutResult {
        let textWidget: Backend.Widget = children.textWidget.into()
        backend.updateTextView(textWidget, content: string, environment: environment)

        var size = measuredSize(
            of: string,
            widget: textWidget,
            proposedSize: proposedSize,
            environment: environment,
            backend: backend
        )

        if proposedSize.width == 0 && size.x == 1 {
            size.x = 0
        }

        if !environment.allowLayoutCaching {
            children.update(
                text: string,
                size: size,
                proposedSize: proposedSize,
                environment: environment,
                backend: backend
            )
        }

        return ViewLayoutResult.leafView(size: ViewSize(size))
    }

    func commit<Backend: BaseAppBackend>(
        _ widget: Backend.Widget,
        children: TextChildren,
        layout: ViewLayoutResult,
        environment: EnvironmentValues,
        backend: Backend
    ) {
        children.commit(
            container: widget,
            layout: layout,
            environment: environment,
            backend: backend
        )
    }

    @MainActor private func measuredSize<Backend: BaseAppBackend>(
        of text: String,
        widget: Backend.Widget,
        proposedSize: ProposedViewSize,
        environment: EnvironmentValues,
        backend: Backend
    ) -> SIMD2<Int> {
        backend.size(
            of: text,
            whenDisplayedIn: widget,
            proposedWidth: Self.proposedTextWidth(proposedSize),
            proposedHeight: Self.proposedTextHeight(proposedSize),
            environment: environment
        )
    }

    fileprivate static func proposedTextWidth(_ proposedSize: ProposedViewSize) -> Int? {
        proposedSize.width.flatMap {
            $0 == .infinity ? nil : $0
        }.map(LayoutSystem.roundSize).map { max(1, $0) }
    }

    fileprivate static func proposedTextHeight(_ proposedSize: ProposedViewSize) -> Int? {
        proposedSize.height.flatMap {
            $0 == .infinity ? nil : $0
        }.map(LayoutSystem.roundSize).map { max(1, $0) }
    }
}

@MainActor
final class TextChildren: ViewGraphNodeChildren, @unchecked Sendable {
    var textWidget: AnyWidget
    fileprivate var fragmentNodes: [TextFragmentNode] = []
    var currentText: String?
    var numericValue: Double?
    var pendingNumericValue: Double?
    var transitionDuration: TimeInterval = 0
    var nextFragmentID = 0
    var nextRunID = 0
    var needsRebuild = true

    var widgets: [AnyWidget] {
        [textWidget] + fragmentNodes.map { $0.node.getWidget() }
    }

    var erasedNodes: [ErasedViewGraphNode] {
        fragmentNodes.map(\.node)
    }

    init<Backend: BaseAppBackend>(backend: Backend) {
        textWidget = AnyWidget(backend.createTextView())
    }

    func rebuild<Backend: BaseAppBackend>(container: Backend.Widget, backend: Backend) {
        backend.removeAllChildren(of: container)
        for (index, child) in widgets.enumerated() {
            backend.insert(child.into(), into: container, at: index)
        }
        needsRebuild = false
    }

    func update<Backend: BaseAppBackend>(
        text: String,
        size: SIMD2<Int>,
        proposedSize: ProposedViewSize,
        environment: EnvironmentValues,
        backend: Backend
    ) {
        let previousNumericValue = pendingNumericValue ?? numericValue
        pendingNumericValue = environment.contentTransition.numericValue

        guard let previousText = currentText else {
            currentText = text
            clearFragments()
            return
        }

        guard previousText != text else {
            computeFragments(environment: environment)
            return
        }

        let transition = environment.contentTransition
        let shouldAnimate = !transition.isIdentity
            && !environment.transaction.disablesAnimations
            && !environment.transaction.disablesContentTransitions
            && environment.transaction.animation != nil

        currentText = text

        guard shouldAnimate else {
            clearFragments()
            return
        }

        let textWidget: Backend.Widget = textWidget.into()
        let runID = nextRunID
        nextRunID += 1
        let fragments = makeFragments(
            previousText: previousText,
            currentText: text,
            size: size,
            proposedSize: proposedSize,
            transition: transition,
            previousNumericValue: previousNumericValue,
            runID: runID,
            textWidget: textWidget,
            environment: environment,
            backend: backend
        )

        guard !fragments.isEmpty else {
            clearFragments()
            return
        }

        fragmentNodes = mergedFragments(
            newFragments: fragments,
            environment: environment
        )
        transitionDuration = environment.transaction.animation?.estimatedDuration ?? 0.35
        needsRebuild = true
        computeFragments(environment: environment)
    }

    func commit<Backend: BaseAppBackend>(
        container: Backend.Widget,
        layout: ViewLayoutResult,
        environment: EnvironmentValues,
        backend: Backend
    ) {
        if needsRebuild {
            rebuild(container: container, backend: backend)
        }

        let textWidget: Backend.Widget = textWidget.into()
        backend.setSize(of: container, to: layout.size.vector)
        backend.setPosition(ofChildAt: 0, in: container, to: .zero)
        backend.setSize(of: textWidget, to: layout.size.vector)
        backend.setOpacity(of: textWidget, to: fragmentNodes.isEmpty ? 1 : 0)
        backend.setBlur(of: textWidget, radius: 0)
        backend.setTransform(of: textWidget, to: .identity)

        for (offset, fragment) in fragmentNodes.enumerated() {
            _ = fragment.node.commit()
            backend.setPosition(
                ofChildAt: offset + 1,
                in: container,
                to: fragment.position
            )
        }

        numericValue = pendingNumericValue
        schedulePhaseUpdate(environment: environment, backend: backend)
        scheduleCleanup(environment: environment, backend: backend)
    }

    private func clearFragments() {
        guard !fragmentNodes.isEmpty else {
            return
        }
        fragmentNodes = []
        needsRebuild = true
    }

    private func computeFragments(environment: EnvironmentValues) {
        for fragment in fragmentNodes {
            _ = fragment.node.computeLayoutWithNewView(
                fragment.advanced ? fragment.targetView : fragment.initialView,
                ProposedViewSize(fragment.size),
                environment.with(\.contentTransition, .identity)
            )
        }
    }

    private func makeFragments<Backend: BaseAppBackend>(
        previousText: String,
        currentText: String,
        size: SIMD2<Int>,
        proposedSize: ProposedViewSize,
        transition: ContentTransition,
        previousNumericValue: Double?,
        runID: Int,
        textWidget: Backend.Widget,
        environment: EnvironmentValues,
        backend: Backend
    ) -> [TextFragmentNode] {
        if transition.usesCharacterFragments,
            let previousSnapshot = TextLayoutSnapshot(
                text: previousText,
                widget: textWidget,
                proposedSize: proposedSize,
                environment: environment,
                backend: backend
            ),
            let currentSnapshot = TextLayoutSnapshot(
                text: currentText,
                widget: textWidget,
                proposedSize: proposedSize,
                environment: environment,
                backend: backend
            )
        {
            return makeCharacterFragments(
                previous: previousSnapshot,
                current: currentSnapshot,
                transition: transition,
                previousNumericValue: previousNumericValue,
                runID: runID,
                environment: environment,
                backend: backend
            )
        }

        return makeWholeTextFragments(
            previousText: previousText,
            currentText: currentText,
            size: size,
            runID: runID,
            environment: environment,
            backend: backend
        )
    }

    private func makeWholeTextFragments<Backend: BaseAppBackend>(
        previousText: String,
        currentText: String,
        size: SIMD2<Int>,
        runID: Int,
        environment: EnvironmentValues,
        backend: Backend
    ) -> [TextFragmentNode] {
        let fragment = TextLayoutFragment(
            characterIndex: 0,
            origin: .zero,
            size: SIMD2(max(size.x, 1), max(size.y, 1))
        )
        return [
            makeFragmentNode(
                text: previousText,
                fragment: fragment,
                transition: .opacity,
                initialPhase: .identity,
                targetPhase: .didDisappear,
                role: .outgoing,
                runID: runID,
                characterIndex: nil,
                order: 0,
                changedCount: 1,
                environment: environment,
                backend: backend
            ),
            makeFragmentNode(
                text: currentText,
                fragment: fragment,
                transition: .opacity,
                initialPhase: .willAppear,
                targetPhase: .identity,
                role: .incoming,
                runID: runID,
                characterIndex: nil,
                order: 0,
                changedCount: 1,
                environment: environment,
                backend: backend
            ),
        ]
    }

    private func makeCharacterFragments<Backend: BaseAppBackend>(
        previous: TextLayoutSnapshot,
        current: TextLayoutSnapshot,
        transition: ContentTransition,
        previousNumericValue: Double?,
        runID: Int,
        environment: EnvironmentValues,
        backend: Backend
    ) -> [TextFragmentNode] {
        let previousCharacters = previous.characters
        let currentCharacters = current.characters
        var prefix = 0
        while prefix < previousCharacters.count,
            prefix < currentCharacters.count,
            previousCharacters[prefix] == currentCharacters[prefix]
        {
            prefix += 1
        }

        var suffix = 0
        while suffix + prefix < previousCharacters.count,
            suffix + prefix < currentCharacters.count,
            previousCharacters[previousCharacters.count - 1 - suffix]
                == currentCharacters[currentCharacters.count - 1 - suffix]
        {
            suffix += 1
        }

        let oldChanged = max(previousCharacters.count - prefix - suffix, 0)
        let newChanged = max(currentCharacters.count - prefix - suffix, 0)
        let changedCount = max(max(oldChanged, newChanged), 1)
        let transition = transition.transition(previousValue: previousNumericValue)
        var nodes: [TextFragmentNode] = []

        for index in 0..<prefix {
            if let node = stableNode(
                index: index,
                snapshot: current,
                runID: runID,
                environment: environment,
                backend: backend
            ) {
                nodes.append(node)
            }
        }

        for offset in 0..<oldChanged {
            let index = prefix + offset
            guard let fragment = previous.fragment(at: index) else {
                continue
            }
            nodes.append(
                makeFragmentNode(
                    text: String(previousCharacters[index]),
                    fragment: fragment,
                    transition: transition,
                    initialPhase: .identity,
                    targetPhase: .didDisappear,
                    role: .outgoing,
                    runID: runID,
                    characterIndex: index,
                    order: offset,
                    changedCount: changedCount,
                    environment: environment,
                    backend: backend
                )
            )
        }

        for offset in 0..<newChanged {
            let index = prefix + offset
            guard let fragment = current.fragment(at: index) else {
                continue
            }
            nodes.append(
                makeFragmentNode(
                    text: String(currentCharacters[index]),
                    fragment: fragment,
                    transition: transition,
                    initialPhase: .willAppear,
                    targetPhase: .identity,
                    role: .incoming,
                    runID: runID,
                    characterIndex: index,
                    order: offset,
                    changedCount: changedCount,
                    environment: environment,
                    backend: backend
                )
            )
        }

        if suffix > 0 {
            for index in (currentCharacters.count - suffix)..<currentCharacters.count {
                if let node = stableNode(
                    index: index,
                    snapshot: current,
                    runID: runID,
                    environment: environment,
                    backend: backend
                ) {
                    nodes.append(node)
                }
            }
        }

        return nodes
    }

    private func stableNode<Backend: BaseAppBackend>(
        index: Int,
        snapshot: TextLayoutSnapshot,
        runID: Int,
        environment: EnvironmentValues,
        backend: Backend
    ) -> TextFragmentNode? {
        guard let fragment = snapshot.fragment(at: index) else {
            return nil
        }
        return makeFragmentNode(
            text: String(snapshot.characters[index]),
            fragment: fragment,
            transition: .identity,
            initialPhase: .identity,
            targetPhase: .identity,
            role: .stable,
            runID: runID,
            characterIndex: index,
            order: 0,
            changedCount: 1,
            environment: environment,
            backend: backend
        )
    }

    private func makeFragmentNode<Backend: BaseAppBackend>(
        text: String,
        fragment: TextLayoutFragment,
        transition: AnyTransition,
        initialPhase: TransitionPhase,
        targetPhase: TransitionPhase,
        role: TextFragmentRole,
        runID: Int,
        characterIndex: Int?,
        order: Int,
        changedCount: Int,
        environment: EnvironmentValues,
        backend: Backend
    ) -> TextFragmentNode {
        let stagger = staggeredTransition(
            transition,
            order: order,
            changedCount: changedCount,
            transaction: environment.transaction
        )
        let view = AnyView(StaticTextFragment(text))
        let initialView = stagger.transition.applyTransition(view, initialPhase)
        let targetView = stagger.transition.applyTransition(view, targetPhase)
        let id = nextFragmentID
        nextFragmentID += 1
        return TextFragmentNode(
            id: id,
            runID: runID,
            role: role,
            characterIndex: characterIndex,
            text: text,
            node: ErasedViewGraphNode(
                for: initialView,
                backend: backend,
                environment: environment.with(\.contentTransition, .identity)
            ),
            initialView: initialView,
            targetView: targetView,
            position: fragment.origin,
            size: SIMD2(max(fragment.size.x, 1), max(fragment.size.y, 1)),
            delay: stagger.delay,
            advanced: initialPhase == targetPhase
        )
    }

    private func mergedFragments(
        newFragments: [TextFragmentNode],
        environment: EnvironmentValues
    ) -> [TextFragmentNode] {
        let currentKeys = Set(
            newFragments
                .filter { $0.role != .outgoing }
                .compactMap(\.key)
        )
        var carried: [TextFragmentNode] = []

        for fragment in fragmentNodes {
            switch fragment.role {
                case .stable:
                    continue
                case .outgoing:
                    if fragment.runID == nextRunID - 2 {
                        carried.append(fragment)
                    }
                case .incoming:
                    if let key = fragment.key, currentKeys.contains(key) {
                        carried.append(fragment)
                    }
            }
        }

        let carriedKeys = Set(carried.compactMap(\.key))
        let appended = newFragments.filter { fragment in
            if fragment.role == .outgoing {
                return true
            }
            guard let key = fragment.key else {
                return true
            }
            return !carriedKeys.contains(key)
        }

        return (carried + appended).sorted {
            if $0.role.sortOrder != $1.role.sortOrder {
                return $0.role.sortOrder < $1.role.sortOrder
            }
            return $0.id < $1.id
        }
    }

    private func staggeredTransition(
        _ transition: AnyTransition,
        order: Int,
        changedCount: Int,
        transaction: Transaction
    ) -> (transition: AnyTransition, delay: TimeInterval) {
        guard let animation = transaction.animation, changedCount > 1 else {
            return (transition, 0)
        }
        let duration = max(animation.estimatedDuration, 0.001)
        let maxDelay = min(duration * 0.35, 0.05 * Double(changedCount - 1))
        let delay = maxDelay * Double(order) / Double(changedCount - 1)
        let segmentDuration = max(duration - maxDelay, 0.001)
        return (transition.animation(
            animation
                .speed(duration / segmentDuration)
        ), delay)
    }

    private func schedulePhaseUpdate<Backend: BaseAppBackend>(
        environment: EnvironmentValues,
        backend: Backend
    ) {
        for index in fragmentNodes.indices
            where !fragmentNodes[index].advanced && !fragmentNodes[index].phaseUpdateScheduled
        {
            fragmentNodes[index].phaseUpdateScheduled = true
            let id = fragmentNodes[index].id
            let delay = max(fragmentNodes[index].delay, 0)
            let update = {
                guard let index = self.fragmentNodes.firstIndex(where: { $0.id == id }) else {
                    return
                }
                self.fragmentNodes[index].advanced = true
                environment.onResize(.zero)
            }
            guard let host = environment.graphUpdateHost else {
                backend.runInMainThread(action: update)
                continue
            }
            if delay == 0 {
                host.enqueue(
                    backend: backend,
                    transaction: environment.transaction,
                    key: AnyHashable("\(ObjectIdentifier(self)):\(id)"),
                    action: update
                )
            } else {
                host.enqueueAfter(
                    backend: backend,
                    delay: delay,
                    transaction: environment.transaction,
                    key: AnyHashable("\(ObjectIdentifier(self)):\(id)"),
                    action: update
                )
            }
        }
    }

    private func scheduleCleanup<Backend: BaseAppBackend>(
        environment: EnvironmentValues,
        backend: Backend
    ) {
        for index in fragmentNodes.indices
            where fragmentNodes[index].role == .outgoing && !fragmentNodes[index].cleanupScheduled
        {
            fragmentNodes[index].cleanupScheduled = true
            let id = fragmentNodes[index].id
            let delay = max(transitionDuration + fragmentNodes[index].delay, 0.001)
            let cleanup = {
                self.fragmentNodes.removeAll { $0.id == id }
                if !self.fragmentNodes.contains(where: { $0.role == .outgoing || !$0.advanced }) {
                    self.fragmentNodes = []
                }
                self.needsRebuild = true
                environment.onResize(.zero)
            }
            guard let host = environment.graphUpdateHost else {
                backend.runInMainThread(action: cleanup)
                continue
            }
            host.enqueueAfter(
                backend: backend,
                delay: delay,
                transaction: environment.transaction,
                key: AnyHashable("\(ObjectIdentifier(self)):cleanup:\(id)"),
                action: cleanup
            )
        }
    }
}

private enum TextFragmentRole {
    case stable
    case outgoing
    case incoming

    var sortOrder: Int {
        switch self {
            case .stable: 0
            case .outgoing: 1
            case .incoming: 2
        }
    }
}

private struct TextFragmentKey: Hashable {
    var characterIndex: Int
    var text: String
    var x: Int
    var y: Int
}

private struct TextFragmentNode {
    var id: Int
    var runID: Int
    var role: TextFragmentRole
    var characterIndex: Int?
    var text: String
    var node: ErasedViewGraphNode
    var initialView: AnyView
    var targetView: AnyView
    var position: SIMD2<Int>
    var size: SIMD2<Int>
    var delay: TimeInterval
    var advanced: Bool
    var phaseUpdateScheduled = false
    var cleanupScheduled = false

    var key: TextFragmentKey? {
        characterIndex.map {
            TextFragmentKey(
                characterIndex: $0,
                text: text,
                x: position.x,
                y: position.y
            )
        }
    }
}

private struct TextLayoutSnapshot {
    var text: String
    var characters: [Character]
    var fragments: [Int: TextLayoutFragment]

    @MainActor init?<Backend: BaseAppBackend>(
        text: String,
        widget: Backend.Widget,
        proposedSize: ProposedViewSize,
        environment: EnvironmentValues,
        backend: Backend
    ) {
        guard let fragments = backend.textLayoutFragments(
            of: text,
            whenDisplayedIn: widget,
            proposedWidth: Text.proposedTextWidth(proposedSize),
            proposedHeight: Text.proposedTextHeight(proposedSize),
            environment: environment
        ) else {
            return nil
        }
        self.text = text
        self.characters = Array(text)
        self.fragments = Dictionary(
            fragments.map { ($0.characterIndex, $0) },
            uniquingKeysWith: { first, _ in first }
        )
    }

    func fragment(at index: Int) -> TextLayoutFragment? {
        fragments[index]
    }
}

private struct StaticTextFragment: ElementaryView, LayoutInputKeyProvider {
    var string: String

    init(_ string: String) {
        self.string = string
    }

    var layoutInputKey: AnyHashable? {
        LayoutInputKeys.make(Self.self, values: [AnyHashable(string)])
    }

    func asWidget<Backend: BaseAppBackend>(backend: Backend) -> Backend.Widget {
        backend.createTextView()
    }

    func computeLayout<Backend: BaseAppBackend>(
        _ widget: Backend.Widget,
        proposedSize: ProposedViewSize,
        environment: EnvironmentValues,
        backend: Backend
    ) -> ViewLayoutResult {
        backend.updateTextView(widget, content: string, environment: environment)
        let size = proposedSize.concrete ?? ViewSize(
            backend.size(
                of: string,
                whenDisplayedIn: widget,
                proposedWidth: Text.proposedTextWidth(proposedSize),
                proposedHeight: Text.proposedTextHeight(proposedSize),
                environment: environment
            )
        )
        return .leafView(size: size)
    }

    func commit<Backend: BaseAppBackend>(
        _ widget: Backend.Widget,
        layout: ViewLayoutResult,
        environment: EnvironmentValues,
        backend: Backend
    ) {
        backend.setSize(of: widget, to: layout.size.vector)
    }
}
