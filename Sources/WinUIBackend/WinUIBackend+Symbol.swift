@_spi(Backends) import SwiftCrossUI
import Foundation
import UWP
import WinAppSDK
import WindowsFoundation
import WinUI

// Renders system symbols as native icon-font glyphs — the FontIcon approach:
// a TextBlock with the Segoe Fluent Icons font family (Segoe MDL2 Assets as
// the automatic fallback on older Windows versions). Vector glyphs rasterize
// crisply at any size/scale and respect opacity, unlike bitmap stand-ins.
extension WinUIBackend: BackendFeatures.SymbolViews {
    /// The icon font family with its Windows 10 fallback, in XAML's
    /// comma-separated fallback-list syntax.
    private static let symbolFontSource = "Segoe Fluent Icons, Segoe MDL2 Assets"

    public func createSymbolView() -> Widget {
        let block = WinUI.TextBlock()
        block.fontFamily = WinUI.FontFamily(Self.symbolFontSource)
        // Segoe Fluent Icons ships a single regular weight; DirectWrite
        // synthesizes the semibold stroke, matching SF Symbols' medium
        // default weight on macOS.
        block.fontWeight = UWP.FontWeights.semiBold
        block.horizontalTextAlignment = .center
        block.verticalAlignment = .center
        block.isTextSelectionEnabled = false
        return block
    }

    public func updateSymbolView(
        _ symbolView: Widget,
        glyph: String,
        fontSize: Double,
        environment: EnvironmentValues
    ) {
        let block = symbolView as! WinUI.TextBlock
        // Guard every write: commits run per layout pass and XAML invalidates
        // on writes even when the assigned value is unchanged.
        if block.text != glyph {
            block.text = glyph
        }
        if block.fontSize != fontSize {
            block.fontSize = fontSize
        }
        if block.fontFamily?.source != Self.symbolFontSource {
            block.fontFamily = WinUI.FontFamily(Self.symbolFontSource)
        }
        let foregroundColor = environment.suggestedForegroundColor
            .resolve(in: environment).uwpColor
        if let brush = block.foreground as? SolidColorBrush, brush.color == foregroundColor {
        } else {
            block.foreground = environment.winUIForegroundBrush
        }
        let opacity = environment.isEnabled ? 1.0 : 0.36
        if block.opacity != opacity {
            block.opacity = opacity
        }
    }
}
