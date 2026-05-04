extension BackendFeatures {
    /// Backend methods for view effects such as opacity, transforms, blur, and z-ordering.
    @MainActor
    public protocol ViewEffects: Widgets {
        /// Sets a widget's opacity to the current frame value.
        func setOpacity(of widget: Widget, to opacity: Double)

        /// Sets a widget's transform to the current frame value.
        func setTransform(of widget: Widget, to transform: AffineTransform)

        /// Sets a widget's blur radius to the current frame value.
        func setBlur(of widget: Widget, radius: Double)

        /// Sets a widget's visibility to the current frame value.
        func setVisibility(of widget: Widget, visible: Bool)

        /// Sets a widget's z-index to the current frame value.
        func setZIndex(of widget: Widget, to zIndex: Double)
    }
}

// MARK: Default Implementations

extension BackendFeatures.ViewEffects {
    public func setOpacity(of widget: Widget, to opacity: Double) {}

    public func setTransform(of widget: Widget, to transform: AffineTransform) {}

    public func setBlur(of widget: Widget, radius: Double) {}

    public func setVisibility(of widget: Widget, visible: Bool) {}

    public func setZIndex(of widget: Widget, to zIndex: Double) {}
}
