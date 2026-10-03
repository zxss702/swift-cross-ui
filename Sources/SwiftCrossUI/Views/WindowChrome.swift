import Foundation

extension BackendFeatures {
    /// Backend hooks that let a window host its chrome strip (application
    /// menu, back button, title, toolbar items) inside the title-bar area,
    /// like modern single-row Windows title bars.
    ///
    /// When a backend conforms to this protocol and
    /// ``installWindowChrome(in:)`` returns a container, ``WindowReference``
    /// renders ``WindowChromeBar`` into that container as a second view graph
    /// and exposes a ``WindowChromeModel`` through
    /// `EnvironmentValues/windowChrome` for content views to publish into.
    @MainActor
    public protocol WindowChrome<Window, Widget>: Core {
        /// Installs a chrome container into the window's title-bar region and
        /// returns the widget that hosts the chrome bar's content, or `nil`
        /// when the backend doesn't support an integrated chrome strip.
        func installWindowChrome(in window: Window) -> Widget?

        /// Creates the application-menu button shown at the leading edge of
        /// the chrome strip. `nil` renders an empty placeholder.
        func createAppMenuButton() -> Widget?

        /// Attaches a button created by ``createAppMenuButton()`` to a window
        /// so the backend can populate it with the application menu.
        func attachAppMenuButton(_ widget: Widget, to window: Window)

        /// Creates a draggable title-bar region element that expands to fill
        /// free space in the chrome strip.
        func createWindowDragRegion() -> Widget?

        /// Registers a drag-region element created by
        /// ``createWindowDragRegion()`` as the window's caption input area.
        /// Called once the element has been committed into the window's tree.
        func attachWindowDragRegion(_ widget: Widget, to window: Window)

        /// Creates a navigation back button styled after the platform's
        /// navigation chrome (e.g. the WinUI back button used by
        /// `NavigationView`), or `nil` to render an empty placeholder in the
        /// back button's slot.
        func createNavigationBackButton() -> Widget?

        /// Updates a button created by ``createNavigationBackButton()`` with
        /// the current back action and environment. Called on every commit
        /// so the click handler stays fresh as navigation state changes.
        func updateNavigationBackButton(
            _ widget: Widget,
            action: (@MainActor () -> Void)?,
            environment: EnvironmentValues
        )
    }
}

extension EnvironmentValues {
    /// Backing store for ``EnvironmentValues/windowChrome``.
    @Entry private var windowChromeStore = UncheckedSendable<WindowChromeModel?>(
        wrappedValue: nil
    )

    /// The per-window chrome state shared between content views and the
    /// backend-hosted chrome strip. `nil` on backends without integrated
    /// window chrome, which makes navigation stacks and toolbars render their
    /// inline bars instead.
    public var windowChrome: WindowChromeModel? {
        get { windowChromeStore.wrappedValue }
        set { windowChromeStore.wrappedValue = newValue }
    }

    /// The height (in DIPs) of the window's chrome strip.
    @Entry public var windowChromeStripHeight = 32.0

    /// Horizontal space (in DIPs) reserved at the chrome strip's leading edge
    /// for system window controls.
    @Entry public var windowCaptionLeadingInset = 0.0

    /// Horizontal space (in DIPs) reserved at the chrome strip's trailing edge
    /// for the system caption buttons.
    @Entry public var windowCaptionTrailingInset = 0.0

    /// The window background color requested by content via
    /// ``View/windowBackground(_:)``. Applied by the backend over its default
    /// window background.
    @Entry public var windowBackgroundColor: Color? = nil
}

/// The per-window model holding the resolved chrome-strip content: back
/// action, title, and toolbar items. Content views publish contributions via
/// the attachment views in this file; the backend's chrome bar reads the
/// resolved values when its view graph updates (which happens after every
/// content update, so contributors are always fresh).
@MainActor
public final class WindowChromeModel: @unchecked Sendable {
    /// Opaque token identifying which attachment view contributed a value, so
    /// that a disappearing view can't clear a newer contribution made by a
    /// different view (ordering of deinit vs commit isn't guaranteed).
    struct ContributionToken: Hashable, Sendable {
        var id = UUID()
    }

