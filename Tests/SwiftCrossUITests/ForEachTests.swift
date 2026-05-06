import Testing

import DummyBackend
@testable import SwiftCrossUI

@Suite("Testing for ForEach")
struct ForEachTests {
    @MainActor
    @Test("Duplicate ids", .bug("https://github.com/moreSwift/swift-cross-ui/issues/456"))
    func duplicateIds() {
        let backend = DummyBackend()
        let window = backend.createSurface(withDefaultSize: nil as SIMD2<Int>?)
        let environment = EnvironmentValues(backend: backend).with(\.window, window)

        let view = ForEach([1, 1], id: \.self) { x in
            Text("\(x)")
        }

        let node = ViewGraphNode(for: view, backend: backend, environment: environment)
        _ = node.computeLayout(
            proposedSize: .unspecified,
            environment: environment
        )
        // This will crash if the duplicate identifiers bug happens
        _ = node.commit()

        // Re-layout the view, because the nature of the duplicate handling bug changed
        // depending on the existing set of nodes before the update
        _ = node.computeLayout(
            with: view,
            proposedSize: .unspecified,
            environment: environment
        )
        _ = node.commit()
    }
    
    @MainActor
    @Test("Reordered children")
    func reorderedChildren() {
        let backend = DummyBackend()
        let window = backend.createSurface(withDefaultSize: nil as SIMD2<Int>?)
        let environment = EnvironmentValues(backend: backend).with(\.window, window)

        func makeView(_ ids: [Int]) -> ForEach<[Int], Int, TupleView1<Text>> {
            ForEach(ids, id: \.self) { x in
                Text("\(x)")
            }
        }

        let values = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]
        var forEach = makeView(values)

        // Perform the initial update
        let node = ViewGraphNode(for: forEach, backend: backend, environment: environment)
        _ = node.computeLayout(
            proposedSize: .unspecified,
            environment: environment
        )
        _ = node.commit()

        // Initialize the state of each view to match its index
        let originalErasedNodes = node.children.erasedNodes
        let originalNodes = originalErasedNodes.map(\.node)
        let originalWidgets = node.widget.getChildren()

        #expect(originalNodes.count == values.count)
        #expect(originalWidgets.count == values.count)

        // let values =    [11, 1, 5, 3, 4, 2, 6, 7, 8, 9, 10]
        let newValues = [11, 1, 5, 6, 2, 4, 3]

        forEach = makeView(newValues)
        _ = node.computeLayout(
            with: forEach,
            proposedSize: .unspecified,
            environment: environment
        )
        _ = node.commit()

        let newErasedNodes = node.children.erasedNodes
        let newNodes = newErasedNodes.map(\.node)
        let newWidgets = node.widget.getChildren()

        // Sanity check
        #expect(newNodes.count == newValues.count)
        #expect(newWidgets.count == newValues.count)

        // Have we successfully re-used all nodes whose identifiers are present
        // in both values and newValues?
        for (originalNode, originalId) in zip(originalNodes, values) {
            for (newNode, newId) in zip(newNodes, newValues) {
                #expect(
                    (originalNode === newNode)
                    <=>
                    (originalId == newId)
                )
            }
        }

        // Have we successfully re-arranged the widgets to match the nodes?
        #expect(zip(originalWidgets, originalErasedNodes).allSatisfy { $0.0 === $0.1.getWidget().into() })
        #expect(zip(newWidgets, newErasedNodes).allSatisfy { $0.0 === $0.1.getWidget().into() })
    }
