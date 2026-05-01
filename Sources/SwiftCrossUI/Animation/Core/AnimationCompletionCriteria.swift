/// The point at which an animation completion should run.
public struct AnimationCompletionCriteria: Hashable, Sendable {
    public static let logicallyComplete = Self(name: "logicallyComplete")
    public static let removed = Self(name: "removed")

    private var name: String

    private init(name: String) {
        self.name = name
    }
}

