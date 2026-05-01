/// A point in a unit coordinate space.
public struct UnitPoint: Hashable, Sendable {
    public static let zero = Self(x: 0, y: 0)
    public static let center = Self(x: 0.5, y: 0.5)
    public static let leading = Self(x: 0, y: 0.5)
    public static let trailing = Self(x: 1, y: 0.5)
    public static let top = Self(x: 0.5, y: 0)
    public static let bottom = Self(x: 0.5, y: 1)
    public static let topLeading = Self(x: 0, y: 0)
    public static let topTrailing = Self(x: 1, y: 0)
    public static let bottomLeading = Self(x: 0, y: 1)
    public static let bottomTrailing = Self(x: 1, y: 1)

    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