<<<<<<< Updated upstream
=======

    @MainActor
    @Test("Moved keyed children keep old presentation positions")
    func movedKeyedChildrenKeepOldPresentationPositions() {
        let backend = DummyBackend()
        let window = backend.createSurface(withDefaultSize: nil as SIMD2<Int>?)
        let transaction = Transaction(animation: .linear(duration: 1))
        let environment = EnvironmentValues(backend: backend)
            .with(\.window, window)
            .withCurrentTransaction(transaction)

        func makeView(_ ids: [Int]) -> some View {
            HStack(spacing: 10) {
                ForEach(ids, id: \.self) { x in
                    Text("\(x)")
                        .frame(width: 40, height: 20)
                }
            }
        }

        let node = ViewGraphNode(
            for: makeView([1, 2, 3]),
            backend: backend,
            environment: environment
        )
        _ = node.computeLayout(proposedSize: .unspecified, environment: environment)
        _ = node.commit()

        _ = node.computeLayout(
            with: makeView([3, 1, 2]),
            proposedSize: .unspecified,
            environment: environment
        )
        _ = node.commit()

        let forEachContainer = node.widget.getChildren()[0] as! DummyBackend.Container
        let positions = forEachContainer.children.map(\.position.x)

        #expect(positions == [100, 0, 50])
    }

    @MainActor
    @Test("Insertion transition starts from active phase")
    func insertionTransitionStartsFromActivePhase() {
        let backend = DummyBackend()
        let window = backend.createSurface(withDefaultSize: nil as SIMD2<Int>?)
        let transaction = Transaction(animation: .linear(duration: 1))
        let environment = EnvironmentValues(backend: backend)
            .with(\.window, window)
            .with(\.transaction, transaction)

        let node = ViewGraphNode(
            for: transitioningTextForEach([1, 2, 3]),
            backend: backend,
            environment: environment
        )
        _ = node.computeLayout(proposedSize: .unspecified, environment: environment)
        _ = node.commit()

        _ = node.computeLayout(
            with: transitioningTextForEach([1, 2, 3, 4]),
            proposedSize: .unspecified,
            environment: environment
        )
        _ = node.commit()

        #expect(node.widget.containsWidget { $0.opacity == 0 })
    }

    @MainActor
    @Test("Removal transition keeps removed node as ghost")
    func removalTransitionKeepsRemovedNodeAsGhost() {
        let backend = DummyBackend()
        let window = backend.createSurface(withDefaultSize: nil as SIMD2<Int>?)
        let environment = EnvironmentValues(backend: backend)
            .with(\.window, window)
            .with(\.transaction, Transaction(animation: .linear(duration: 1)))

        let node = ViewGraphNode(
            for: transitioningTextForEach([1, 2, 3]),
            backend: backend,
            environment: environment
        )
        _ = node.computeLayout(proposedSize: .unspecified, environment: environment)
        _ = node.commit()

        let originalNodes = node.children.erasedNodes.map { $0.node }

        _ = node.computeLayout(
            with: transitioningTextForEach([1, 2]),
            proposedSize: .unspecified,
            environment: environment
        )
        _ = node.commit()

        let updatedNodes = node.children.erasedNodes.map { $0.node }
        #expect(updatedNodes.count == 3)
        #expect(updatedNodes.last === originalNodes.last)
    }

    @MainActor
    @Test("Consecutive removals keep render list consistent")
    func consecutiveRemovalsKeepRenderListConsistent() {
        let backend = DummyBackend()
        let window = backend.createSurface(withDefaultSize: nil as SIMD2<Int>?)
        let environment = EnvironmentValues(backend: backend)
            .with(\.window, window)
            .with(\.transaction, Transaction(animation: .linear(duration: 1)))

        let node = ViewGraphNode(
            for: transitioningTextForEach([1, 2, 3, 4, 5]),
            backend: backend,
            environment: environment
        )
        _ = node.computeLayout(proposedSize: .unspecified, environment: environment)
        _ = node.commit()

        _ = node.computeLayout(
            with: transitioningTextForEach([1, 2, 3, 4]),
            proposedSize: .unspecified,
            environment: environment
        )
        _ = node.commit()

        _ = node.computeLayout(
            with: transitioningTextForEach([1, 2, 3]),
            proposedSize: .unspecified,
            environment: environment
        )
        _ = node.commit()

        let widgets = node.widget.getChildren()
        let uniqueWidgets = Set(widgets.map(ObjectIdentifier.init))
        #expect(widgets.count == node.children.erasedNodes.count)
        #expect(uniqueWidgets.count == widgets.count)
    }

    @MainActor
    @Test("Middle removal keeps active identity and one removal presentation child")
    func middleRemovalKeepsActiveIdentityAndRemovalPresentationChild() {
        let backend = DummyBackend()
        let window = backend.createSurface(withDefaultSize: nil as SIMD2<Int>?)
        let environment = EnvironmentValues(backend: backend)
            .with(\.window, window)
            .with(\.transaction, Transaction(animation: .linear(duration: 1)))

        let node = ViewGraphNode(
            for: transitioningTextForEach([1, 2, 3, 4]),
            backend: backend,
            environment: environment
        )
        _ = node.computeLayout(proposedSize: .unspecified, environment: environment)
        _ = node.commit()

        let originalNodes = node.children.erasedNodes.map { $0.node }

        _ = node.computeLayout(
            with: transitioningTextForEach([1, 3, 4]),
            proposedSize: .unspecified,
            environment: environment
        )
        _ = node.commit()

        let renderedNodes = node.children.erasedNodes.map { $0.node }
        let widgets = node.widget.getChildren()

        #expect(renderedNodes.count == 4)
        #expect(widgets.count == 4)
        #expect(ObjectIdentifier(renderedNodes[0]) == ObjectIdentifier(originalNodes[0]))
        #expect(ObjectIdentifier(renderedNodes[1]) == ObjectIdentifier(originalNodes[2]))
        #expect(ObjectIdentifier(renderedNodes[2]) == ObjectIdentifier(originalNodes[3]))
        #expect(ObjectIdentifier(renderedNodes[3]) == ObjectIdentifier(originalNodes[1]))
    }

    @MainActor
    @Test("Explicit id recreates child identity only when id changes")
    func explicitIDRecreatesChildIdentityOnlyWhenIDChanges() {
        let backend = DummyBackend()
        let window = backend.createSurface(withDefaultSize: nil as SIMD2<Int>?)
        let environment = EnvironmentValues(backend: backend)
            .with(\.window, window)

        func makeView(_ id: Int) -> IDView<Text, Int> {
            IDView(content: Text("value"), id: id)
        }

        let node = ViewGraphNode(
            for: makeView(1),
            backend: backend,
            environment: environment
        )
        _ = node.computeLayout(proposedSize: .unspecified, environment: environment)
        _ = node.commit()

        let originalNode = node.children.erasedNodes[0].node

        _ = node.computeLayout(
            with: makeView(1),
            proposedSize: .unspecified,
            environment: environment
        )
        _ = node.commit()
        #expect(ObjectIdentifier(node.children.erasedNodes[0].node) == ObjectIdentifier(originalNode))

        _ = node.computeLayout(
            with: makeView(2),
            proposedSize: .unspecified,
            environment: environment
        )
        _ = node.commit()
        #expect(ObjectIdentifier(node.children.erasedNodes[0].node) != ObjectIdentifier(originalNode))
    }
>>>>>>> Stashed changes
}

infix operator <=>

func <=> (_ lhs: Bool, _ rhs: Bool) -> Bool {
    lhs == rhs
}
