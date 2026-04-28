import DefaultBackend
import Foundation
import SwiftCrossUI

#if canImport(SwiftBundlerRuntime)
    import SwiftBundlerRuntime
#endif

enum AnimationPreset: String, CaseIterable, Equatable {
    case `default`
    case linear
    case easeIn
    case easeOut
    case easeInOut
    case spring
    case interactiveSpring
    case smooth
    case snappy
    case bouncy
    case delayed
    case fast
    case repeatCount
    case repeatForever

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
            case .spring:
                .spring(response: 0.55, dampingFraction: 0.65)
            case .interactiveSpring:
                .interactiveSpring(response: 0.25, dampingFraction: 0.72)
            case .smooth:
                .smooth
            case .snappy:
                .snappy
            case .bouncy:
                .bouncy
            case .delayed:
                .easeInOut(duration: 0.45).delay(0.25)
            case .fast:
                .easeInOut(duration: 0.8).speed(2)
            case .repeatCount:
                .linear(duration: 0.35).repeatCount(3, autoreverses: true)
            case .repeatForever:
                .easeInOut(duration: 0.7).repeatForever(autoreverses: true)
        }
    }
}

struct AnimationItem: Identifiable {
    let id = UUID()
    var label: String
}

@main
struct AnimationApp: App {
    @State var preset: AnimationPreset? = .snappy
    @State var expanded = false
    @State var visible = true
    @State var identity = 0
    @State var phase = false
    @State var items = [
        AnimationItem(label: "Alpha"),
        AnimationItem(label: "Beta"),
        AnimationItem(label: "Gamma"),
    ]
    @State var nextItem = 1

    var selectedAnimation: Animation {
        preset?.animation ?? .default
    }

    var body: some Scene {
        WindowGroup("AnimationExample") {
            ScrollView {
                VStack(spacing: 24) {
                    controls
                    propertyAnimationDemo
                    transitionDemo
                    identityDemo
                    listDemo
                }
                .padding()
                //                    .animation(selectedAnimation)
            }
            .frame(minHeight: 760)
        }
        .defaultSize(width: 560, height: 760)
    }

    var controls: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Animation")
                Picker(of: AnimationPreset.allCases, selection: $preset)
                    .pickerStyle(.menu)
            }
            HStack {
                Button("Toggle withAnimation") {
                    withAnimation(selectedAnimation) {
                        toggleAll()
                    }
                }
                Button("Interrupt") {
                    Task { @MainActor in
                        withAnimation(.linear(duration: 1.4)) {
                            phase.toggle()
                            expanded.toggle()
                        }
                        try? await Task.sleep(nanoseconds: 180_000_000)
                        withAnimation(.snappy) {
                            phase.toggle()
                            expanded.toggle()
                        }
                    }
                }
                Button("No animation") {
                    withAnimation(nil) {
                        toggleAll()
                    }
                }
            }
        }
    }

    var propertyAnimationDemo: some View {
        VStack(spacing: 12) {
            Text("Properties")
            HStack {
                Color.blue
                    .frame(width: expanded ? 180 : 72, height: expanded ? 72 : 180)
                    .cornerRadius(expanded ? 34 : 8)
                    .opacity(phase ? 0.35 : 1)
                    .scaleEffect(phase ? 0.75 : 1.15)
                    .offset(x: phase ? 70 : -20, y: 0)
                    .animation(selectedAnimation, value: expanded)
                    .animation(.easeInOut(duration: 0.35), value: phase)
                Color.pink
                    .frame(width: 64, height: 64)
                    .cornerRadius(32)
                    .offset(x: phase ? -50 : 40, y: expanded ? 34 : -20)
                    .animation(.spring(response: 0.45, dampingFraction: 0.55), value: phase)
            }
            HStack {
                Button("Shape") {
                    expanded.toggle()
                }
                Button("Opacity / offset") {
                    phase.toggle()
                }
            }
        }
    }

    var transitionDemo: some View {
        VStack(spacing: 12) {
            Text("Transition")
            HStack {
                if visible {
                    Color.green
                        .frame(width: 160, height: 80)
                        .cornerRadius(14)
                        .transition(
                            .asymmetric(
                                insertion: .scale.combined(with: .opacity),
                                removal: .move(edge: .trailing).combined(with: .opacity)
                            )
                        )
                }
            }
            .frame(height: 110)
            
            Button(visible ? "Remove" : "Insert") {
                withAnimation(selectedAnimation) {
                    visible.toggle()
                }
            }
        }
    }

    var identityDemo: some View {
        VStack(spacing: 12) {
            Text(".id()")
            Color.orange
                .frame(width: identity.isMultiple(of: 2) ? 120 : 180, height: 72)
                .cornerRadius(identity.isMultiple(of: 2) ? 10 : 36)
                .id(identity)
                .transition( .opacity)
            
            Button("Replace identity") {
                withAnimation(.bouncy) {
                    identity += 1
                }
            }
        }
    }

    var listDemo: some View {
        VStack(spacing: 12) {
            Text("ForEach")
            HStack {
                Button("Add") {
                    withAnimation(.snappy) {
                        items.insert(
                            AnimationItem(label: "New \(nextItem)"),
                            at: 0
                        )
                        nextItem += 1
                    }
                }
                Button("Remove") {
                    guard !items.isEmpty else {
                        return
                    }
                    withAnimation(.easeOut(duration: 0.45)) {
                        items.removeLast()
                    }
                }
                Button("Shuffle") {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                        items.shuffle()
                    }
                }
            }
            VStack(spacing: 8) {
                ForEach(items, id: \.id) { item in
                    HStack {
                        Color.cyan
                            .frame(width: 24, height: 24)
                            .cornerRadius(12)
                        Text(item.label)
                        Spacer()
                    }
                    .padding(8)
                    .frame(maxWidth: 260)
                    .transition(.offset(x: -80).combined(with: .opacity))
                }
            }
        }
    }

    func toggleAll() {
        expanded.toggle()
        visible.toggle()
        identity += 1
        phase.toggle()
        if !items.isEmpty {
            items.moveLastToFront()
        }
    }
}

extension Array {
    mutating func moveLastToFront() {
        guard let last = popLast() else {
            return
        }
        insert(last, at: startIndex)
    }
}
