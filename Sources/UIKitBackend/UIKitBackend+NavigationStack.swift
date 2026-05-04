import SwiftCrossUI
import UIKit

final class NavigationStackWidget: WrapperControllerWidget<UINavigationController>,
    UINavigationControllerDelegate
{
    private var pageControllers: [NavigationPageController] = []
    private var isUpdatingPages = false
    private var onPopToPage: (@MainActor (Int) -> Void)?

    init() {
        super.init(child: UINavigationController())
        child.delegate = self
    }

    func setPages(
        _ pages: [NavigationStackPage<any WidgetProtocol>],
        environment: EnvironmentValues,
        onPopToPage: @escaping @MainActor (Int) -> Void
    ) {
        self.onPopToPage = onPopToPage

        let oldControllers = pageControllers
        let newControllers = pages.map { page in
            let controller =
                oldControllers.first { ($0.child as AnyObject) === (page.widget as AnyObject) }
                ?? NavigationPageController(child: page.widget)
            controller.apply(page: page, environment: environment)
            controller.parentWidget = self
            return controller
        }

        for oldController in oldControllers where !newControllers.contains(where: { $0 === oldController }) {
            oldController.parentWidget = nil
        }

        pageControllers = newControllers
        childWidgets = newControllers

        let oldViewControllers = child.viewControllers
        let hasChanged =
            oldViewControllers.count != newControllers.count
            || zip(oldViewControllers, newControllers).contains { old, new in
                old !== new
            }

        if hasChanged {
            isUpdatingPages = true
            child.setViewControllers(
                newControllers,
                animated: newControllers.count > oldViewControllers.count && child.view.window != nil
            )
            isUpdatingPages = false
        }

        let hasBottomToolbar = pages.last?.toolbar.items.contains {
            $0.placement == .bottomBar
        } ?? false
        child.setToolbarHidden(!hasBottomToolbar, animated: false)
    }

    func navigationController(
        _ navigationController: UINavigationController,
        didShow viewController: UIViewController,
        animated: Bool
    ) {
        guard !isUpdatingPages else {
            return
        }
        guard let pageIndex = pageControllers.firstIndex(where: { $0 === viewController }) else {
            return
        }
        guard pageIndex < pageControllers.count - 1 else {
            return
        }

        pageControllers = Array(pageControllers.prefix(pageIndex + 1))
        childWidgets = pageControllers
        onPopToPage?(pageIndex)
    }
}

final class NavigationPageController: ContainerWidget {
    private var toolbarActions: [NavigationToolbarAction] = []

    override func viewDidLoad() {
        super.viewDidLoad()

        NSLayoutConstraint.activate([
            view.leadingAnchor.constraint(equalTo: child.view.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: child.view.trailingAnchor),
            view.topAnchor.constraint(equalTo: child.view.topAnchor),
            view.bottomAnchor.constraint(equalTo: child.view.bottomAnchor),
        ])
    }

    func apply(
        page: NavigationStackPage<any WidgetProtocol>,
        environment: EnvironmentValues
    ) {
        title = page.navigationTitle
        navigationItem.title = page.navigationTitle
        toolbarActions = []

        navigationItem.leftBarButtonItems = toolbarItems(
            from: page.toolbar,
            placements: [.navigation, .topBarLeading],
            environment: environment
        )
        navigationItem.rightBarButtonItems = toolbarItems(
            from: page.toolbar,
            placements: [.automatic, .primaryAction, .topBarTrailing],
            environment: environment
        )
        navigationItem.titleView = principalItem(
            from: page.toolbar,
            environment: environment
        )
        toolbarItems = toolbarItems(
            from: page.toolbar,
            placements: [.bottomBar],
            environment: environment
        )
    }

    private func toolbarItems(
        from toolbar: ResolvedToolbar,
        placements: Set<ToolbarItemPlacement>,
        environment: EnvironmentValues
    ) -> [UIBarButtonItem] {
        toolbar.items
            .filter { placements.contains($0.placement) }
            .map { toolbarItem($0, environment: environment) }
    }

    private func toolbarItem(
        _ item: ResolvedToolbarItem,
        environment: EnvironmentValues
    ) -> UIBarButtonItem {
        switch item.content {
            case .button(let label, let action):
                let action = NavigationToolbarAction(action)
                toolbarActions.append(action)
                return UIBarButtonItem(
                    title: label,
                    style: .plain,
                    target: action,
                    action: #selector(action.run)
                )
            case .spacer(let minLength):
                if let minLength {
                    return .fixedSpace(CGFloat(minLength))
                } else {
                    return .flexibleSpace()
                }
            case .separator:
                return .fixedSpace(8)
        }
    }

    private func principalItem(
        from toolbar: ResolvedToolbar,
        environment: EnvironmentValues
    ) -> UIView? {
        guard let principal = toolbar.items.first(where: { $0.placement == .principal }) else {
            return nil
        }

        switch principal.content {
            case .button(let label, let action):
                let action = NavigationToolbarAction(action)
                toolbarActions.append(action)
                let button = UIButton(type: .system)
                button.setTitle(label, for: .normal)
                button.addTarget(action, action: #selector(action.run), for: .touchUpInside)
                return button
            case .spacer, .separator:
                return nil
        }
    }
}

@MainActor
final class NavigationToolbarAction: NSObject {
    private let action: @MainActor @Sendable () -> Void

    init(_ action: @escaping @MainActor @Sendable () -> Void) {
        self.action = action
    }

    @objc func run() {
        action()
    }
}

extension UIKitBackend: BackendFeatures.NavigationStacks {
    public func createNavigationStack() -> Widget {
        NavigationStackWidget()
    }

    public func setNavigationStackPages(
        of navigationStack: Widget,
        to pages: [NavigationStackPage<Widget>],
        environment: EnvironmentValues,
        onPopToPage: @escaping @MainActor (Int) -> Void
    ) {
        let navigationStack = navigationStack as! NavigationStackWidget
        navigationStack.setPages(
            pages,
            environment: environment,
            onPopToPage: onPopToPage
        )
    }
}
