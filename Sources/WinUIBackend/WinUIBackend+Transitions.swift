@_spi(Backends) import SwiftCrossUI
import Foundation
import UWP
import WinAppSDK
import WindowsFoundation
import WinUI

// WinUI's navigation transition: a container whose direct children play the
// platform's entrance transition when inserted and the removal transition
// when removed. `NavigationStack` hosts its visible page in one.
extension WinUIBackend: BackendFeatures.TransitionContainers {
    public func createTransitionContainer() -> Widget? {
        let canvas = WinUI.Canvas()
        let transitions = WinUI.TransitionCollection()
        transitions.append(WinUI.EntranceThemeTransition())
        canvas.childrenTransitions = transitions
        return canvas
    }
}
