/// A button that shows a popover menu when clicked.
///
/// Due to technical limitations, the minimum supported OS's for menu buttons in
/// UIKitBackend are iOS 14 and tvOS 17.
public struct Menu {
    /// The menu's label.
    public var label: String
    /// The menu's items.
    public var items: [MenuItem]

    /// A custom view label, when created via ``init(content:label:)``.
    var labelContent: (() -> AnyView)?

    var buttonWidth: Int?

    /// Creates a menu.
    ///
    /// - Parameters:
    ///   - label: The menu's label.
    ///   - items: The menu's items.
    @MainActor
    public init(_ label: String, @ViewBuilder items: () -> some View) {
        self.label = label
        self.items = items()._asMenuItems
        self.labelContent = nil
    }

    /// Creates a menu with a custom view label.
    ///
    /// - Parameters:
    ///   - content: The menu's items.
    ///   - label: The menu's label.
    @MainActor
    public init<Content: View, Label: View>(
        @ViewBuilder content: () -> Content,
        @ViewBuilder label: () -> Label
    ) {
        let labelView = label()
        // Preserve the label's title text so that contexts which can't host a
        // view label (such as a submenu in a context menu) still get a
        // meaningful name.
        self.label = (labelView as? SwiftCrossUI.Label<Text, Image>)?.title.string ?? ""
        self.items = content()._asMenuItems
        self.labelContent = { AnyView(labelView) }
    }

    /// Resolves the menu to a representation used by backends.
    @MainActor
    func resolve() -> ResolvedMenu.Submenu {
        ResolvedMenu.Submenu(
            label: label,
            content: Self.resolve(items: items)
        )
    }

    @MainActor
    static func resolve(item: MenuItem) -> ResolvedMenu.Item {
        switch item {
            case .button(let button):
                .button(button.body.view0.view0.string, button.action)
            case .text(let text):
                .button(text.string, nil)
            case .toggle(let toggle):
                .toggle(
                    toggle.label,
                    toggle.active.wrappedValue,
                    onChange: { toggle.active.wrappedValue = $0 }
                )
            case .separator:
                .separator
            case .submenu(let submenu):
                .submenu(submenu.resolve())
            case .modifiedEnvironment(let item, let modification):
                .modifiedEnvironment(resolve(item: item()), modification())
        }
    }

    /// Resolves the menu's items to a representation used by backends.
    @MainActor
    static func resolve(items: [MenuItem]) -> ResolvedMenu {
        ResolvedMenu(items: items.map(resolve(item:)))
    }
}

@available(iOS 14, macCatalyst 14, tvOS 17, *)
extension Menu: TypeSafeView {
    public var body: EmptyView { return EmptyView() }

    public var _asMenuItems: [MenuItem] { [.submenu(self)] }

    func children<Backend: BaseAppBackend>(
        backend: Backend,
        snapshots: [ViewGraphSnapshotter.NodeSnapshot]?,
        environment: EnvironmentValues
    ) -> Children {
        let storage = MenuStorage()
        if let labelContent {
            storage.labelChildren = TupleViewChildren1(
                labelContent(),
                backend: backend,
                snapshots: nil,
                environment: environment
            )
        }
        return storage
    }

    func asWidget<Backend: BaseAppBackend>(
        _ children: MenuStorage,
        backend: Backend
    ) -> Backend.Widget {
        if let labelChildren = children.labelChildren {
            return backend.createButton(wrapping: labelChildren.child0.widget.into())
        }
        return backend.createSimpleButton()
    }

    func layoutableChildren<Backend: BaseAppBackend>(
        backend: Backend,
        children: MenuStorage
    ) -> [LayoutSystem.LayoutableChild] {
        []
    }

    @CastBackend<BackendFeatures.MenuButtons>(backendGenericName: "NewBackend")
    func computeLayout<Backend: BaseAppBackend>(
        _ widget: Backend.Widget,
        children: MenuStorage,
        proposedSize: ProposedViewSize,
        environment: EnvironmentValues,
        backend: Backend
    ) -> ViewLayoutResult {
        // TODO: Look into ways to predict a button's natural size without
        //   updating its content so that computeLayout can be a bit more of
        //   a pure function.

        if let labelChildren = children.labelChildren {
            let buttonPadding = backend.buttonPadding(in: environment)
            let childEnvironment = backend.computeButtonLabelEnvironment(from: environment)
            let childResult = labelChildren.child0.computeLayout(
                with: labelContent!(),
                proposedSize: proposedSize,
                environment: childEnvironment
            )
            backend.updateButton(widget, environment: environment, action: {})
            // Keep the size as Double so an infinite probe result propagates as
            // .infinity instead of clamping to Int32.max (see `Button.computeLayout`).
            let size = ViewSize(
                childResult.size.width + Double(buttonPadding.x),
                childResult.size.height + Double(buttonPadding.y)
            )
            switch backend.menuImplementationStyle {
                case .menuButton(let backend):
                    let menu =
                        children.menu.flatMap { $0 as? NewBackend.Menu }
                            ?? backend.createPopoverMenu()
                    children.menu = menu
                    backend.setButtonMenu(widget, menu: menu, environment: environment)
                case .dynamicPopover:
                    break
            }
            return ViewLayoutResult
                .leafView(size: size)
                .with(\.isNeverFocusable, false)
        }

        // Update the button before measuring its natural size
        switch backend.menuImplementationStyle {
            case .dynamicPopover(let backend):
                // Our menu button action implementation needs to know the size
                // of the button, but we don't have that yet, so just update it
                // with an empty action and fix it in commit.
                backend.updateSimpleButton(
                    widget,
                    label: label,
                    environment: environment,
                    action: {}
                )
            case .menuButton(let backend):
                let menu =
                    children.menu.flatMap { $0 as? NewBackend.Menu }
                        ?? backend.createPopoverMenu()
                children.menu = menu
                backend.updateButton(
                    widget,
                    label: label,
                    menu: menu,
                    environment: environment
                )
        }

        var size = backend.naturalSize(of: widget)
        size.x = buttonWidth ?? size.x
        return ViewLayoutResult
            .leafView(size: ViewSize(size))
            .with(\.isNeverFocusable, false)
    }

