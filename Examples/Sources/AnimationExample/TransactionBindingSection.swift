import SwiftCrossUI

struct TransactionBindingSection: View {
    var animation: Animation
    @Binding var bindingToggle: Bool
    @Binding var sliderValue: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Transaction and binding animation")
                .font(.headline)

            Text(
                """
                Toggle and slider writes carry their transaction through the \
                binding, matching SwiftUI's Binding.animation mental model.
                """
            )
            .font(.caption)

            HStack(spacing: 18) {
                Toggle(
                    "Binding.animation",
                    isOn: $bindingToggle.animation(animation)
                )
                .toggleStyle(.switch)

                Button("Transaction") {
                    var transaction = Transaction(animation: animation)
                    transaction.isContinuous = true
                    withTransaction(transaction) {
                        bindingToggle.toggle()
                        sliderValue = sliderValue < 0.5 ? 0.8 : 0.2
                    }
                }

                Button("No animation") {
                    var transaction = Transaction(animation: animation)
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        bindingToggle.toggle()
                        sliderValue = sliderValue < 0.5 ? 0.85 : 0.15
                    }
                }
            }

            HStack {
                Color.indigo
                    .frame(width: 76, height: 76)
                    .cornerRadius(8)
                    .scaleEffect(bindingToggle ? 1.25 : 0.75)
                    .opacity(bindingToggle ? 1 : 0.45)

                Color.mint
                    .frame(width: 76, height: 76)
                    .cornerRadius(8)
                    .rotationEffect(.degrees(bindingToggle ? 90 : -20))
                    .offset(x: sliderValue * 120)
            }
            .animation(animation, value: bindingToggle)
            .animation(animation, value: sliderValue)
        }
    }
}
