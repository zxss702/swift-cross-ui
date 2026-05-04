/// A timing curve that maps linear progress to eased progress.
public struct UnitCurve: Hashable, Sendable {
    private indirect enum Storage: Hashable, Sendable {
        case bezier(UnitPoint, UnitPoint)
        case circularEaseIn
        case circularEaseOut
        case circularEaseInOut
        case inverse(UnitCurve)
    }

    public static let linear = Self.bezier(
        startControlPoint: UnitPoint(x: 0, y: 0),
        endControlPoint: UnitPoint(x: 1, y: 1)
    )
    public static let easeIn = Self.bezier(
        startControlPoint: UnitPoint(x: 0.42, y: 0),
        endControlPoint: UnitPoint(x: 1, y: 1)
    )
    public static let easeOut = Self.bezier(
        startControlPoint: UnitPoint(x: 0, y: 0),
        endControlPoint: UnitPoint(x: 0.58, y: 1)
    )
    public static let easeInOut = Self.bezier(
        startControlPoint: UnitPoint(x: 0.42, y: 0),
        endControlPoint: UnitPoint(x: 0.58, y: 1)
    )
    public static let easeInEaseOut = easeInOut
    public static let circularEaseIn = Self(storage: .circularEaseIn)
    public static let circularEaseOut = Self(storage: .circularEaseOut)
    public static let circularEaseInOut = Self(storage: .circularEaseInOut)

    private let storage: Storage

    private init(storage: Storage) {
        self.storage = storage
    }

    public static func bezier(
        startControlPoint: UnitPoint,
        endControlPoint: UnitPoint
    ) -> UnitCurve {
        Self(storage: .bezier(startControlPoint, endControlPoint))
    }

    /// Returns the eased value at the given progress.
    public func value(at progress: Double) -> Double {
        let progress = progress.clamped(to: 0...1)
        switch storage {
            case .bezier(let p1, let p2):
                return cubicBezierY(atX: progress, p1: p1, p2: p2)
            case .circularEaseIn:
                return 1 - (1 - progress * progress).squareRoot()
            case .circularEaseOut:
                let inverse = 1 - progress
                return (1 - inverse * inverse).squareRoot()
            case .circularEaseInOut:
                if progress < 0.5 {
                    return (1 - (1 - 4 * progress * progress).squareRoot()) / 2
                } else {
                    let inverse = -2 * progress + 2
                    return ((1 - inverse * inverse).squareRoot() + 1) / 2
                }
            case .inverse(let curve):
                return solveInverseValue(of: curve, at: progress)
        }
    }

    /// Returns the approximate velocity at the given progress.
    public func velocity(at progress: Double) -> Double {
        let delta = 0.0001
        let lower = max(0, progress - delta)
        let upper = min(1, progress + delta)
        guard upper > lower else {
            return 0
        }
        return (value(at: upper) - value(at: lower)) / (upper - lower)
    }

    /// A curve that approximately inverts this curve's output.
    public var inverse: UnitCurve {
        Self(storage: .inverse(self))
    }

    private func cubicBezierY(atX x: Double, p1: UnitPoint, p2: UnitPoint) -> Double {
        var lower = 0.0
        var upper = 1.0
        var t = x
        for _ in 0..<12 {
            t = (lower + upper) / 2
            if cubicBezier(t, 0, p1.x, p2.x, 1) < x {
                lower = t
            } else {
                upper = t
            }
        }
        return cubicBezier(t, 0, p1.y, p2.y, 1)
    }

    private func solveInverseValue(of curve: UnitCurve, at y: Double) -> Double {
        var lower = 0.0
        var upper = 1.0
        var midpoint = y
        for _ in 0..<16 {
            midpoint = (lower + upper) / 2
            if curve.value(at: midpoint) < y {
                lower = midpoint
            } else {
                upper = midpoint
            }
        }
        return midpoint
    }

    private func cubicBezier(
        _ t: Double,
        _ p0: Double,
        _ p1: Double,
        _ p2: Double,
        _ p3: Double
    ) -> Double {
        let inverse = 1 - t
        return inverse * inverse * inverse * p0
            + 3 * inverse * inverse * t * p1
            + 3 * inverse * t * t * p2
            + t * t * t * p3
    }
}

extension Comparable {
    fileprivate func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