    /// Called whenever a contribution mutates the resolved chrome content.
    /// ``WindowReference`` sets this to refresh the chrome view graph: content
    /// commits triggered by bottom-up (state-driven) node updates never reach
    /// `WindowReference.update`, so without this hook the strip would stay
    /// stale until the next full window update.
    var onDidChange: (@MainActor () -> Void)?

    /// The back action contributed by the enclosing navigation stack, or
    /// `nil` while the displayed page hides the back button via
    /// ``View/navigationBarBackButtonHidden(_:)``.
    var backAction: (@MainActor () -> Void)? {
        backHiddenContribution?.hidden == true ? nil : backContribution?.action
    }

    private var backContribution: (token: ContributionToken, action: @MainActor () -> Void)?
    private var backHiddenContribution: (token: ContributionToken, hidden: Bool)?
    private var titleContribution: (token: ContributionToken, title: Text)?
    /// Toolbar items contributed by every live ``View/toolbar`` modifier, in
    /// contribution order (outermost first — matching SwiftUI's merge
    /// semantics for multiple `.toolbar` modifiers).
    private var toolbarContributions: [(token: ContributionToken, items: [ResolvedToolbarItem])] = []

    /// The window's fallback title (the scene's title), shown when no view
    /// contributes a ``navigationTitle``.
    var baseTitle: Text?

    /// The effective title to display in the chrome strip.
    var title: Text? { titleContribution?.title ?? baseTitle }

    /// The toolbar items to display in the chrome strip.
    var toolbarItems: [ResolvedToolbarItem] {
        toolbarContributions.flatMap(\.items)
    }

    init(baseTitle: Text? = nil) {
        self.baseTitle = baseTitle
    }

    func setBackAction(_ action: (@MainActor () -> Void)?, from token: ContributionToken) {
        let hadAction = backAction != nil
        let hadToken = backContribution?.token == token
        if let action {
            backContribution = (token, action)
        } else if hadToken {
            backContribution = nil
        }
        // The stored action always updates so the button's handler stays
        // fresh, but the strip only needs relayout when the button's
        // presence actually changed.
        if hadAction != (backAction != nil) || !hadToken {
            onDidChange?()
        }
    }

    func clearBackAction(from token: ContributionToken) {
        let hadAction = backAction != nil
        if backContribution?.token == token {
            backContribution = nil
        }
        if hadAction != (backAction != nil) {
            onDidChange?()
        }
    }

    func setBackHidden(_ hidden: Bool, from token: ContributionToken) {
        let hadAction = backAction != nil
        backHiddenContribution = (token, hidden)
        if hadAction != (backAction != nil) {
            onDidChange?()
        }
    }

    func clearBackHidden(from token: ContributionToken) {
        let hadAction = backAction != nil
        if backHiddenContribution?.token == token {
            backHiddenContribution = nil
        }
        if hadAction != (backAction != nil) {
            onDidChange?()
        }
    }

    func setTitle(_ title: Text, from token: ContributionToken) {
        // The stored title always updates, but the strip only needs relayout
        // when the contribution's value actually changed.
        let changed = titleContribution?.token != token || titleContribution?.title != title
        titleContribution = (token, title)
        if changed {
            onDidChange?()
        }
    }

    func clearTitle(from token: ContributionToken) {
        if titleContribution?.token == token {
            titleContribution = nil
            onDidChange?()
        }
    }

    func setToolbarItems(_ items: [ResolvedToolbarItem], from token: ContributionToken) {
        if let index = toolbarContributions.firstIndex(where: { $0.token == token }) {
            toolbarContributions[index].items = items
        } else {
            toolbarContributions.append((token, items))
        }
        onDidChange?()
    }

    func clearToolbarItems(from token: ContributionToken) {
        toolbarContributions.removeAll { $0.token == token }
        onDidChange?()
    }
}

/// The chrome strip rendered by the backend into the window's title-bar
/// region as a second view graph. Mirrors the single-row Windows title bar:
/// app menu button, optional back button, title, leading toolbar items, a
/// flexible drag region, trailing toolbar items, then the system caption
/// inset.
struct WindowChromeBar: View {
    @Environment(\.windowChrome) private var chrome
    @Environment(\.windowChromeStripHeight) private var stripHeight
    @Environment(\.windowCaptionLeadingInset) private var leadingInset
    @Environment(\.windowCaptionTrailingInset) private var trailingInset

