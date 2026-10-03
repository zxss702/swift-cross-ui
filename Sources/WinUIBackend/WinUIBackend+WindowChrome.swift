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
        applyApplicationMenu(to: window)
    }

    /// The back button shown while navigation can pop, styled after WinUI's
    /// `NavigationBackButtonNormalStyle` (the `NavigationView` back button):
    /// transparent chrome with a subtle-fill hover pill, 4pt corner radius,
    /// and the Segoe Fluent Icons "Back" glyph (U+E72B) at 16pt. The stock
    /// template's `AnimatedIcon` isn't exposed in the projection, so the
    /// static glyph stands in for it.
    public func createNavigationBackButton() -> Widget? {
        NavigationBackButton()
    }

    public func updateNavigationBackButton(
        _ widget: Widget,
        action: (@MainActor () -> Void)?,
        environment: EnvironmentValues
    ) {
        guard let button = widget as? NavigationBackButton else { return }
        button.action = action
        button.glyph.foreground = environment.winUIForegroundBrush
        button.requestedTheme =
            switch environment.colorScheme {
                case .light: .light
                case .dark: .dark
            }
        button.isEnabled = environment.isEnabled
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

/// A title-bar back button replicating the visuals of WinUI's
/// `NavigationBackButtonNormalStyle` (square, Segoe Fluent Icons \u{E72B}
/// glyph at 16pt, transparent chrome with a subtle-fill hover pill and the
/// standard control corner radius). The stock template animates its
/// `AnimatedIcon` on press — since that control isn't projected, the glyph
/// gets an equivalent scale-down/spring-back animation instead.
final class NavigationBackButton: WinUI.Button {
    var action: (@MainActor () -> Void)?
    let glyph = WinUI.TextBlock()
    private let glyphScale = WinUI.CompositeTransform()
    private var pressStoryboard: WinUI.Storyboard?

    override init() {
        super.init()

        padding = Thickness(left: 0, top: 0, right: 0, bottom: 0)
        minWidth = 40
        minHeight = 40
        horizontalContentAlignment = .center
        verticalContentAlignment = .center
        cornerRadius = CornerRadius(topLeft: 4, topRight: 4, bottomRight: 4, bottomLeft: 4)

        glyph.text = "\u{E72B}"
        glyph.fontFamily = WinUI.FontFamily("Segoe Fluent Icons, Segoe MDL2 Assets")
        glyph.fontSize = 16
        glyph.fontWeight = UWP.FontWeights.normal
        glyph.horizontalTextAlignment = .center
        // Measure to the glyph's ink bounds so the arrow centres optically.
        glyph.textLineBounds = .tight
        glyph.isTextSelectionEnabled = false
        // Normalized origin scales the glyph around its own centre.
        glyph.renderTransformOrigin = WindowsFoundation.Point(x: 0.5, y: 0.5)
        glyph.renderTransform = glyphScale
        content = glyph

        // Transparent chrome with a subtle-fill hover/pressed pill — the same
        // recipe the app-menu button uses (tuned for this chrome's tone).
        let transparent = WinUI.SolidColorBrush()
        transparent.color = UWP.Color(a: 0, r: 0, g: 0, b: 0)
        background = transparent
        borderBrush = transparent
        borderThickness = Thickness(left: 0, top: 0, right: 0, bottom: 0)
        let hover = WinUI.SolidColorBrush()
        hover.color = UWP.Color(a: 0x1F, r: 0, g: 0, b: 0)
        let pressed = WinUI.SolidColorBrush()
        pressed.color = UWP.Color(a: 0x30, r: 0, g: 0, b: 0)
        _ = resources.insert("ButtonBackgroundPointerOver", hover)
        _ = resources.insert("ButtonBackgroundPressed", pressed)
        _ = resources.insert("ButtonBorderBrushPointerOver", transparent)
        _ = resources.insert("ButtonBorderBrushPressed", transparent)

        AutomationProperties.setName(self, "Back")
        let tooltip = WinUI.ToolTip()
        tooltip.content = "Back"
        ToolTipService.setToolTip(self, tooltip)

        click.addHandler { [weak self] _, _ in
            guard let action = self?.action else { return }
            MainActor.assumeIsolated(action)
        }

        // The system back button's AnimatedIcon squashes the arrow on press
        // and springs it back on release; approximate with a transform
        // animation on the glyph.
        pointerPressed.addHandler { [weak self] _, _ in
            self?.animateGlyphScale(to: 0.75, milliseconds: 90, springBack: false)
        }
        pointerReleased.addHandler { [weak self] _, _ in
            self?.animateGlyphScale(to: 1.0, milliseconds: 320, springBack: true)
        }
        pointerExited.addHandler { [weak self] _, _ in
            self?.animateGlyphScale(to: 1.0, milliseconds: 320, springBack: true)
        }
        pointerCaptureLost.addHandler { [weak self] _, _ in
            self?.animateGlyphScale(to: 1.0, milliseconds: 320, springBack: true)
        }
    }

    /// Animates the glyph's scale toward `scale`. On release a gentle
    /// `BackEase` overshoots slightly, matching the system's springy feel.
    private func animateGlyphScale(
        to scale: Double,
        milliseconds: Double,
        springBack: Bool
    ) {
        let storyboard = WinUI.Storyboard()
        for property in ["ScaleX", "ScaleY"] {
            let animation = WinUI.DoubleAnimation()
            animation.to = scale
            animation.duration = WinUI.Duration(
                timeSpan: WindowsFoundation.TimeSpan(
                    duration: Int64(milliseconds * 10_000)),
                type: .init(1))  // DurationType.TimeSpan
            animation.enableDependentAnimation = true
            if springBack {
                let ease = WinUI.BackEase()
                ease.amplitude = 0.5
                animation.easingFunction = ease
            }
            WinUI.Storyboard.setTarget(animation, glyphScale)
            WinUI.Storyboard.setTargetProperty(animation, property)
            storyboard.children.append(animation)
        }
        // Keep a strong reference until a newer animation replaces it —
        // releasing the storyboard mid-flight cancels it.
        pressStoryboard = storyboard
        try? storyboard.begin()
    }
}
