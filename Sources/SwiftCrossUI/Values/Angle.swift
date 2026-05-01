/// An angle measured in radians.
public struct Angle: Hashable, Sendable {
    public var radians: Double

    public var degrees: Double {
        radians * 180 / .pi
    }

    public init(radians: Double) {
        self.radians = radians
    }

    public init(degrees: Double) {
        self.radians = degrees * .pi / 180
    }

    public static func radians(_ radians: Double) -> Self {
        Self(radians: radians)
    }

    public static func degrees(_ degrees: Double) -> Self {
        Self(degrees: degrees)
    }
}

