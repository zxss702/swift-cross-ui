import SwiftCrossUI

struct IdentityStateTile: View {
    @State private var count = 0

    var body: some View {
        VStack(spacing: 8) {
            Text(".id()")
                .font(.caption)
            Button("Count \(count)") {
                count += 1
            }
        }
        .frame(width: 120, height: 58)
        .background(Color.purple)
        .foregroundColor(.white)
        .cornerRadius(8)
    }
}
