import Foundation
import SwiftCrossUI
import WinUI

extension WinUIBackend: BackendFeatures.Popovers {
    public func createPopover(content: Widget) -> WinUI.Flyout {
        let flyout = WinUI.Flyout()
        flyout.content = content as? WinUI.UIElement
        flyout.closed.addHandler { [weak internalState, weak flyout] _, _ in
            guard let internalState, let flyout else { return }
            internalState.popoverDismissActions.removeValue(
                forKey: ObjectIdentifier(flyout)
            )?()
        }
        return flyout
    }

    public func updatePopover(
        _ popover: WinUI.Flyout,
        content: Widget,
        environment: EnvironmentValues,
        onDismiss: @escaping () -> Void
    ) {
        if popover.content !== content {
            popover.content = content as? WinUI.UIElement
        }
        internalState.popoverDismissActions[ObjectIdentifier(popover)] = onDismiss
    }

    public func presentPopover(
        _ popover: WinUI.Flyout,
        relativeTo widget: Widget,
        arrowEdge: Edge?
    ) {
        // `arrowEdge` is the edge of the popover that its arrow sits on, so
        // the popover appears on the opposite side of the anchor.
        popover.placement =
            switch arrowEdge {
                case .top: .bottom
                case .bottom: .top
                case .leading: .right
                case .trailing: .left
                case nil: .bottomEdgeAlignedLeft
            }
        try? popover.showAt(widget)
    }

    public func dismissPopover(_ popover: WinUI.Flyout) {
        internalState.popoverDismissActions.removeValue(forKey: ObjectIdentifier(popover))
        try? popover.hide()
    }
}
