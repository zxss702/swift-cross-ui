import Foundation

/// A curve that maps linear progress in `[0, 1]` to eased progress.
public struct UnitCurve: Sendable, Hashable {
    enum Function: Sendable, Hashable {
        case linear
        case circularEaseIn
        case circularEaseOut
        case circularEaseInOut
        case bezier(startControlPoint: UnitPoint, endControlPoint: UnitPoint)
    }

    var function: Function

    public static let linear = UnitCurve(function: .linear)
    public static let easeIn = UnitCurve(
        function: .bezier(
            startControlPoint: UnitPoint(x: 0.42, y: 0),
            endControlPoint: UnitPoint(x: 1, y: 1)
        )
    )
    public static let easeOut = UnitCurve(
        function: .bezier(
            startControlPoint: UnitPoint(x: 0, y: 0),
            endControlPoint: UnitPoint(x: 0.58, y: 1)
        )
    )
    public static let easeInOut = UnitCurve(
        function: .bezier(
            startControlPoint: UnitPoint(x: 0.42, y: 0),
            endControlPoint: UnitPoint(x: 0.58, y: 1)
        )
    )
    public static let circularEaseIn = UnitCurve(function: .circularEaseIn)
    public static let circularEaseOut = UnitCurve(function: .circularEaseOut)
    public static let circularEaseInOut = UnitCurve(function: .circularEaseInOut)

    public static func bezier(
        startControlPoint: UnitPoint,
        endControlPoint: UnitPoint
    ) -> UnitCurve {
        UnitCurve(
            function: .bezier(
                startControlPoint: startControlPoint,
                endControlPoint: endControlPoint
            )
        )
    }

    public func value(at progress: Double) -> Double {
        let progress = progress.clamped(to: 0...1)
        switch function {
            case .linear:
                return progress
            case .circularEaseIn:
                return 1 - sqrt(max(0, 1 - progress * progress))
            case .circularEaseOut:
                let inverse = 1 - progress
                return sqrt(max(0, 1 - inverse * inverse))
            case .circularEaseInOut:
                if progress < 0.5 {
                    let doubled = progress * 2
                    return (1 - sqrt(max(0, 1 - doubled * doubled))) / 2
                } else {
                    let doubled = (1 - progress) * 2
                    return (1 + sqrt(max(0, 1 - doubled * doubled))) / 2
                }
            case .bezier(let start, let end):
                return CubicBezier(
                    x1: start.x.clamped(to: 0...1),
                    y1: start.y,
                    x2: end.x.clamped(to: 0...1),
                    y2: end.y
                )
                .solve(progress)
        }
    }

    public func velocity(at progress: Double) -> Double {
        let progress = progress.clamped(to: 0...1)
        switch function {
            case .linear:
                return 1
            default:
                let delta = 0.000_1
                let lower = max(0, progress - delta)
                let upper = min(1, progress + delta)
                guard upper > lower else {
                    return 0
                }
                return (value(at: upper) - value(at: lower)) / (upper - lower)
        }
    }

    public var inverse: UnitCurve {
        switch function {
            case .linear:
                return .linear
            case .circularEaseIn:
                return .circularEaseOut
            case .circularEaseOut:
                return .circularEaseIn
            case .circularEaseInOut:
                return .circularEaseInOut
            case .bezier(let start, let end):
                return .bezier(
                    startControlPoint: UnitPoint(x: start.y, y: start.x),
                    endControlPoint: UnitPoint(x: end.y, y: end.x)
                )
        }
    }
}

/// Describes how a value changes over time.
public struct Animation: Sendable, Equatable, Hashable {
    enum Storage: Sendable, Equatable, Hashable {
        case curve(UnitCurve, duration: Double)
        case spring(response: Double, dampingFraction: Double, blendDuration: Double)
        indirect case delay(Double, Storage)
        indirect case speed(Double, Storage)
        indirect case repeated(Storage, count: Int?, autoreverses: Bool)
    }

    var storage: Storage

    init(storage: Storage) {
        self.storage = storage
    }

