import SwiftCrossUI

enum MotionPhase: CaseIterable, Equatable {
    case idle
    case lift
    case travel
    case settle

    var offset: Double {
        switch self {
            case .idle:
                0
            case .lift:
                42
            case .travel:
                168
            case .settle:
                120
        }
    }

    var scale: Double {
        switch self {
            case .idle:
                1
            case .lift:
                1.2
            case .travel:
                0.82
            case .settle:
                1.05
        }
    }

    var rotation: Angle {
        switch self {
            case .idle:
                .degrees(0)
            case .lift:
                .degrees(-12)
            case .travel:
                .degrees(18)
            case .settle:
                .degrees(0)
        }
    }

    var animation: Animation {
        switch self {
            case .idle:
                .smooth(duration: 0.45)
            case .lift:
                .snappy(duration: 0.35)
            case .travel:
                .easeInOut(duration: 0.55)
            case .settle:
                .bouncy(duration: 0.6)
        }
    }
}
