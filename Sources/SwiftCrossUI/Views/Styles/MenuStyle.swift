/// The visibility of the drop-down indicator of a menu button.
public enum MenuIndicatorVisibility: Sendable, Hashable {
    /// The system decides whether to show the indicator.
    case automatic
    /// Always show the indicator.
    case visible
    /// Never show the indicator.
    case hidden
}

/// When the actions of a menu are dismissed.
public enum MenuActionDismissBehavior: Sendable, Hashable {
    /// Dismiss the menu after an action completes.
    case automatic
    /// Keep the menu open after an action completes.
    case disabled
}

extension EnvironmentValues {
    /// The visibility of the menu drop-down indicator. Recorded for backends.
    @Entry public var menuIndicator: MenuIndicatorVisibility? = nil
    /// When menu actions dismiss the menu. Recorded for backends.
    @Entry public var menuActionDismissBehavior: MenuActionDismissBehavior = .automatic
}

extension View {
    /// Sets the visibility of the drop-down indicator for menus.
    public func menuIndicator(_ visibility: MenuIndicatorVisibility) -> some View {
        EnvironmentModifier(self) { environment in
            environment.with(\.menuIndicator, visibility)
        }
    }

    /// Sets whether menu actions dismiss the menu.
    public func menuActionDismissBehavior(_ behavior: MenuActionDismissBehavior) -> some View {
        EnvironmentModifier(self) { environment in
            environment.with(\.menuActionDismissBehavior, behavior)
        }
    }
}