    var body: some View {
        let items = chrome?.toolbarItems ?? []
        // Near-square chrome buttons, sized like the caption buttons the
        // strip sits next to (a little under the strip height so there's a
        // few points of breathing room top and bottom).
        let itemSize = min(stripHeight - 8, 40)
        HStack(alignment: .center, spacing: 4) {
            WindowMenuButton()
            if let backAction = chrome?.backAction {
                WindowBackButton(action: backAction)
                    .frame(width: itemSize, height: itemSize)
            }
            if let title = chrome?.title {
                title
            }
            chromeItems(items.filter { $0.placement.isLeading })
            WindowDragRegion()
            chromeItems(items.filter {
                !$0.placement.isLeading && $0.placement != .bottomBar
            })
            Color.clear.frame(width: trailingInset)
        }
        .padding(.leading, 8 + leadingInset)
        .frame(height: stripHeight)
    }

    /// Renders toolbar items inline without ``ToolbarBar``'s own leading/
    /// trailing split and padding — the chrome row manages spacing itself.
    /// Toolbar labels show their icon only (matching macOS toolbars), and
    /// every item gets the same height so mixed Button/Menu/Toggle entries
    /// don't produce a ragged strip.
    @ViewBuilder
    private func chromeItems(_ items: [ResolvedToolbarItem]) -> some View {
        let itemSize = min(stripHeight - 8, 40)
        ForEach(Array(items.enumerated()), id: \.offset) { item in
            switch item.element.kind {
            case .view(let view):
                view
                    .labelsHidden()
                    .buttonStyle(.borderless)
                    .font(.system(size: 15))
                    .frame(width: itemSize, height: itemSize)
            case .spacer(.fixed):
                Spacer().frame(width: 16)
            case .spacer(.flexible):
                WindowDragRegion()
            }
        }
    }
}

/// The application-menu button at the leading edge of the chrome strip. The
/// backend supplies the native widget (a button opening the app menu); on
/// backends without chrome support it collapses to an empty container.
struct WindowMenuButton: ElementaryView, View {
    func asWidget<Backend: BaseAppBackend>(backend: Backend) -> Backend.Widget {
        if let backend = backend as? any BackendFeatures.WindowChrome<
            Backend.Window, Backend.Widget
        >,
            let widget = backend.createAppMenuButton()
        {
            return widget
        }
        return backend.createContainer()
    }

    func computeLayout<Backend: BaseAppBackend>(
        _ widget: Backend.Widget,
        proposedSize: ProposedViewSize,
        environment: EnvironmentValues,
        backend: Backend
    ) -> ViewLayoutResult {
        ViewLayoutResult.leafView(
            size: ViewSize(backend.naturalSize(of: widget))
        )
    }

    func commit<Backend: BaseAppBackend>(
        _ widget: Backend.Widget,
        layout: ViewLayoutResult,
        environment: EnvironmentValues,
        backend: Backend
    ) {
        backend.setSize(of: widget, to: layout.size.vector)
        if let backend = backend as? any BackendFeatures.WindowChrome<
            Backend.Window, Backend.Widget
        > {
            func attach<NewBackend>(backend: NewBackend)
            where NewBackend: BackendFeatures.WindowChrome<Backend.Window, Backend.Widget> {
                if let window = environment.window as? NewBackend.Window {
                    backend.attachAppMenuButton(widget, to: window)
                }
            }
            attach(backend: backend)
        }
    }
}

/// The navigation back button shown in the chrome strip while the
/// navigation stack can pop. The backend supplies the native widget (styled
/// after the platform's navigation back affordance); a `nil` widget renders
/// an empty placeholder.
struct WindowBackButton: ElementaryView, View {
    var action: @MainActor () -> Void

    func asWidget<Backend: BaseAppBackend>(backend: Backend) -> Backend.Widget {
        if let backend = backend as? any BackendFeatures.WindowChrome<
            Backend.Window, Backend.Widget
        >,
            let widget = backend.createNavigationBackButton()
        {
            return widget
        }
        return backend.createContainer()
    }

    func computeLayout<Backend: BaseAppBackend>(
        _ widget: Backend.Widget,
        proposedSize: ProposedViewSize,
        environment: EnvironmentValues,
        backend: Backend
    ) -> ViewLayoutResult {
        ViewLayoutResult.leafView(
            size: ViewSize(backend.naturalSize(of: widget))
        )
    }

