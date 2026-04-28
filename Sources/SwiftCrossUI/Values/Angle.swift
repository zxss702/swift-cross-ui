/// A geometric angle whose value can be read or written in radians or degrees.
public struct Angle: Hashable, Comparable, Sendable {
    public var radians: Double

    public var degrees: Double {
        get { radians * (180.0 / .pi) }
        set { radians = newValue * (.pi / 180.0) }
    }

    public init() {
        self.init(radians: 0)
    }

    public init(radians: Double) {
        self.radians = radians
    }

    public init(degrees: Double) {
        self.init(radians: degrees * (.pi / 180.0))
    }

    public static func radians(_ radians: Double) -> Angle {
        Angle(radians: radians)
    }

    public static func degrees(_ degrees: Double) -> Angle {
        Angle(degrees: degrees)
    }

    public static var zero: Angle {
        Angle()
    }

    public static func < (lhs: Angle, rhs: Angle) -> Bool {
        lhs.radians < rhs.radians
    }
}

extension Angle: Animatable {
    public typealias AnimatableData = Double

    public var animatableData: Double {
        get { radians }
        set { radians = newValue }
    }
}
