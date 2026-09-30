extension View {
    /// Sets the foreground color of the view.
    ///
    /// Equivalent to ``View/foregroundColor(_:)``.
    public func foregroundStyle(_ color: Color) -> some View {
        foregroundColor(color)
    }

    /// Sets the primary and secondary foreground styles of the view.
    ///
    /// The primary style is applied to the view's foreground; hierarchical
    /// secondary styling is consumed by symbol-aware backends.
    public func foregroundStyle<S1: ShapeStyle, S2: ShapeStyle>(
        _ primary: S1,
        _ secondary: S2
    ) -> some View {
        foregroundStyle(primary)
    }

    /// Sets the primary, secondary and tertiary foreground styles of the view.
    public func foregroundStyle<S1: ShapeStyle, S2: ShapeStyle, S3: ShapeStyle>(
        _ primary: S1,
        _ secondary: S2,
        _ tertiary: S3
    ) -> some View {
        foregroundStyle(primary)
    }
}

extension Image {
    /// Makes the image resizable while preserving its aspect ratio to fit
    /// the proposed size.
    @MainActor public func scaledToFit() -> some View {
        resizable().aspectRatio(contentMode: .fit)
    }

    /// Makes the image resizable while preserving its aspect ratio to fill
    /// the proposed size.
    @MainActor public func scaledToFill() -> some View {
        resizable().aspectRatio(contentMode: .fill)
    }
}

extension View {
    /// Scales this view to fit its parent while preserving its aspect ratio.
    ///
    /// Equivalent to `aspectRatio(contentMode: .fit)` in SwiftUI.
    public func scaledToFit() -> some View {
        aspectRatio(contentMode: .fit)
    }

    /// Scales this view to fill its parent while preserving its aspect
    /// ratio.
    ///
    /// Equivalent to `aspectRatio(contentMode: .fill)` in SwiftUI.
    public func scaledToFill() -> some View {
        aspectRatio(contentMode: .fill)
    }
}

/// Whether scroll indicators should be shown.
public enum ScrollIndicatorVisibility: Sendable {
    /// The system decides visibility based on content and platform.
    case automatic
    /// Indicators are always shown.
    case visible
    /// Indicators are always hidden.
    case hidden
    /// Indicators are shown only while scrolling.
    case never
}

extension View {
    /// Sets the visibility of scroll indicators for scroll views within
    /// this view.
    ///
    /// The preference is carried through the environment; scroll views read
    /// it when backend support lands.
    public func scrollIndicators(
        _ visibility: ScrollIndicatorVisibility,
        axes: Axis.Set = [.horizontal, .vertical]
    ) -> some View {
        environment(\.scrollIndicatorVisibility, visibility)
    }

    /// Disables scrolling for scroll views within this view.
    ///
    /// The preference is carried through the environment; scroll views read
    /// it when backend support lands.
    public func scrollDisabled(_ disabled: Bool) -> some View {
        environment(\.scrollDisabled, disabled)
    }

    /// Associates a layout with the scroll-target behavior of the enclosing
    /// scroll view.
    ///
    /// Scroll-targeting (paging) is not yet implemented; the modifier records
    /// the intent for future scroll-view support.
    public func scrollTargetLayout(isEnabled: Bool = true) -> some View {
        environment(\.scrollTargetLayoutEnabled, isEnabled)
    }
}
