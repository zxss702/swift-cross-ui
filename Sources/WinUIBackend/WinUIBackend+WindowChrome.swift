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
    static var probeMenuCreates = 0
    /// The chrome strip's view-graph content lives in the top grid row, which
    /// is already sized to the system caption-button height.
    public func installWindowChrome(in window: Window) -> Widget? {
        window.chromeContainer
    }

    /// The leading-edge button that opens the application menu, rendered as
    /// the app icon like the Windows Settings app's header button.
    public func createAppMenuButton() -> Widget? {
        if ProcessInfo.processInfo.environment["SY_PROBE"] != nil {
            Self.probeMenuCreates += 1
            FileHandle.standardError.write(
                "[PROBE] createAppMenuButton #\(Self.probeMenuCreates)\n".data(using: .utf8)!)
        }
        let button = WinUI.Button()
        button.horizontalAlignment = .left
        button.verticalAlignment = .center
        button.minWidth = 32
        button.minHeight = 32
        button.padding = Thickness(left: 4, top: 2, right: 4, bottom: 2)
        let transparent = UWP.Color(a: 0, r: 0, g: 0, b: 0)
        let background = WinUI.SolidColorBrush()
        background.color = transparent
        button.background = background
        button.borderThickness = Thickness(left: 0, top: 0, right: 0, bottom: 0)

        // The stock `ButtonBackgroundPointerOver` theme resource is nearly
        // invisible on this app's cream chrome (≈4% black) — the transition
        // mid-frame reads as a "flash" and the settled state looks absent.
        // A slightly stronger overlay matches the Windows Settings header
        // button hover and actually persists while hovered.
        let hoverBrush = WinUI.SolidColorBrush()
        hoverBrush.color = UWP.Color(a: 0x1F, r: 0, g: 0, b: 0)
        let pressedBrush = WinUI.SolidColorBrush()
        pressedBrush.color = UWP.Color(a: 0x30, r: 0, g: 0, b: 0)
        let borderBrush = WinUI.SolidColorBrush()
        borderBrush.color = transparent
        _ = button.resources.insert("ButtonBackgroundPointerOver", hoverBrush)
        _ = button.resources.insert("ButtonBackgroundPressed", pressedBrush)
        _ = button.resources.insert("ButtonBorderBrushPointerOver", borderBrush)
        _ = button.resources.insert("ButtonBorderBrushPressed", borderBrush)

        guard let pixels = SwiftCrossUI.Image.assetPixels(named: "appIcon") else {
            preconditionFailure("appIcon asset is missing from the bundle")
        }
        // Temporary diagnostics: log pointer enter/exit to a file so a real
        // mouse hover reveals whether the pointer is being stolen or the
        // PointerOver visual is resetting on its own.
        func point(_ args: Any?) -> String {
            guard let args = args as? WinUI.PointerRoutedEventArgs,
                let pt = try? args.getCurrentPoint(nil)
            else { return "?" }
            return "\(pt.position.x),\(pt.position.y)"
        }
        button.pointerEntered.addHandler { _, args in
            Self.hoverLog("pointerEntered @\(point(args))")
        }
        button.pointerExited.addHandler { _, args in
            Self.hoverLog("pointerExited @\(point(args))")
        }
        button.pointerMoved.addHandler { _, _ in Self.hoverLog("pointerMoved") }
        button.gotFocus.addHandler { _, _ in Self.hoverLog("gotFocus") }
        button.lostFocus.addHandler { _, _ in Self.hoverLog("lostFocus") }
        let image = WinUI.Image()
        image.source = Self.writeableBitmap(
            rgbaData: pixels.bytes,
            width: pixels.width,
            height: pixels.height
        )
        image.width = 20
        image.height = 20
        image.stretch = .uniform
        button.content = image
        return button
    }

    public func attachAppMenuButton(_ widget: Widget, to window: Window) {
        guard let button = widget as? WinUI.Button else { return }
        // Commits re-run on every chrome relayout; re-assigning the same
        // button (and rebuilding the flyout) mid-hover resets the button's
        // PointerOver visual, producing a hover flash.
        guard window.appMenuButton !== button else { return }
        window.appMenuButton = button
        Self.hoverLog("attachMenu")
        applyApplicationMenu(to: window)
    }

    /// Temporary diagnostics: shared hover-log writer so pointer events and
    /// chrome operations land on one timeline in %TEMP%\sy_hover.log.
    static func hoverLog(_ msg: String) {
        let logPath = ProcessInfo.processInfo.environment["TEMP"]
            .map { $0 + "\\sy_hover.log" } ?? "C:\\Temp\\sy_hover.log"
        let line = "\(Date()) \(msg)\n"
        if let h = FileHandle(forWritingAtPath: logPath) {
            h.seekToEndOfFile()
            h.write(line.data(using: .utf8)!)
            try? h.close()
        } else {
            try? line.write(toFile: logPath, atomically: true, encoding: .utf8)
        }
    }

    /// A plain transparent element the window registers as its caption drag
    /// region via `setTitleBar`.
    public func createWindowDragRegion() -> Widget? {
        WinUI.Grid()
    }

    public func attachWindowDragRegion(_ widget: Widget, to window: Window) {
        guard window.dragElement !== widget else { return }
        window.dragElement = widget
        Self.hoverLog("attachDrag")
        // `setTitleBar` requires the element to be part of the loaded visual
        // tree; `loaded` covers both the initial attach and re-parenting.
        widget.loaded.addHandler { [weak window, weak widget] _, _ in
            guard let window, let widget, window.dragElement === widget else {
                return
            }
            try? window.setTitleBar(widget)
            Self.hoverLog("setTitleBar(loaded)")
        }
        if widget.isLoaded {
            try? window.setTitleBar(widget)
        }
        if ProcessInfo.processInfo.environment["SY_PROBE"] != nil {
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                let el = widget as? WinUI.FrameworkElement
                let canvas = window.chromeContainer
                let btn = window.appMenuButton
                let row0 = window.grid.rowDefinitions.getAt(0)?.actualHeight ?? -1
                FileHandle.standardError.write(
                    "[PROBE] drag w=\(el?.width ?? -1) h=\(el?.height ?? -1) aw=\(el?.actualWidth ?? -1) ah=\(el?.actualHeight ?? -1) left=\(WinUI.Canvas.getLeft(widget)) top=\(WinUI.Canvas.getTop(widget)) vis=\(widget.visibility) loaded=\(widget.isLoaded) | canvas aw=\(canvas.actualWidth) ah=\(canvas.actualHeight) | row0=\(row0) | btn top=\(WinUI.Canvas.getTop(btn!)) btnAh=\(btn?.actualHeight ?? -1) btnH=\(btn?.height ?? -1)\n".data(using: .utf8)!)
            }
        }
    }
}
