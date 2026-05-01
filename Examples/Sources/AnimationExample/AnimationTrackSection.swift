import SwiftCrossUI

struct AnimationTrackSection: View {
    var animation: Animation
    @Binding var expanded: Bool
    @Binding var alternate: Bool
    @Binding var sliderValue: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Implicit and scoped animation")
                .font(.headline)

            Text("The rows below exercise animation(_:value:) and animation(_:body:).")
                .font(.caption)

            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("offset")
                        .frame(width: 120, alignment: .leading)

                    ZStack(alignment: .leading) {
                        Color.gray.opacity(0.18)
                            .frame(width: 280, height: 20)
                            .cornerRadius(10)

                        Color.blue
                            .frame(width: 78, height: 20)
                            .cornerRadius(10)
                            .offset(x: expanded ? 202 : 0)
                            .animation(animation, value: expanded)
                    }
                }

                HStack {
                    Text("opacity + blur")
                        .frame(width: 120, alignment: .leading)

                    HStack(spacing: 18) {
                        Color.orange
                            .frame(width: 64, height: 64)
                            .cornerRadius(8)
                            .opacity(expanded ? 1 : 0.32)
                            .blur(radius: expanded ? 0 : 5)
                            .animation(animation, value: expanded)

                        Color.teal
                            .frame(width: 64, height: 64)
                            .cornerRadius(8)
                            .opacity(alternate ? 0.35 : 1)
                            .blur(radius: alternate ? 7 : 0)
                            .animation(animation.delay(0.08), value: alternate)
                    }
                }

                HStack {
                    Text("closure scope")
                        .frame(width: 120, alignment: .leading)

                    Color.green
                        .frame(width: 74, height: 74)
                        .cornerRadius(8)
                        .animation(animation) { content in
                            content
                                .scaleEffect(expanded ? 1.22 : 0.78)
                                .rotationEffect(.degrees(alternate ? 180 : 0))
                                .offset(x: expanded ? 140 : 0)
                        }
                }

                HStack {
                    Text("slider target")
                        .frame(width: 120, alignment: .leading)

                    #if !os(tvOS)
                        Slider(value: $sliderValue.animation(animation), in: 0...1)
                            .frame(width: 220)
                    #endif

                    Color.pink
                        .frame(width: 42, height: 42)
                        .cornerRadius(8)
                        .scaleEffect(0.65 + sliderValue)
                        .rotationEffect(.degrees(sliderValue * 220))
                        .offset(x: sliderValue * 70)
                        .animation(animation, value: sliderValue)
                }
            }
        }
    }
}
