import Foundation

@MainActor
final class LayoutPresentationStore {
    static let shared = LayoutPresentationStore()

    private var animations: [
        ObjectIdentifier: PresentationAnimation<AnimatablePair<Double, Double>>
    ] = [:]

    func seedPositionIfNeeded(for id: ObjectIdentifier, position: Position) {
        let animation = animations[id] ?? PresentationAnimation()
        if !animation.hasValue {
            animation.reset(to: AnimatablePair(position.x, position.y))
        }
        animations[id] = animation
    }

    func removePosition(for id: ObjectIdentifier) {
        animations[id] = nil
    }

    func position(
        for id: ObjectIdentifier,
        target: Position,
        transaction: Transaction,
        environment: EnvironmentValues,
        requestFrame: @escaping @MainActor (Transaction) -> Void
    ) -> Position {
        let animation = animations[id] ?? PresentationAnimation()
        animations[id] = animation

        let presentation = animation.value(
            for: AnimatablePair(target.x, target.y),
            transaction: transaction,
            environment: environment,
            requestFrame: requestFrame
        )
        return Position(presentation.first, presentation.second)
    }
}
