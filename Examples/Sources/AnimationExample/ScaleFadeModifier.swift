import SwiftCrossUI

struct ScaleFadeModifier: ViewModifier {
    var scale: Double
    var opacity: Double
    var offset: ViewSize

    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .opacity(opacity)
            .offset(offset)
    }
}
