import SwiftCrossUI

struct IdentityResetProbe: View {
    var identity: Int

    var body: some View {
        ZStack {
            Color.gray.opacity(0.12)
                .frame(width: 180, height: 130)
                .cornerRadius(8)

            IdentityStateTile()
                .id(identity)
                .transition(
                    .scale(scale: 0.7)
                        .combined(with: .opacity)
                )
        }
    }
}
