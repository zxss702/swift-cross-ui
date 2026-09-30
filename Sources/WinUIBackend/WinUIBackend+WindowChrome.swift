@_spi(Backends) import SwiftCrossUI
import Foundation
import UWP
import WinAppSDK
import WindowsFoundation
import WinUI

// WinUI's integrated window chrome: a single title-bar row hosting the app
// menu button, navigation back button, title and toolbar items, with a
// dedicated drag region filling the remaining space. The chrome strip's view
// content is rendered by `WindowChromeBar` in a second view graph rooted in
// `CustomWindow.chromeContainer`.
extension WinUIBackend: BackendFeatures.WindowChrome {
    /// The chrome strip's view-graph content lives in the top grid row, which
    /// is already sized to the system caption-button height.
    public func installWindowChrome(in window: Window) -> Widget? {
        window.chromeContainer
    }

    /// The leading-edge button that opens the application menu, rendered as
    /// the app icon like the Windows Settings app's header button.
    public func createAppMenuButton() -> Widget? {
        let button = WinUI.Button()
        button.horizontalAlignment = .left
        button.verticalAlignment = .center
        button.minWidth = 28
        button.minHeight = 28
        button.padding = Thickness(left: 4, top: 2, right: 4, bottom: 2)
        let transparent = UWP.Color(a: 0, r: 0, g: 0, b: 0)
        let background = WinUI.SolidColorBrush()
        background.color = transparent
        button.background = background
        button.borderThickness = Thickness(left: 0, top: 0, right: 0, bottom: 0)

        if let pixels = SwiftCrossUI.Image.assetPixels(named: "appIcon") {
            let image = WinUI.Image()
            image.source = Self.writeableBitmap(
                rgbaData: pixels.bytes,
                width: pixels.width,
                height: pixels.height
            )
            image.width = 18
            image.height = 18
            image.stretch = .uniform
            button.content = image
        } else {
            let fallback = WinUI.TextBlock()
            fallback.text = "☰"
            button.content = fallback
        }
        return button
    }

    public func attachAppMenuButton(_ widget: Widget, to window: Window) {
        guard let button = widget as? WinUI.Button else { return }
        window.appMenuButton = button
        applyApplicationMenu(to: window)
    }

    /// A plain transparent element the window registers as its caption drag
    /// region via `setTitleBar`.
    public func createWindowDragRegion() -> Widget? {
        WinUI.Grid()
    }

    public func attachWindowDragRegion(_ widget: Widget, to window: Window) {
        guard window.dragElement !== widget else { return }
        window.dragElement = widget
        // `setTitleBar` requires the element to be part of the loaded visual
        // tree; `loaded` covers both the initial attach and re-parenting.
        widget.loaded.addHandler { [weak window, weak widget] _, _ in
            guard let window, let widget, window.dragElement === widget else {
                return
            }
            try? window.setTitleBar(widget)
        }
        if widget.isLoaded {
            try? window.setTitleBar(widget)
        }
    }
}