    func commit<Backend: BaseAppBackend>(
        _ widget: Backend.Widget,
        layout: ViewLayoutResult,
        environment: EnvironmentValues,
        backend: Backend
    ) {
        backend.setSize(of: widget, to: layout.size.vector)
        if let backend = backend as? any BackendFeatures.WindowChrome<
            Backend.Window, Backend.Widget
        > {
            func update<NewBackend>(backend: NewBackend)
            where NewBackend: BackendFeatures.WindowChrome<Backend.Window, Backend.Widget> {
                backend.updateNavigationBackButton(
                    widget,
                    action: action,
                    environment: environment
                )
            }
            update(backend: backend)
        }
    }
}

/// The flexible draggable region inside the chrome strip. Behaves like a
/// ``Spacer`` for layout purposes and is registered with the backend as the
/// window's caption input area once committed.
struct WindowDragRegion: ElementaryView, View {
    func asWidget<Backend: BaseAppBackend>(backend: Backend) -> Backend.Widget {
        if let backend = backend as? any BackendFeatures.WindowChrome<
            Backend.Window, Backend.Widget
        >,
            let widget = backend.createWindowDragRegion()
        {
            return widget
        }
        return backend.createContainer()
    }

    func computeLayout<Backend: BaseAppBackend>(
        _ widget: Backend.Widget,
        proposedSize: ProposedViewSize,
        environment: EnvironmentValues,
        backend: Backend
    ) -> ViewLayoutResult {
        var size = ViewSize.zero
        if environment.usesZStackLayout {
            size = proposedSize.replacingUnspecifiedDimensions(by: ViewSize(8, 8))
        } else {
            let proposedLength = proposedSize[component: environment.layoutOrientation]
            size[component: environment.layoutOrientation] = proposedLength ?? 8
            // The drag region needs real bounds on the cross axis too — a
            // zero-height element gives the window's `setTitleBar` no area to
            // treat as caption.
            let perpendicular = environment.layoutOrientation.perpendicular
            size[component: perpendicular] =
                proposedSize[component: perpendicular] ?? 0
        }
        return ViewLayoutResult(
            size: size,
            participateInStackLayoutsWhenEmpty: true,
            preferences: PreferenceValues.default
                .with(\.layoutPriority, -Double.infinity)
        )
    }

    func commit<Backend: BaseAppBackend>(
        _ widget: Backend.Widget,
        layout: ViewLayoutResult,
        environment: EnvironmentValues,
        backend: Backend
    ) {
        backend.setSize(of: widget, to: layout.size.vector)
        if let backend = backend as? any BackendFeatures.WindowChrome<
            Backend.Window, Backend.Widget
        > {
            func attach<NewBackend>(backend: NewBackend)
            where NewBackend: BackendFeatures.WindowChrome<Backend.Window, Backend.Widget> {
                if let window = environment.window as? NewBackend.Window {
                    backend.attachWindowDragRegion(widget, to: window)
                }
            }
            attach(backend: backend)
        }
    }
}

/// Publishes the navigation back action into the window chrome on every
/// commit, and withdraws it when the navigation stack disappears.
struct WindowChromeBackAttachment<Content: View>: View {
    @Environment(\.windowChrome) private var chrome
    @State private var token = WindowChromeModel.ContributionToken()

    var content: Content
    var canGoBack: Bool
    var action: @MainActor () -> Void

    var body: TupleView1<OnDisappearModifier<Content>> {
        TupleView1(
            OnDisappearModifier(body: TupleView1(content)) { [chrome, token] in
                chrome?.clearBackAction(from: token)
            }
        )
    }

    init(content: Content, canGoBack: Bool, action: @escaping @MainActor () -> Void) {
        self.content = content
        self.canGoBack = canGoBack
        self.action = action
    }

    public func commit<Backend: BaseAppBackend>(
        _ widget: Backend.Widget,
        children: any ViewGraphNodeChildren,
        layout: ViewLayoutResult,
        environment: EnvironmentValues,
        backend: Backend
    ) {
        defaultCommit(
            widget,
            children: children,
            layout: layout,
            environment: environment,
            backend: backend
        )
        environment.windowChrome?.setBackAction(
            canGoBack ? action : nil,
            from: token
        )
    }
}

