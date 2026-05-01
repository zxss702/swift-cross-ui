import SwiftCrossUI

enum AnimationPreset: CaseIterable, CustomStringConvertible, Equatable {
    case `default`
    case linear
    case easeIn
    case easeOut
    case easeInOut
    case timingCurve
    case spring
    case interactiveSpring
    case interpolatingSpring
    case smooth
    case snappy
    case bouncy
    case delayed
    case repeated
    case fast

    var animation: Animation {
        switch self {
            case .default:
                .default
            case .linear:
                .linear(duration: 0.7)
            case .easeIn:
                .easeIn(duration: 0.7)
            case .easeOut:
                .easeOut(duration: 0.7)
            case .easeInOut:
                .easeInOut(duration: 0.7)
            case .timingCurve:
                .timingCurve(0.2, 0.8, 0.2, 1, duration: 0.75)
            case .spring:
                .spring(duration: 0.65, bounce: 0.25)
            case .interactiveSpring:
                .interactiveSpring(response: 0.22, dampingFraction: 0.72)
            case .interpolatingSpring:
                .interpolatingSpring(
                    mass: 1,
                    stiffness: 80,
                    damping: 9,
                    initialVelocity: 1.2
                )
            case .smooth:
                .smooth(duration: 0.65)
            case .snappy:
                .snappy(duration: 0.5, extraBounce: 0.08)
            case .bouncy:
                .bouncy(duration: 0.8, extraBounce: 0.1)
            case .delayed:
                .easeInOut(duration: 0.55).delay(0.18)
            case .repeated:
                .easeInOut(duration: 0.35).repeatCount(3, autoreverses: true)
            case .fast:
                .easeInOut(duration: 0.7).speed(1.8)
        }
    }

    var description: String {
        switch self {
            case .default:
                "default"
            case .linear:
                "linear"
            case .easeIn:
                "easeIn"
            case .easeOut:
                "easeOut"
            case .easeInOut:
                "easeInOut"
            case .timingCurve:
                "timingCurve"
            case .spring:
                "spring"
            case .interactiveSpring:
                "interactiveSpring"
            case .interpolatingSpring:
                "interpolatingSpring"
            case .smooth:
                "smooth"
            case .snappy:
                "snappy"
            case .bouncy:
                "bouncy"
            case .delayed:
                "delay"
            case .repeated:
                "repeatCount"
            case .fast:
                "speed"
        }
    }
}