    public static let `default` = Animation.easeInOut
    public static let linear = Animation.linear(duration: 0.35)
    public static let easeIn = Animation.easeIn(duration: 0.35)
    public static let easeOut = Animation.easeOut(duration: 0.35)
    public static let easeInOut = Animation.easeInOut(duration: 0.35)
    public static let smooth = Animation.spring(response: 0.5, dampingFraction: 1)
    public static let snappy = Animation.spring(response: 0.35, dampingFraction: 0.85)
    public static let bouncy = Animation.spring(response: 0.5, dampingFraction: 0.62)

    public static func linear(duration: Double) -> Animation {
        Animation(storage: .curve(.linear, duration: duration))
    }

    public static func easeIn(duration: Double) -> Animation {
        Animation(storage: .curve(.easeIn, duration: duration))
    }

    public static func easeOut(duration: Double) -> Animation {
        Animation(storage: .curve(.easeOut, duration: duration))
    }

    public static func easeInOut(duration: Double) -> Animation {
        Animation(storage: .curve(.easeInOut, duration: duration))
    }

    public static func timingCurve(
        _ c0x: Double,
        _ c0y: Double,
        _ c1x: Double,
        _ c1y: Double,
        duration: Double = 0.35
    ) -> Animation {
        Animation(
            storage: .curve(
                .bezier(
                    startControlPoint: UnitPoint(x: c0x, y: c0y),
                    endControlPoint: UnitPoint(x: c1x, y: c1y)
                ),
                duration: duration
            )
        )
    }

    public static func spring(
        duration: Double = 0.5,
        bounce: Double = 0,
        blendDuration: Double = 0
    ) -> Animation {
        spring(
            response: duration,
            dampingFraction: max(0.05, min(1.5, 1 - bounce * 0.5)),
            blendDuration: blendDuration
        )
    }

    public static func spring(
        response: Double = 0.55,
        dampingFraction: Double = 0.825,
        blendDuration: Double = 0
    ) -> Animation {
        Animation(
            storage: .spring(
                response: response,
                dampingFraction: dampingFraction,
                blendDuration: blendDuration
            )
        )
    }

    public static func interactiveSpring(
        response: Double = 0.15,
        dampingFraction: Double = 0.86,
        blendDuration: Double = 0.25
    ) -> Animation {
        .spring(
            response: response,
            dampingFraction: dampingFraction,
            blendDuration: blendDuration
        )
    }

    public static func smooth(
        duration: Double = 0.5,
        extraBounce: Double = 0
    ) -> Animation {
        .spring(
            response: duration,
            dampingFraction: max(0.75, 1 - extraBounce * 0.35)
        )
    }

    public static func snappy(
        duration: Double = 0.35,
        extraBounce: Double = 0
    ) -> Animation {
        .spring(
            response: duration,
            dampingFraction: max(0.65, 0.85 - extraBounce * 0.3)
        )
    }

    public static func bouncy(
        duration: Double = 0.5,
        extraBounce: Double = 0
    ) -> Animation {
        .spring(
            response: duration,
            dampingFraction: max(0.35, 0.62 - extraBounce * 0.35)
        )
    }

    public func delay(_ delay: Double) -> Animation {
        Animation(storage: .delay(delay, storage))
    }

    public func speed(_ speed: Double) -> Animation {
        Animation(storage: .speed(speed, storage))
    }

    public func repeatCount(_ count: Int, autoreverses: Bool = true) -> Animation {
        Animation(storage: .repeated(storage, count: max(1, count), autoreverses: autoreverses))
    }

    public func repeatForever(autoreverses: Bool = true) -> Animation {
        Animation(storage: .repeated(storage, count: nil, autoreverses: autoreverses))
    }

    func value(at elapsed: Double) -> Double {
        evaluate(storage, elapsed: max(0, elapsed)).progress
    }

    func isComplete(at elapsed: Double) -> Bool {
        evaluate(storage, elapsed: max(0, elapsed)).isComplete
    }

    var totalDuration: Double {
        duration(of: storage)
    }

    private func duration(of storage: Storage) -> Double {
        switch storage {
            case .curve(_, let duration):
                return max(duration, 0)
            case .spring(let response, _, let blendDuration):
                return max(response, 0.01) * 2.5 + max(blendDuration, 0)
            case .delay(let delay, let base):
                return max(delay, 0) + duration(of: base)
            case .speed(let speed, let base):
                return duration(of: base) / max(abs(speed), 0.000_1)
            case .repeated(let base, let count, _):
                guard let count else {
                    return .infinity
                }
                return duration(of: base) * Double(max(count, 1))
        }
    }

