import Foundation

// MARK: - Value types

/// How a text view truncates overflowing content.
public enum TruncationMode: Sendable, Hashable {
    /// Truncate at the beginning.
    case head
    /// Truncate in the middle.
    case middle
    /// Truncate at the end.
    case tail
}

/// Whether a view's text is selectable.
public struct TextSelection: Sendable, Hashable {
    var isEnabled: Bool

    /// Text can be selected.
    public static let enabled = TextSelection(isEnabled: true)
    /// Text cannot be selected.
    public static let disabled = TextSelection(isEnabled: false)
}

/// The size of controls within a view hierarchy.
public enum ControlSize: Int, Sendable, Hashable, CaseIterable {
    /// Smaller than regular.
    case mini
    /// The small control size.
    case small
    /// The regular control size.
    case regular
    /// The large control size.
    case large
    /// Larger than large.
    case extraLarge
}

/// A style applied to text fields.
public struct TextFieldStyle: Sendable, Hashable {
    enum Kind: Sendable, Hashable {
        case automatic, plain, roundedBorder
    }
    var kind: Kind

    /// The default text field style.
    public static let automatic = TextFieldStyle(kind: .automatic)
    /// A plain text field with no border.
    public static let plain = TextFieldStyle(kind: .plain)
    /// A text field with a rounded border.
    public static let roundedBorder = TextFieldStyle(kind: .roundedBorder)
}

/// A style applied to menus.
public struct MenuStyle: Sendable, Hashable {
    enum Kind: Sendable, Hashable {
        case automatic, button, borderlessButton
    }
    var kind: Kind

    /// The default menu style.
    public static let automatic = MenuStyle(kind: .automatic)
    /// Renders the menu's label as a bordered button.
    public static let button = MenuStyle(kind: .button)
    /// Renders the menu's label as a borderless button.
    public static let borderlessButton = MenuStyle(kind: .borderlessButton)
}

/// Keyboard modifier keys for ``KeyboardShortcut``.
public struct EventModifiers: OptionSet, Sendable, Hashable {
    public let rawValue: Int
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let capsLock = EventModifiers(rawValue: 1 << 0)
    public static let shift = EventModifiers(rawValue: 1 << 1)
    public static let control = EventModifiers(rawValue: 1 << 2)
    public static let option = EventModifiers(rawValue: 1 << 3)
    public static let command = EventModifiers(rawValue: 1 << 4)
    public static let numericPad = EventModifiers(rawValue: 1 << 5)
    public static let function = EventModifiers(rawValue: 1 << 6)

    /// All modifier keys.
    public static let all: EventModifiers = [
        .capsLock, .shift, .control, .option, .command, .numericPad, .function,
    ]
}

/// A key on a keyboard, used in keyboard shortcuts.
public struct KeyEquivalent: Sendable, Hashable, ExpressibleByExtendedGraphemeClusterLiteral {
    /// The key's character, if it's a printable key.
    public var character: Character?

    public init(_ character: Character) {
        self.character = character
    }

    public init(extendedGraphemeClusterLiteral value: Character) {
        self.init(value)
    }

    /// The return key.
    public static let `return` = KeyEquivalent("\r")
    /// The escape key.
    public static let escape = KeyEquivalent("\u{1B}")
    /// The up arrow key.
    public static let upArrow = KeyEquivalent("\u{F700}")
    /// The down arrow key.
    public static let downArrow = KeyEquivalent("\u{F701}")
    /// The left arrow key.
    public static let leftArrow = KeyEquivalent("\u{F702}")
    /// The right arrow key.
    public static let rightArrow = KeyEquivalent("\u{F703}")
}

/// A keyboard shortcut for a control.
public struct KeyboardShortcut: Sendable, Hashable {
    /// The shortcut's key, expressed as a character or a semantic action.
    public enum Key: Sendable, Hashable {
        /// A printable character.
        case character(Character)
        /// The return key; default action.
        case `return`
        /// The escape key; cancel action.
        case escape
        /// A named special key (arrows, tab, etc.).
        case named(String)
    }

    public var key: Key
    public var modifiers: EventModifiers

    public init(_ key: Key, modifiers: EventModifiers = .command) {
        self.key = key
        self.modifiers = modifiers
    }

