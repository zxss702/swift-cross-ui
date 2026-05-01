import SwiftCrossUI

struct PivotTransition: Transition {
    static var properties: TransitionProperties {
        TransitionProperties(hasMotion: true)
    }

    func body(content: Content, phase: TransitionPhase) -> some View {
        content
            .opacity(phase.isIdentity ? 1 : 0)
            .scaleEffect(phase.isIdentity ? 1 : 0.7, anchor: .topLeading)
            .rotationEffect(.degrees(phase.isIdentity ? 0 : -18), anchor: .topLeading)
            .offset(x: phase.isIdentity ? 0 : -36, y: phase.isIdentity ? 0 : 22)
    }
}