    private func evaluate(_ storage: Storage, elapsed: Double) -> (progress: Double, isComplete: Bool) {
        switch storage {
            case .curve(let curve, let duration):
                let duration = max(duration, 0.000_1)
                let linearProgress = elapsed / duration
                return (curve.value(at: min(linearProgress, 1)), linearProgress >= 1)
            case .spring(let response, let dampingFraction, let blendDuration):
                let duration = max(response, 0.01) * 2.5 + max(blendDuration, 0)
                let linearProgress = elapsed / max(duration, 0.000_1)
                let progress = SpringCurve(
                    response: response,
                    dampingFraction: dampingFraction
                )
                .value(at: min(linearProgress, 1))
                return (progress, linearProgress >= 1)
            case .delay(let delay, let base):
                if elapsed < delay {
                    return (0, false)
                }
                return evaluate(base, elapsed: elapsed - max(delay, 0))
            case .speed(let speed, let base):
                return evaluate(base, elapsed: elapsed * max(abs(speed), 0.000_1))
            case .repeated(let base, let count, let autoreverses):
                let baseDuration = max(duration(of: base), 0.000_1)
                if count == nil {
                    return repeatedValue(base, elapsed: elapsed, baseDuration: baseDuration, autoreverses: autoreverses)
                }
                let cycles = max(count ?? 1, 1)
                let total = baseDuration * Double(cycles)
                if elapsed >= total {
                    return (autoreverses && cycles.isMultiple(of: 2) ? 0 : 1, true)
                }
                return repeatedValue(base, elapsed: elapsed, baseDuration: baseDuration, autoreverses: autoreverses)
        }
    }

    private func repeatedValue(
        _ base: Storage,
        elapsed: Double,
        baseDuration: Double,
        autoreverses: Bool
    ) -> (progress: Double, isComplete: Bool) {
        let cycle = max(0, Int((elapsed / baseDuration).rounded(.down)))
        let cycleElapsed = elapsed - Double(cycle) * baseDuration
        var progress = evaluate(base, elapsed: cycleElapsed).progress
        if autoreverses && !cycle.isMultiple(of: 2) {
            progress = 1 - progress
        }
        return (progress, false)
    }
}

private struct CubicBezier: Sendable, Hashable {
    var x1: Double
    var y1: Double
    var x2: Double
    var y2: Double

    func solve(_ x: Double) -> Double {
        var t = x
        for _ in 0..<8 {
            let xEstimate = sampleCurveX(t) - x
            let derivative = sampleCurveDerivativeX(t)
            if abs(derivative) < 0.000_001 {
                break
            }
            t = (t - xEstimate / derivative).clamped(to: 0...1)
        }
        return sampleCurveY(t)
    }

    private func sampleCurveX(_ t: Double) -> Double {
        let inv = 1 - t
        return 3 * inv * inv * t * x1 + 3 * inv * t * t * x2 + t * t * t
    }

    private func sampleCurveY(_ t: Double) -> Double {
        let inv = 1 - t
        return 3 * inv * inv * t * y1 + 3 * inv * t * t * y2 + t * t * t
    }

    private func sampleCurveDerivativeX(_ t: Double) -> Double {
        let inv = 1 - t
        return 3 * inv * inv * x1 + 6 * inv * t * (x2 - x1) + 3 * t * t * (1 - x2)
    }
}

private struct SpringCurve: Sendable, Hashable {
    var response: Double
    var dampingFraction: Double

    func value(at progress: Double) -> Double {
        let damping = max(0.01, dampingFraction)
        let omega = 2 * Double.pi / max(response, 0.01)
        let time = progress * max(response, 0.01) * 2.5

        if damping < 1 {
            let dampedOmega = omega * sqrt(1 - damping * damping)
            let envelope = exp(-damping * omega * time)
            return 1 - envelope * (
                cos(dampedOmega * time)
                    + (damping / sqrt(1 - damping * damping)) * sin(dampedOmega * time)
            )
        } else {
            let envelope = exp(-omega * time)
            return 1 - envelope * (1 + omega * time)
        }
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