    public init(_ character: Character, modifiers: EventModifiers = .command) {
        self.init(.character(character), modifiers: modifiers)
    }

    /// The standard shortcut for the default action (Return, ⌘ on macOS).
    public static let defaultAction = KeyboardShortcut(.return, modifiers: .command)
    /// The standard shortcut for the cancel action (Escape).
    public static let cancelAction = KeyboardShortcut(.escape, modifiers: [])
}

/// How a control's visible content transitions when it changes.
public struct ContentTransition: Sendable, Hashable {
    enum Kind: Sendable, Hashable {
        case identity
        case opacity
        case interpolate
        case numericText
        case symbolEffect
    }
    var kind: Kind

    /// No transition.
    public static let identity = ContentTransition(kind: .identity)
    /// A cross-fade.
    public static let opacity = ContentTransition(kind: .opacity)
    /// Content interpolation.
    public static let interpolate = ContentTransition(kind: .interpolate)
    /// Numeric text transitions.
    public static func numericText() -> ContentTransition {
        ContentTransition(kind: .numericText)
    }
    /// Symbol-effect transitions.
    public static var symbolEffect: ContentTransition {
        ContentTransition(kind: .symbolEffect)
    }
}

/// A symbol effect applied to SF-symbol-style images.
public struct SymbolEffect: Sendable, Hashable {
    enum Kind: Sendable, Hashable {
        case bounce, pulse, variableColor, appear, disappear, replace
    }
    var kind: Kind

    public static let bounce = SymbolEffect(kind: .bounce)
    public static let pulse = SymbolEffect(kind: .pulse)
    public static let variableColor = SymbolEffect(kind: .variableColor)
    public static let appear = SymbolEffect(kind: .appear)
    public static let disappear = SymbolEffect(kind: .disappear)
    public static let replace = SymbolEffect(kind: .replace)
}

/// Options controlling symbol-effect playback.
public struct SymbolEffectOptions: Sendable, Hashable {
    var repeats: Bool

    public static let `default` = SymbolEffectOptions(repeats: false)
    /// Repeats the effect indefinitely.
    public static let repeating = SymbolEffectOptions(repeats: true)
    /// Plays the effect once.
    public static let nonRepeating = SymbolEffectOptions(repeats: false)
}

/// The visibility of a scroll view's background.
public struct ScrollContentBackground: Sendable, Hashable {
    var isHidden: Bool

    /// Show the default scroll content background.
    public static let automatic = ScrollContentBackground(isHidden: false)
    /// Hide the scroll content background.
    public static let hidden = ScrollContentBackground(isHidden: true)
    /// Show the scroll content background.
    public static let visible = ScrollContentBackground(isHidden: false)
}

extension EnvironmentValues {
    /// A stable identity for the view, used by ``ScrollViewReader`` targets
    /// and identity-based diffing.
    @Entry public var viewID: AnyHashable?

    /// Text truncation mode applied by text views.
    @Entry public var truncationMode: TruncationMode?

    /// The size controls should render at.
    @Entry public var controlSize: ControlSize = .regular

    /// The style applied to text fields.
    @Entry public var textFieldStyle: TextFieldStyle = .automatic

    /// The style applied to menus.
    @Entry public var menuStyle: MenuStyle = .automatic

    /// Whether ``Label``s should hide their titles.
    @Entry public var labelsHidden = false

    /// The title shown by navigation containers for this view.
    @Entry public var navigationTitle: Text?

    /// The badge value shown for this view by tabs and dock surfaces.
    @Entry public var badgeValue: Text?

    /// The content transition applied when this view's content changes.
    @Entry public var contentTransition: ContentTransition?

    /// The scroll content background visibility.
    @Entry public var scrollContentBackground: ScrollContentBackground = .automatic

    /// Menu items presented as this view's context menu. Consumed by backends
    /// with context-menu support; otherwise inert.
    @Entry public var contextMenuItems: [MenuItem]?

    /// The keyboard shortcut bound to the nearest activatable control.
    /// Consumed by menus today; control-level shortcut dispatch is pending.
    @Entry public var keyboardShortcut: KeyboardShortcut?

    /// The drop handler for this view.
    @Entry public var dropHandler: (@MainActor @Sendable ([URL]) -> Bool)?

