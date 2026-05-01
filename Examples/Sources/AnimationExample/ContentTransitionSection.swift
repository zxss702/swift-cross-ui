import SwiftCrossUI

struct ContentTransitionSection: View {
    var animation: Animation
    @Binding var counter: Int

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
        }
    }
}