/// Publishes a navigation title into the window chrome while the attached
/// view is on the navigation stack, and withdraws it when the view disappears.
struct WindowChromeTitleAttachment<Content: View>: View {
    @Environment(\.windowChrome) private var chrome
    @State private var token = WindowChromeModel.ContributionToken()

    var content: Content
    var title: Text

    var body: TupleView1<OnDisappearModifier<Content>> {
        TupleView1(
            OnDisappearModifier(body: TupleView1(content)) { [chrome, token] in
                chrome?.clearTitle(from: token)
            }
        )
    }

    init(content: Content, title: Text) {
        self.content = content
        self.title = title
    }

    public func commit<Backend: BaseAppBackend>(
        _ widget: Backend.Widget,
        children: any ViewGraphNodeChildren,
        layout: ViewLayoutResult,
        environment: EnvironmentValues,
        backend: Backend
    ) {
        defaultCommit(
            widget,
            children: children,
            layout: layout,
            environment: environment,
            backend: backend
        )
        environment.windowChrome?.setTitle(title, from: token)
    }
}

/// Publishes a request to hide the navigation back button while the attached
/// view is displayed, and withdraws it when the view disappears. Applied by
/// ``View/navigationBarBackButtonHidden(_:)``; since environment values only
/// propagate down, the page-level request reaches the chrome strip as a
/// contribution — like ``navigationTitle`` does.
struct WindowChromeBackHiddenAttachment<Content: View>: View {
    @Environment(\.windowChrome) private var chrome
    @State private var token = WindowChromeModel.ContributionToken()

    var content: Content
    var hidden: Bool

    var body: TupleView1<OnDisappearModifier<Content>> {
        TupleView1(
            OnDisappearModifier(body: TupleView1(content)) { [chrome, token] in
                chrome?.clearBackHidden(from: token)
            }
        )
    }

    init(content: Content, hidden: Bool) {
        self.content = content
        self.hidden = hidden
    }

    public func commit<Backend: BaseAppBackend>(
        _ widget: Backend.Widget,
        children: any ViewGraphNodeChildren,
        layout: ViewLayoutResult,
        environment: EnvironmentValues,
        backend: Backend
    ) {
        defaultCommit(
            widget,
            children: children,
            layout: layout,
            environment: environment,
            backend: backend
        )
        environment.windowChrome?.setBackHidden(hidden, from: token)
    }
}

/// Publishes toolbar items into the window chrome while the attached view is
/// on screen. When the window chrome isn't available (other backends), the
/// items render as an inline bar above the content as before.
struct WindowChromeToolbarAttachment<Content: View>: View {
    @Environment(\.windowChrome) private var chrome
    @State private var token = WindowChromeModel.ContributionToken()

    var content: Content
    var items: [ResolvedToolbarItem]

    var body: some View {
        if chrome != nil {
            let bottomItems = items.filter { $0.placement == .bottomBar }
            if bottomItems.isEmpty {
                AnyView(
                    content.onDisappear { [chrome, token] in
                        chrome?.clearToolbarItems(from: token)
                    }
                )
            } else {
                AnyView(
                    VStack(spacing: 0) {
                        content
                        ToolbarBar(items: bottomItems)
                    }
                    .onDisappear { [chrome, token] in
                        chrome?.clearToolbarItems(from: token)
                    }
                )
            }
        } else {
            AnyView(
                VStack(spacing: 0) {
                    ToolbarBar(items: items)
                    content
                }
            )
        }
    }

    public func commit<Backend: BaseAppBackend>(
        _ widget: Backend.Widget,
        children: any ViewGraphNodeChildren,
        layout: ViewLayoutResult,
        environment: EnvironmentValues,
        backend: Backend
    ) {
        defaultCommit(
            widget,
            children: children,
            layout: layout,
            environment: environment,
            backend: backend
        )
        environment.windowChrome?.setToolbarItems(
            items.filter { $0.placement != .bottomBar },
            from: token
        )
    }
}

extension View {
    /// Sets the window's background color. The color propagates up through
    /// layout preferences to the backend, which applies it to the window's
    /// chrome and content area (the Windows equivalent of setting
    /// `NSWindow.backgroundColor`).
    public func windowBackground(_ color: Color) -> some View {
        preference(key: \.windowBackground, value: color)
    }
}
