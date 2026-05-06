import SwiftCrossUI
import UWP
import WinUI

extension WinUIBackend: BackendFeatures.WindowToolbars {
    public func setToolbar(
        ofSurface surface: Surface,
        to resolvedToolbar: ResolvedToolbar,
        navigationTitle: String?,
        environment: EnvironmentValues
    ) {
        if let navigationTitle {
            surface.title = navigationTitle
        }

        surface.toolBar.primaryCommands.clear()
        surface.toolBar.secondaryCommands.clear()
        surface.toolBar.content = nil

        let isVisible = !resolvedToolbar.items.isEmpty
        surface.setToolbarVisible(isVisible)
        guard isVisible else {
            return
        }

        surface.toolBar.isOpen = false
        surface.toolBar.isDynamicOverflowEnabled = true

        let transparentBrush = SolidColorBrush()
        transparentBrush.color = UWP.Color(a: 0, r: 0, g: 0, b: 0)
        surface.toolBar.background = transparentBrush

        switch environment.colorScheme {
            case .light:
                surface.toolBar.requestedTheme = .light
            case .dark:
                surface.toolBar.requestedTheme = .dark
        }

        for item in resolvedToolbar.items {
            switch item.content {
                case .button(let label, let action):
                    let button = AppBarButton()
                    button.label = label
                    button.isEnabled = environment.isEnabled
                    button.click.addHandler { _, _ in
                        action()
                    }
                    append(button, placement: item.placement, to: surface.toolBar)
                case .text(let text):
                    let button = AppBarButton()
                    button.label = text
                    button.isEnabled = false
                    append(button, placement: item.placement, to: surface.toolBar)
                case .spacer:
                    break
                case .separator:
                    append(AppBarSeparator(), placement: item.placement, to: surface.toolBar)
            }
        }
    }

    private func append(
        _ item: ICommandBarElement,
        placement: ToolbarItemPlacement,
        to commandBar: CommandBar
    ) {
        switch placement {
            case .bottomBar:
                commandBar.secondaryCommands.append(item)
            case .automatic, .navigation, .principal, .primaryAction, .topBarLeading,
                .topBarTrailing:
                commandBar.primaryCommands.append(item)
        }
    }
}
