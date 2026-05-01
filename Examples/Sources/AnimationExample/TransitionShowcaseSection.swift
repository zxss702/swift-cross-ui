import SwiftCrossUI

struct TransitionShowcaseSection: View {
    var animation: Animation
    @Binding var seed: Int

    @State private var showsPrimary = true
    @State private var showsCustom = true
    @State private var items = [
        TransitionItem(label: "A"),
        TransitionItem(label: "B"),
        TransitionItem(label: "C"),
    ]
    @State private var verticalItems = [
        TransitionItem(label: "1"),
        TransitionItem(label: "2"),
        TransitionItem(label: "3"),
    ]
    @State private var nextIndex = 4
    @State private var nextVerticalIndex = 4
    @State private var identitySeed = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Structural transitions")
                .font(.headline)

            Text(
                """
                Optional content and ForEach rows are kept alive as render \
                ghosts until their removal transition finishes.
                """
            )
            .font(.caption)

            HStack(spacing: 10) {
                Button("Toggle card") {
                    withAnimation(animation) {
                        showsPrimary.toggle()
                        seed += 1
                    }
                }

                Button("Toggle custom") {
                    withAnimation(animation) {
                        showsCustom.toggle()
                    }
                }

                Button("Append") {
                    withAnimation(animation) {
                        items.append(TransitionItem(label: "\(nextIndex)"))
                        nextIndex += 1
                    }
                }

                Button("Prepend") {
                    withAnimation(animation) {
                        items.insert(TransitionItem(label: "\(nextIndex)"), at: 0)
                        nextIndex += 1
                    }
                }

                Button("Remove first") {
                    guard !items.isEmpty else {
                        return
                    }
                    withAnimation(animation) {
                        _ = items.removeFirst()
                    }
                }

                Button("Remove last") {
                    guard !items.isEmpty else {
                        return
                    }
                    withAnimation(animation) {
                        _ = items.removeLast()
                    }
                }

                Button("Move") {
                    guard items.count > 1 else {
                        return
                    }
                    withAnimation(animation) {
                        let item = items.removeLast()
                        items.insert(item, at: 0)
                    }
                }
            }

            HStack(spacing: 10) {
                Button("V append") {
                    withAnimation(animation) {
                        verticalItems.append(
                            TransitionItem(label: "\(nextVerticalIndex)")
                        )
                        nextVerticalIndex += 1
                    }
                }

                Button("V prepend") {
                    withAnimation(animation) {
                        verticalItems.insert(
                            TransitionItem(label: "\(nextVerticalIndex)"),
                            at: 0
                        )
                        nextVerticalIndex += 1
                    }
                }

                Button("V remove first") {
                    guard !verticalItems.isEmpty else {
                        return
                    }
                    withAnimation(animation) {
                        _ = verticalItems.removeFirst()
                    }
                }

                Button("V remove last") {
                    guard !verticalItems.isEmpty else {
                        return
                    }
                    withAnimation(animation) {
                        _ = verticalItems.removeLast()
                    }
                }

                Button("Reset .id") {
                    withAnimation(animation) {
                        identitySeed += 1
                    }
                }
            }

            HStack(alignment: .top, spacing: 24) {
                optionalTransitionProbe
                customTransitionProbe
                IdentityResetProbe(identity: identitySeed)
            }

            HStack(alignment: .top, spacing: 20) {
                HStack(spacing: 10) {
                    ForEach(items, id: \.id) { item in
                        transitionTile(item)
                            .transition(
                                .push(from: .bottom)
                                    .combined(with: .opacity)
                                    .animation(animation)
                            )
                    }
                }
                .frame(height: 62, alignment: .leading)

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(verticalItems, id: \.id) { item in
                        transitionTile(item)
                            .transition(
                                .move(edge: .leading)
                                    .combined(with: .opacity)
                                    .animation(animation)
                            )
                    }
                }
                .frame(width: 64, alignment: .top)
            }
        }
    }

    private func transitionTile(_ item: TransitionItem) -> some View {
        Text(item.label)
            .font(.headline)
            .foregroundColor(.white)
            .frame(width: 42, height: 42)
            .background(Color.blue)
            .cornerRadius(8)
    }

    private var optionalTransitionProbe: some View {
        ZStack {
            Color.gray.opacity(0.12)
                .frame(width: 230, height: 130)
                .cornerRadius(8)

            if showsPrimary {
                VStack(spacing: 8) {
                    Text("asymmetric")
                        .font(.caption)
                    Color.orange
                        .frame(width: 120, height: 58)
                        .cornerRadius(8)
                }
                .transition(
                    .asymmetric(
                        insertion: .move(edge: .leading)
                            .combined(with: .opacity),
                        removal: .scale(scale: 0.55)
                            .combined(with: .opacity)
                    )
                    .animation(animation)
                )
            }
        }
    }

    private var customTransitionProbe: some View {
        ZStack {
            Color.gray.opacity(0.12)
                .frame(width: 230, height: 130)
                .cornerRadius(8)

            if showsCustom {
                VStack(spacing: 8) {
                    Text("custom")
                        .font(.caption)
                    Color.teal
                        .frame(width: 120, height: 58)
                        .cornerRadius(8)
                }
                .transition(
                    AnyTransition(PivotTransition())
                        .combined(
                            with: .modifier(
                                active: ScaleFadeModifier(
                                    scale: 0.4,
                                    opacity: 0,
                                    offset: ViewSize(0, 34)
                                ),
                                identity: ScaleFadeModifier(
                                    scale: 1,
                                    opacity: 1,
                                    offset: .zero
                                )
                            )
                        )
                        .animation(animation)
                )
            }
        }
    }
}