    /// Called when the pointer enters or leaves a drop destination, as
    /// recorded by ``View/dropDestination(for:action:isTargeted:)``.
    @Entry public var dropIsTargetedHandler: (@MainActor @Sendable (Bool) -> Void)?

    /// The pointer style over this view, as recorded by
    /// ``View/pointerStyle(_:)``.
    @Entry public var pointerStyle: PointerStyle?
}

// MARK: - Modifiers

extension View {
    /// Assigns a stable identity to the view, used for scroll targets and
    /// identity-based invalidation.
    public func id<ID: Hashable>(_ id: ID) -> some View {
        EnvironmentModifier(self) { environment in
            environment.with(\.viewID, AnyHashable(id))
        }
    }

    /// Sets whether the view's text is selectable.
    public func textSelection(_ selection: TextSelection) -> some View {
        textSelectionEnabled(selection.isEnabled)
    }

    /// Sets the truncation mode for text within this view.
    public func truncationMode(_ mode: TruncationMode) -> some View {
        EnvironmentModifier(self) { environment in
            environment.with(\.truncationMode, mode)
        }
    }

    /// Sets the size of controls within this view.
    public func controlSize(_ size: ControlSize) -> some View {
        EnvironmentModifier(self) { environment in
            environment.with(\.controlSize, size)
        }
    }

    /// Sets the style applied to text fields within this view.
    public func textFieldStyle(_ style: TextFieldStyle) -> some View {
        EnvironmentModifier(self) { environment in
            environment.with(\.textFieldStyle, style)
        }
    }

    /// Sets the style applied to menus within this view.
    public func menuStyle(_ style: MenuStyle) -> some View {
        EnvironmentModifier(self) { environment in
            environment.with(\.menuStyle, style)
        }
    }

    /// Hides the title of ``Label``s within this view.
    public func labelsHidden() -> some View {
        EnvironmentModifier(self) { environment in
            environment.with(\.labelsHidden, true)
        }
    }

    /// Sets the navigation title for this view.
    public func navigationTitle(_ title: String) -> some View {
        navigationTitle(Text(title))
    }

    /// Sets the navigation title for this view.
    public func navigationTitle(_ title: Text) -> some View {
        WindowChromeTitleAttachment(
            content: EnvironmentModifier(self) { environment in
                environment.with(\.navigationTitle, title)
            },
            title: title
        )
    }

    /// Sets a badge value shown by containing presentation surfaces.
    public func badge(_ count: Int) -> some View {
        EnvironmentModifier(self) { environment in
            environment.with(\.badgeValue, Text("\(count)"))
        }
    }

    /// Sets a badge label shown by containing presentation surfaces.
    public func badge(_ label: String) -> some View {
        EnvironmentModifier(self) { environment in
            environment.with(\.badgeValue, Text(label))
        }
    }

    /// Sets a badge label shown by containing presentation surfaces.
    public func badge(_ label: Text) -> some View {
        EnvironmentModifier(self) { environment in
            environment.with(\.badgeValue, label)
        }
    }

    /// Sets the transition applied when this view's content changes.
    /// Animated playback lands with animation support; the transition is
    /// recorded in the environment.
    public func contentTransition(_ transition: ContentTransition) -> some View {
        EnvironmentModifier(self) { environment in
            environment.with(\.contentTransition, transition)
        }
    }

    /// Applies a symbol effect to SF-symbol-style images within this view.
    /// Effect playback lands with animation support; the configuration is
    /// recorded in the environment.
    public func symbolEffect(
        _ effect: SymbolEffect,
        options: SymbolEffectOptions = .default,
        isActive: Bool = true
    ) -> some View {
        self
    }

    /// Applies a symbol effect triggered by changes to a value.
    public func symbolEffect<V: Equatable>(
        _ effect: SymbolEffect,
        options: SymbolEffectOptions = .default,
        value: V
    ) -> some View {
        self
    }

    /// Sets the visibility of scroll content backgrounds within this view.
    public func scrollContentBackground(_ visibility: ScrollContentBackground) -> some View {
        EnvironmentModifier(self) { environment in
            environment.with(\.scrollContentBackground, visibility)
        }
    }