    @CastBackend<BackendFeatures.MenuButtons>(backendGenericName: "NewBackend")
    func commit<Backend: BaseAppBackend>(
        _ widget: Backend.Widget,
        children: MenuStorage,
        layout: ViewLayoutResult,
        environment: EnvironmentValues,
        backend: Backend
    ) {
        let size = layout.size
        backend.setSize(of: widget, to: size.vector)

        if let labelChildren = children.labelChildren {
            _ = labelChildren.child0.commit()
            switch backend.menuImplementationStyle {
                case .dynamicPopover(let backend):
                    backend.updateButton(
                        widget,
                        environment: environment,
                        action: {
                            let content = resolve().content
                            let menu = backend.createPopoverMenu()
                            children.menu = menu
                            backend.updatePopoverMenu(
                                menu,
                                content: content,
                                environment: environment
                            )
                            backend.showPopoverMenu(
                                menu,
                                at: SIMD2(0, LayoutSystem.roundSize(size.height) + 2),
                                relativeTo: widget
                            ) {
                                children.menu = nil
                            }
                        }
                    )
                case .menuButton(let backend):
                    let content = resolve().content
                    let menu =
                        (children.menu as? NewBackend.Menu) ?? backend.createPopoverMenu()
                    children.menu = menu
                    backend.updatePopoverMenu(
                        menu,
                        content: content,
                        environment: environment
                    )
                    backend.setButtonMenu(widget, menu: menu, environment: environment)
            }
            return
        }

        switch backend.menuImplementationStyle {
            case .dynamicPopover(let backend):
                backend.updateSimpleButton(
                    widget,
                    label: label,
                    environment: environment,
                    action: {
                        let content = resolve().content
                        let menu = backend.createPopoverMenu()
                        children.menu = menu
                        backend.updatePopoverMenu(
                            menu,
                            content: content,
                            environment: environment
                        )
                        backend.showPopoverMenu(
                            menu,
                            at: SIMD2(0, LayoutSystem.roundSize(size.height) + 2),
                            relativeTo: widget
                        ) {
                            children.menu = nil
                        }
                    }
                )

                if let menu = children.menu {
                    let content = resolve().content
                    backend.updatePopoverMenu(
                        menu as! NewBackend.Menu,
                        content: content,
                        environment: environment
                    )
                }
            case .menuButton(let backend):
                // We can assume that computeLayout has already run, so children.menu
                // will already be correctly initialized.
                let content = resolve().content
                let menu = children.menu! as! NewBackend.Menu
                backend.updatePopoverMenu(
                    menu,
                    content: content,
                    environment: environment
                )

                // Even though we update the button in computeLayout (in order
                // for naturalSize to work), we appear to have to update it again
                // in commit; otherwise UIKitBackend users get menu buttons that
                // aren't poppable until the second time that the view gets updated.
                // They also get menu button menus with toggles that only toggle every
                // second time. I'm not sure why any of that happens.
                // TODO: Investigate why the following is needed. It may point us to
                //   some layout system/state management issues.
                backend.updateButton(
                    widget,
                    label: label,
                    menu: menu,
                    environment: environment
                )
        }
    }

    /// A temporary button width solution until arbitrary labels are supported.
    public func _buttonWidth(_ width: Int?) -> Menu {
        var menu = self
        menu.buttonWidth = width
        return menu
    }
}

class MenuStorage: ViewGraphNodeChildren {
    var menu: Any?
    var labelChildren: TupleViewChildren1<AnyView>?

    var widgets: [AnyWidget] {
        labelChildren?.widgets ?? []
    }
    var erasedNodes: [ErasedViewGraphNode] {
        labelChildren?.erasedNodes ?? []
    }

    init() {}
}
