import Foundation

/// A view that renders window decorations (title bar, close/minimise/zoom
/// buttons) when the backend is in "chromeless" mode.
///
/// This is a structural stub; full styling will be added incrementally.
public struct WindowChromeView: View {
    let title: String
    let onClose: (() -> Void)?

    public var body: some View {
        HStack {
            if let onClose {
                Button("×") {
                    onClose()
                }
            }
            Text(title)
                .font(.headline)
            Spacer()
        }
        .padding()
        .background(Color.gray.opacity(0.15))
    }
}