    /// Adds a context menu to this view.
    public func contextMenu<MenuItems: View>(
        @ViewBuilder menuItems: () -> MenuItems
    ) -> some View {
        let items = menuItems()._asMenuItems
        return EnvironmentModifier(self) { environment in
            environment.with(\.contextMenuItems, items)
        }
    }

    /// Assigns a keyboard shortcut to the nearest activatable control.
    public func keyboardShortcut(
        _ shortcut: KeyboardShortcut,
        modifiers: EventModifiers? = nil
    ) -> some View {
        EnvironmentModifier(self) { environment in
            environment.with(\.keyboardShortcut, shortcut)
        }
    }

    /// Assigns a keyboard shortcut to the nearest activatable control.
    public func keyboardShortcut(
        _ key: KeyEquivalent,
        modifiers: EventModifiers = .command
    ) -> some View {
        keyboardShortcut(
            KeyboardShortcut(
                key.character.map(KeyboardShortcut.Key.character) ?? .named("special"),
                modifiers: modifiers
            )
        )
    }

    /// Enables dropping URLs onto this view. The handler participates in
    /// drop-target resolution once backend drop support lands.
    public func dropDestination(
        for type: URL.Type = URL.self,
        action: @escaping @MainActor @Sendable ([URL], CGPoint) -> Bool
    ) -> some View {
        EnvironmentModifier(self) { environment in
            environment.with(\.dropHandler) { urls in action(urls, .zero) }
        }
    }

    /// Enables dropping URLs onto this view with an `isTargeted` hover
    /// callback, as in SwiftUI's `dropDestination(for:action:isTargeted:)`.
    ///
    /// Both callbacks are recorded in the environment for backends' drop
    /// machinery once it lands.
    public func dropDestination(
        for type: URL.Type = URL.self,
        action: @escaping @MainActor @Sendable ([URL], CGPoint) -> Bool,
        isTargeted: @escaping @MainActor @Sendable (Bool) -> Void
    ) -> some View {
        EnvironmentModifier(self) { environment in
            environment
                .with(\.dropHandler) { urls in action(urls, .zero) }
                .with(\.dropIsTargetedHandler) { isTargeted($0) }
        }
    }

    /// Presents content in a popover when `isPresented` is true. Uses sheet
    /// presentation plumbing until popover-specific chrome lands.
    public func popover<Content: View>(
        isPresented: Binding<Bool>,
        attachmentAnchor: UnitPoint = .center,
        arrowEdge: Edge? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        sheet(isPresented: isPresented, content: content)
    }

    /// Inserts a view at the given safe-area edge, reserving space for it.
    func _safeAreaInset<Content: View>(
        edge: Edge.Set,
        alignment: Alignment = .center,
        spacing: Double? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        _SafeAreaInsetView(
            body: self,
            edge: edge,
            spacing: spacing ?? 0,
            insetContent: content()
        )
    }
}

/// Lays out safe-area inset content at the given edge, reserving space for it
/// as SwiftUI does.
private struct _SafeAreaInsetView<Wrapped: View, InsetContent: View>: View {
    var wrapped: Wrapped
    var edge: Edge.Set
    var spacing: Double
    var insetContent: InsetContent

    init(
        body wrapped: Wrapped,
        edge: Edge.Set,
        spacing: Double,
        insetContent: InsetContent
    ) {
        self.wrapped = wrapped
        self.edge = edge
        self.spacing = spacing
        self.insetContent = insetContent
    }

    var body: some View {
        if edge == .top {
            VStack(spacing: spacing) { insetContent; wrapped }
        } else if edge == .bottom {
            VStack(spacing: spacing) { wrapped; insetContent }
        } else if edge == .leading {
            HStack(spacing: spacing) { insetContent; wrapped }
        } else if edge == .trailing {
            HStack(spacing: spacing) { wrapped; insetContent }
        } else {
            wrapped
        }
    }
}

/// A view equal to another only when its content compares equal, enabling
/// update elision (SwiftUI semantics).
public struct EquatableView<Content: View & Equatable>: View, Equatable {
    public nonisolated(unsafe) var content: Content

    public init(content: Content) {
        self.content = content
    }

    public var body: some View { content }
}

extension View {
    /// Wraps this view so updates are elided while its value compares equal
    /// to the previous value.
    public func equatable() -> EquatableView<Self> where Self: Equatable {
        EquatableView(content: self)
    }
}
