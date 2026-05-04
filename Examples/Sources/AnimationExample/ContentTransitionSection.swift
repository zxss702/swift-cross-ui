import SwiftCrossUI

struct ContentTransitionSection: View {
    var animation: Animation
    @Binding var counter: Int

    @State private var sampleIndex = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Content transition")
                .font(.headline)

            HStack(spacing: 16) {
                Button("Increment") {
                    withAnimation(animation) {
                        counter += 1
                    }
                }

                Button("Decrement") {
                    withAnimation(animation) {
                        counter -= 1
                    }
                }

                Text("Value \(counter)")
                    .font(.title2)
                    .contentTransition(.numericText(value: Double(counter)))
                    .animation(animation, value: counter)
            }

            HStack(spacing: 10) {
                Text("opacity")
                    .contentTransition(.opacity)
                Text("interpolate")
                    .contentTransition(.interpolate)
                Text("identity")
                    .contentTransition(.identity)
            }
            .font(.caption)

            Button("New text") {
                withAnimation(animation) {
                    sampleIndex = (sampleIndex + 1) % contentTransitionSamples.count
                }
            }

            Text(contentTransitionSamples[sampleIndex])
                .contentTransition(.numericText(countsDown: true))
        }
    }
}

private let contentTransitionSamples = [
    "虚室生白光，凝眸透纸长",
    "灯前细核勘，笔下意彷徨",
    "潜心究脉络，抽绎理丝纲",
    "一灯穷暗室，半偈破迷方",
    "披阅经千遍，幽微始自彰",
]
