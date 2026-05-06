/// A simple navigation bar view for use in the fallback navigation stack
/// implementation.
public struct NavigationBar: View {
    /// The title displayed in the center of the navigation bar.
    let title: String?
    /// An action to perform when the back button is tapped. If `nil`, no back
    /// button is shown.
    let onBack: (() -> Void)?

    /// Creates a navigation bar.
    /// - Parameters:
    ///   - title: The title to display.
    ///   - onBack: The back action, if any.
    public init(
        title: String?,
        onBack: (() -> Void)?
    ) {
        self.title = title
        self.onBack = onBack
    }

    public var body: some View {
        HStack {
            if let onBack {
                Text("‹ Back")
                    .onTapGesture(perform: onBack)
            }
            Spacer()
            if let title {
                Text(title)
                    .font(.headline)
            }
            Spacer()
            if onBack != nil {
                Spacer().frame(width: 60)
            }
        }
        .padding(8)
        .background(Color.gray.opacity(0.1))
    }
}
