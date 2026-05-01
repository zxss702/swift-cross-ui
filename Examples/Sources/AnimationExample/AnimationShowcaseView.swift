import SwiftCrossUI

struct AnimationShowcaseView: View {
    @State private var selectedPreset: AnimationPreset? = .smooth
    @State private var expanded = false
    @State private var alternate = false
    @State private var sliderValue = 0.25
    @State private var bindingToggle = false
    @State private var transitionSeed = 0
    @State private var phaseTrigger = 0
    @State private var keyframeTrigger = 0
    @State private var contentCounter = 0
    @State private var completionRuns = 0

    private var activeAnimation: Animation {
        selectedPreset?.animation ?? .default
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("AnimationExample")
                        .font(.title)
                    Text(
                        """
                        A broad smoke-test for SwiftUI-style animation APIs, \
                        transactions, binding animation, phases, keyframes, \
                        content transitions, and structural transitions.
                        """
                    )
                    .font(.callout)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Animation preset")
                        .font(.headline)

                    HStack {
                        Picker(
                            of: AnimationPreset.allCases,
                            selection: $selectedPreset
                        )
                        .pickerStyle(.menu)

                        Button("withAnimation") {
                            runPrimaryAnimation()
                        }

                        Button("Completion") {
                            runCompletionAnimation()
                        }

                        Button("Disable once") {
                            runWithoutAnimation()
                        }
                    }

                    Text("Completion callbacks observed: \(completionRuns)")
                        .font(.caption)
                }

                AnimationTrackSection(
                    animation: activeAnimation,
                    expanded: $expanded,
                    alternate: $alternate,
                    sliderValue: $sliderValue
                )

                TransactionBindingSection(
                    animation: activeAnimation,
                    bindingToggle: $bindingToggle,
                    sliderValue: $sliderValue
                )

                ContentTransitionSection(
                    animation: activeAnimation,
                    counter: $contentCounter
                )

                TimelineShowcaseSection(
                    animation: activeAnimation,
                    phaseTrigger: $phaseTrigger,
                    keyframeTrigger: $keyframeTrigger
                )

                TransitionShowcaseSection(
                    animation: activeAnimation,
                    seed: $transitionSeed
                )
            }
            .padding()
        }
    }

    private func runPrimaryAnimation() {
        withAnimation(activeAnimation) {
            expanded.toggle()
            alternate.toggle()
            sliderValue = sliderValue < 0.5 ? 0.9 : 0.2
            transitionSeed += 1
            phaseTrigger += 1
            keyframeTrigger += 1
            contentCounter += 1
        }
    }

    private func runCompletionAnimation() {
        withAnimation(
            activeAnimation,
            completionCriteria: .logicallyComplete
        ) {
            expanded.toggle()
            alternate.toggle()
            contentCounter += 1
        } completion: {
            Task { @MainActor in
                completionRuns += 1
            }
        }
    }

    private func runWithoutAnimation() {
        var transaction = Transaction(animation: activeAnimation)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            expanded.toggle()
            alternate.toggle()
            sliderValue = sliderValue < 0.5 ? 0.85 : 0.15
            contentCounter += 1
        }
    }
}
