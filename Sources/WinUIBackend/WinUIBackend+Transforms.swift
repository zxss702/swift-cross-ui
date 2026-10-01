@_spi(Backends) import SwiftCrossUI
@preconcurrency import WindowsFoundation
import WinUI

/// `rotationEffect` support: WinUI exposes `rotation` (degrees, clockwise)
/// and `centerPoint` (element-local pixels) on every UIElement, so any
/// FrameworkElement widget can be rotated directly. Backends without
/// conformance simply render the content unrotated.
extension WinUI.FrameworkElement: SCUIRotatable {
    public func setRotation(degrees: Double, anchor: UnitPoint) {
        rotation = Float(degrees)
        // CenterPoint is in element-local pixels; the layout system always
        // sets an explicit width/height on widgets before commit.
        centerPoint = WindowsFoundation.Vector3(
            x: Float(anchor.x * width),
            y: Float(anchor.y * height),
            z: 0
        )
    }
}
