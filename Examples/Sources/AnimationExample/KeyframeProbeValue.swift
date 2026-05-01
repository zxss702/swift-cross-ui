import SwiftCrossUI

struct KeyframeProbeValue: Animatable {
    var offset = 0.0
    var scale = 1.0
    var rotation = 0.0
    var opacity = 1.0

    var animatableData: AnimatablePair<
        AnimatablePair<Double, Double>,
        AnimatablePair<Double, Double>
    > {
        get {
            AnimatablePair(
                AnimatablePair(offset, scale),
                AnimatablePair(rotation, opacity)
            )
        }
        set {
            offset = newValue.first.first
            scale = newValue.first.second
            rotation = newValue.second.first
            opacity = newValue.second.second
        }
    }
}
