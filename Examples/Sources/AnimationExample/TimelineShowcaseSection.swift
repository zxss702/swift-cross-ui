import SwiftCrossUI

struct TimelineShowcaseSection: View {
    var animation: Animation
    @Binding var phaseTrigger: Int
    @Binding var keyframeTrigger: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Phase and keyframe animation")
                .font(.headline)

            HStack(spacing: 12) {
                Button("Phase trigger") {
                    withAnimation(animation) {
                        phaseTrigger += 1
                    }
                }

                Button("Keyframe trigger") {
                    keyframeTrigger += 1
                }
            }

            HStack(spacing: 28) {
                phaseProbe
                keyframeProbe
                repeatingProbe
            }
        }
    }

    private var phaseProbe: some View {
        VStack(spacing: 8) {
            Text("PhaseAnimator")
                .font(.caption)

            Color.cyan
                .frame(width: 54, height: 54)
                .cornerRadius(8)
                .phaseAnimator(
                    MotionPhase.allCases,
                    trigger: phaseTrigger
                ) { content, phase in
                    content
                        .scaleEffect(phase.scale)
                        .rotationEffect(phase.rotation)
                        .offset(x: phase.offset)
                } animation: { phase in
                    phase.animation
                }
                .frame(width: 240, height: 80, alignment: .leading)
        }
    }

    private var keyframeProbe: some View {
        VStack(spacing: 8) {
            Text("KeyframeAnimator")
                .font(.caption)

            Color.purple
                .frame(width: 54, height: 54)
                .cornerRadius(8)
                .keyframeAnimator(
                    initialValue: KeyframeProbeValue(),
                    trigger: keyframeTrigger
                ) { content, value in
                    content
                        .scaleEffect(value.scale)
                        .rotationEffect(.degrees(value.rotation))
                        .opacity(value.opacity)
                        .offset(x: value.offset)
                } keyframes: { _ in
                    KeyframeTrack(\.offset) {
                        LinearKeyframe(150, duration: 0.32, timingCurve: .easeOut)
                        SpringKeyframe(40, duration: 0.42, spring: .bouncy)
                        LinearKeyframe(0, duration: 0.24, timingCurve: .easeInOut)
                    }
                    KeyframeTrack(\.scale) {
                        CubicKeyframe(1.35, duration: 0.28)
                        SpringKeyframe(0.85, duration: 0.36, spring: .snappy)
                        LinearKeyframe(1, duration: 0.28)
                    }
                    KeyframeTrack(\.rotation) {
                        MoveKeyframe(0)
                        LinearKeyframe(180, duration: 0.5)
                        LinearKeyframe(360, duration: 0.5)
                    }
                    KeyframeTrack(\.opacity) {
                        LinearKeyframe(0.45, duration: 0.24)
                        LinearKeyframe(1, duration: 0.42)
                    }
                }
                .frame(width: 240, height: 80, alignment: .leading)
        }
    }

    private var repeatingProbe: some View {
        VStack(spacing: 8) {
            Text("repeating")
                .font(.caption)

            Color.yellow
                .frame(width: 54, height: 54)
                .cornerRadius(8)
                .keyframeAnimator(initialValue: 0.0, repeating: true) { content, value in
                    content
                        .scaleEffect(0.75 + value * 0.5)
                        .opacity(0.35 + value * 0.65)
                        .offset(y: -18 * value)
                } keyframes: { _ in
                    LinearKeyframe(1.0, duration: 0.7, timingCurve: .easeInOut)
                    LinearKeyframe(0.0, duration: 0.7, timingCurve: .easeInOut)
                }
                .frame(width: 90, height: 80)
        }
    }
}
