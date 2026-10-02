import Foundation

/// The environment used when constructing scenes and views. Each scene or view
/// gets to modify the environment before passing it on to its children, which
/// is the basis of many view modifiers.
public struct EnvironmentValues {
    /// The app's most recently computed root environment.
    ///
    /// Root environments already contain backend-provided values such as
    /// `colorScheme`, so this gives platform code that lives outside the view
    /// hierarchy (e.g. static `Color` definitions) access to them.
    nonisolated(unsafe) public internal(set) static var current: EnvironmentValues?

    /// A font resolution context derived from the current environment.
    ///
    /// Essentially just a subset of the environment.
    @MainActor
    public var fontResolutionContext: Font.Context {
        Font.Context(
            overlay: fontOverlay,
            deviceClass: backend.deviceClass,
            resolveTextStyle: { backend.resolveTextStyle($0) }
        )
    }

    /// The current font resolved to a form suitable for rendering.
    ///
    /// Just a helper method for our own backends. We haven't made this public
    /// because it would be weird to have two pretty equivalent ways of resolving
    /// fonts.
    @MainActor
    @_spi(Backends) public var resolvedFont: Font.Resolved {
        font.resolve(in: fontResolutionContext)
    }

    /// The suggested foreground color for backends to use.
    ///
    /// Backends don't neccessarily have to obey this when
    /// ``EnvironmentValues/foregroundColor`` is `nil`.
    public var suggestedForegroundColor: Color {
        foregroundColor ?? colorScheme.defaultForegroundColor
    }

    /// Called by view graph nodes when they resize due to an internal state
    /// change and end up changing size.
    ///
    /// Each view graph node sets its own handler when passing the environment
    /// on to its children, setting up a bottom-up update chain up which resize
    /// events can propagate.
    @_spi(Backends) public var onResize: @MainActor (_ newSize: ViewSize) -> Void

    /// Backing storage for extensible subscript
    private var values: [ObjectIdentifier: Any]

    /// An internal environment value used to control whether layout caching is
    /// enabled or not.
    ///
    /// This is set to `true` when computing non-final layouts. E.g. when a stack
    /// computes the minimum and maximum sizes of its children, it should enable
    /// layout caching because those updates are guaranteed to be non-final. The
    /// reason that we can't cache on non-final updates is that the last layout
    /// proposal received by each view must be its intended final proposal.
    var allowLayoutCaching: Bool = false

    /// Backing storage for observable subscript
    private var observableObjects: [ObjectIdentifier: AnyObject]

    /// Gets an environment value given an environment key's metatype.
    ///
    /// - Parameter key: The type of the key.
    /// - Returns: The environment value associated with `key`, or the key's
    ///   default value if it hasn't been set in the environment yet.
    public subscript<T: EnvironmentKey>(_ key: T.Type) -> T.Value {
        get {
            values[ObjectIdentifier(T.self), default: T.defaultValue] as! T.Value
        }
        set {
            values[ObjectIdentifier(T.self)] = newValue
        }
    }

    public subscript<T: AnyObject>(observable key: T.Type) -> T? {
        get {
            guard let value = observableObject(forType: T.self) as? T? else {
                let message =
                    "EnvironmentValues type mismatch: value for key '\(T.self).self' doesn't match expected type '\(T.self)'"
                logger.critical("\(message)")
                fatalError(message)
            }
            return value
        }
        set {
            observableObjects[ObjectIdentifier(T.self)] = newValue
        }
    }

    /// Looks up an environment object by its concrete runtime type.
    ///
    /// Unlike the `observable` subscript, this can be called through an
    /// existential metatype because the key is derived from the metatype
    /// *value* rather than a static generic parameter.
    public func observableObject(forType type: AnyObject.Type) -> AnyObject? {
        observableObjects[ObjectIdentifier(type)]
    }

    /// Brings the current window forward.
    ///
    /// This is not guaranteed to always bring the window to the top (due
    /// to focus stealing prevention).
    @MainActor
    func bringWindowForward() {
        func activate<Backend: BaseAppBackend>(with backend: Backend) {
            backend.activate(window: window as! Backend.Window)
        }
        activate(with: backend)
    }

    /// The backend in use.
    ///
    /// Mustn't change throughout the app's lifecycle.
    let backend: any BaseAppBackend

    /// Presents an 'Open file' dialog fit for selecting a single file.
    ///
    /// Displays as a modal for the current window, or the entire app if
    /// accessed outside of a scene's view graph (in which case the backend
    /// can decide whether to make it an app modal, a standalone window, or a
    /// modal for a window of its choosing).
    ///
    /// - Important: GtkBackend, Gtk3Backend, and WinUIBackend will only
    ///   enable _either_ files or directories for selection, but won't
    ///   enable both types in a single dialog.
    @MainActor
    @available(tvOS, unavailable, message: "tvOS does not provide file system access")
    public var chooseFile: PresentSingleFileOpenDialogAction {
        PresentSingleFileOpenDialogAction(
            backend: backend,
            window: MainActorBox(value: window)
        )
    }

    /// Presents an 'Open files' dialog fit for selecting multiple files.
    @MainActor
    @available(tvOS, unavailable, message: "tvOS does not provide file system access")
    public var chooseFiles: PresentMultipleFilesOpenDialogAction {
        PresentMultipleFilesOpenDialogAction(
            backend: backend,
            window: MainActorBox(value: window)
        )
    }

    /// Presents a 'Save file' dialog fit for selecting a save destination.
    ///
    /// Displays as a modal for the current window, or the entire app if
    /// accessed outside of a scene's view graph (in which case the backend
    /// can decide whether to make it an app modal, a standalone window, or a
    /// window of its choosing).
    @MainActor
    public var chooseFileSaveDestination: PresentFileSaveDialogAction {
        PresentFileSaveDialogAction(
            backend: backend,
            window: MainActorBox(value: window)
        )
    }

    /// Presents an alert for the current window, or the entire app if accessed
    /// outside of a scene's view graph (in which case the backend can decide
    /// whether to make it an app modal, a standalone window, or a modal for a
    /// window of its choosing).
    @MainActor
    public var presentAlert: PresentAlertAction {
        PresentAlertAction(environment: self)
    }

    /// Opens a URL with the default application.
    ///
    /// May present an application picker if multiple applications are registered
    /// for the given URL protocol.
    ///
    /// `nil` on platforms that don't support opening external URLS (none at the
    /// moment).
    @MainActor
    public var openURL: OpenURLAction {
        OpenURLAction(backend: backend)
    }

    /// Opens a window with the specified ID.
    @MainActor
    public var openWindow: OpenWindowAction {
        OpenWindowAction(environment: self)
    }

    /// Closes the enclosing window.
    @MainActor
    public var dismissWindow: DismissWindowAction {
        DismissWindowAction(
            backend: backend,
            window: MainActorBox(value: window)
        )
    }

    /// Reveals a file in the system's file manager.
    ///
    /// This opens the file's enclosing directory and highlights the file.
    ///
    /// `nil` on platforms that don't support revealing files, e.g. iOS.
    @MainActor
    public var revealFile: RevealFileAction? {
        RevealFileAction(backend: backend)
    }

    /// Whether the backend can have multiple windows open at once. Mobile
    /// backends generally can't.
    @MainActor
    public var supportsMultipleWindows: Bool {
        backend.supportsMultipleWindows
    }

    /// The display styles supported by ``DatePicker``. ``datePickerStyle`` must be one of these.
    public let supportedDatePickerStyles: [DatePickerStyle]

    /// Checks whether a picker style is supported by the current backend.
    @MainActor
    public var isPickerStyleSupported: PickerSupportedAction {
        PickerSupportedAction(backend: backend)
    }

    /// Creates the default environment.
    ///
    /// - Parameters:
    ///   - backend: The app's backend.
    @_spi(Backends) public init<Backend: BaseAppBackend>(backend: Backend) {
        self.backend = backend

        onResize = { _ in }
        values = [:]
        observableObjects = [:]

        if let backend = backend as? any BackendFeatures.DatePickers {
            self.supportedDatePickerStyles = backend.supportedDatePickerStyles
        } else {
            self.supportedDatePickerStyles = [.automatic]
        }
    }

    /// Returns a copy of the environment with the specified property set to the
    /// provided new value.
    ///
    /// - Parameters:
    ///   - keyPath: A key path to the property to set.
    ///   - newValue: The new value of the property.
    /// - Returns: A copy of the environment with the specified property set to
    ///   `newValue`.
    public func with<T>(_ keyPath: WritableKeyPath<Self, T>, _ newValue: T) -> Self {
        var environment = self
        environment[keyPath: keyPath] = newValue
        return environment
    }
}

extension EnvironmentValues {
    /// The app storage provider to use for `@AppStorage` property wrappers.
    @Entry public var appStorageProvider: any AppStorageProvider = DefaultAppStorageProvider()

    /// The current stack orientation.
    ///
    /// Inherited by ``ForEach`` and ``Group`` so that they can be used without
    /// affecting layout.
    @Entry public var layoutOrientation: Orientation = .vertical

    /// The current stack alignment.
    ///
    /// Inherited by ``ForEach`` and ``Group`` so that they can be used without
    /// affecting layout.
    @Entry public var layoutAlignment: StackAlignment = .center

    /// Whether to use the ZStack StackLayout variants.
    @Entry public var usesZStackLayout: Bool = false

    /// The alignment of content inside a ``ZStack``.
    /// Only gets used when ``usesZStackLayout`` is `true`.
    @Entry public var zStackContentAlignment: Alignment = .center

    /// The current stack spacing.
    ///
    /// Inherited by ``ForEach`` and ``Group`` so that they can be used without
    /// affecting layout.
    @Entry public var layoutSpacing: Double = 10

    /// The horizontal spacing between cells in a ``Grid`` row, propagated
    /// from the enclosing ``Grid``'s `horizontalSpacing`.
    @Entry internal var gridHorizontalSpacing: Double?

    /// The visibility of scroll indicators for scroll views within this
    /// scope. Read by scroll views when backend support lands.
    @Entry public var scrollIndicatorVisibility: ScrollIndicatorVisibility = .automatic

    /// Whether scrolling is disabled for scroll views within this scope.
    /// Read by scroll views when backend support lands.
    @Entry public var scrollDisabled = false

    /// Whether the view participates in scroll-target (paging) behavior.
    /// Read by scroll views when scroll-targeting support lands.
    @Entry internal var scrollTargetLayoutEnabled = false

    /// The bounce behavior for scroll views within this scope. Read by
    /// scroll views when bounce-behavior support lands.
    @Entry public var scrollBounceBehavior = ScrollBounceBehavior.automatic

    /// Whether scrollable views should avoid clipping to their bounds, as
    /// recorded by ``View/scrollClipDisabled(_:)``.
    @Entry public var scrollClipDisabled = false

    /// The viewport of the nearest enclosing ``ScrollView`` that scrolls
    /// vertically. Published by ``ScrollView`` so that lazy containers such
    /// as ``LazyVStack`` can materialize only the visible elements.
    @Entry internal var scrollViewport: ScrollViewport?

    /// Whether this view is a descendant of a ``LazyVStack``. Consumed by
    /// ``ForEach`` to decide whether element windowing is permitted.
    @Entry internal var lazyStackEnabled = false

    /// The opacity of views within this scope. Applied by backends when
    /// opacity support lands.
    @Entry public var viewOpacity: Double = 1

    /// The line spacing for text within this scope. Applied by text layout
    /// when line-spacing support lands.
    @Entry public var lineSpacing: Double?

    /// The current font.
    @Entry public var font: Font = .body

    /// A font overlay storing font modifications.
    ///
    /// If these conflict with the font's internal overlay, these win out.
    ///
    /// We keep this separate overlay for modifiers because we want modifiers to
    /// be persisted even if the developer sets a custom font further down the
    /// view hierarchy.
    @Entry internal var fontOverlay = Font.Overlay()

    /// How lines should be aligned relative to each other when line wrapped.
    @Entry public var multilineTextAlignment: HorizontalAlignment = .leading

    /// Whether to override the case of displayed ``Text`` views.
    ///
    /// `nil` displays the text without any case changes.
    @Entry public var textCase: Text.Case?

    /// Whether to render text struck through. Backend rendering support is
    /// pending; the value is carried so that backends can opt in.
    @Entry public var textStrikethrough = false

    /// Whether to render text underlined. Backend rendering support is
    /// pending; the value is carried so that backends can opt in.
    @Entry public var textUnderline = false

    /// The current color scheme of the current view scope.
    @Entry public var colorScheme: ColorScheme = .light

    /// The foreground color.
    ///
    /// `nil` means that the default foreground color of the current color scheme
    /// should be used.
    @Entry public var foregroundColor: Color?

    /// The tint color of views within this view, as in SwiftUI's `View.tint`.
    ///
    /// Affects progress bars, and may affect other controls once the backends
    /// learn to consume it.
    @Entry public var tintColor: (any ShapeStyle)?

    /// Called when a text field gets submitted (usually due to the user
    /// pressing Enter/Return).
    @Entry public var onSubmit: (@MainActor @Sendable () -> Void)?

    /// The scale factor of the current window.
    @Entry public var windowScaleFactor: Double = 1

    /// The type of input that text fields represent.
    ///
    /// This affects autocomplete suggestions, and on devices with no physical keyboard, which
    /// on-screen keyboard to use.
    ///
    /// - Warning: Do not use this in place of validation, even if you only plan on supporting
    ///   mobile devices, as this does not restrict copy-paste and many mobile devices support
    ///   Bluetooth keyboards.
    @Entry public var textContentType: TextContentType = .text

    /// The way that scrollable content interacts with the software keyboard.
    @Entry public var scrollDismissesKeyboardMode: ScrollDismissesKeyboardMode = .automatic

    /// The style of list to use.
    @Entry @_spi(Backends) public var listStyle: ListStyle = .default

    /// The style of toggle to use.
    @Entry public var toggleStyle: ToggleStyle = .button

    /// Whether the text should be selectable.
    ///
    /// Set by ``View/textSelectionEnabled(_:)``.
    @Entry public var isTextSelectionEnabled: Bool = false

    /// The resizing behaviour of windows.
    ///
    /// Set by ``Window/windowResizability(_:)->Scene``.
    @Entry internal var windowResizability: WindowResizability = .automatic

    /// The default launch behavior of windows.
    ///
    /// Set by ``Window/defaultLaunchBehavior(_:)->Scene``.
    @Entry internal var defaultLaunchBehavior: SceneLaunchBehavior = .automatic

    /// The default size of windows.
    ///
    /// Defaults to 900x450.
    ///
    /// Set by ``Window/defaultSize(width:height:)->Scene``.
    @Entry internal var defaultWindowSize: SIMD2<Int> = SIMD2(900, 450)

    /// The menu ordering to use.
    @Entry public var menuOrder: MenuOrder = .automatic

    /// Backing store for ``EnvironmentValues/openWindowFunctionsByID``.
    /// Used to resolve "non-sendable type" warnings in Swift 5 and errors in Swift 6 language mode.
    @Entry private var openWindowFunctionsByIDStore = UncheckedSendable(
        wrappedValue: Box<[String: @MainActor () -> Void]>([:])
    )

    /// A mapping of window IDs to functions that open the corresponding windows.
    internal var openWindowFunctionsByID: Box<[String: @MainActor () -> Void]> {
        get {
            openWindowFunctionsByIDStore.wrappedValue
        }
        set {
            openWindowFunctionsByIDStore.wrappedValue = newValue
        }
    }

    /// Backing store for ``EnvironmentValues/openWindowFunctionsByValueType``.
    @Entry private var openWindowFunctionsByValueTypeStore = UncheckedSendable(
        wrappedValue: Box<[ObjectIdentifier: @MainActor (Any) -> Void]>([:])
    )

    /// A mapping of presented value types to functions that open a window
    /// bound to a value of that type.
    internal var openWindowFunctionsByValueType: Box<[ObjectIdentifier: @MainActor (Any) -> Void]> {
        get {
            openWindowFunctionsByValueTypeStore.wrappedValue
        }
        set {
            openWindowFunctionsByValueTypeStore.wrappedValue = newValue
        }
    }

    /// The app's lifecycle phase.
    ///
    /// Unlike in SwiftUI, where the app's lifecycle phase can only be accessed
    /// by using `@Environment(\.scenePhase)` directly on the ``App`` struct, this
    /// environment value can be accessed from anywhere within the application.
    @Entry public package(set) var appPhase: AppPhase = .active

    /// The current scene's lifecycle phase.
    ///
    /// - Important: Unlike SwiftUI, this environment value cannot be accessed from
    ///   outside a scene. If you need to access the phase of the entire application,
    ///   use ``appPhase`` instead.
    public package(set) var scenePhase: ScenePhase {
        get {
            guard let phase = self[__Key_scenePhase.self] else {
                if window != nil {
                    // If there's a window but no scenePhase, we assume that the
                    // backend is actively trying to _set_ the scene phase; return
                    // a dummy value to prevent a crash.
                    return .inactive
                }

                fatalError(
                    """
                    'scenePhase' accessed from outside a scene (most likely \
                    with an @Environment property on the App struct); you \
                    probably meant to use 'appPhase' instead
                    """
                )
            }
            return phase
        }
        set { self[__Key_scenePhase.self] = newValue }
    }
    private struct __Key_scenePhase: EnvironmentKey {
        static let defaultValue: ScenePhase? = nil
    }

    /// Backing store for ``EnvironmentValues/window``.
    /// Used to resolve "non-sendable type" warnings in Swift 5 and errors in Swift 6 language mode.
    @Entry private var windowStore = UncheckedSendable<Any?>(wrappedValue: nil)

    /// The backend's representation of the window that the current view is
    /// in, if any.
    ///
    /// This is a very internal detail that should never get exposed to users.
    @_spi(Backends) public var window: Any? {
        get {
            windowStore.wrappedValue
        }
        set {
            windowStore.wrappedValue = newValue
        }
    }

    /// Backing store for ``EnvironmentValues/sheet``.
    /// Used to resolve "non-sendable type" warnings in Swift 5 and errors in Swift 6 language mode.
    @Entry private var sheetStore = UncheckedSendable<Any?>(wrappedValue: nil)

    /// The backend's representation of the sheet that the current view is
    /// in, if any.
    ///
    /// This is a very internal detail that should never get exposed to users.
    @_spi(Backends) public var sheet: Any? {
        get {
            sheetStore.wrappedValue
        }
        set {
            sheetStore.wrappedValue = newValue
        }
    }

    /// The current calendar that views should use when handling dates.
    @Entry public var calendar: Calendar = .current

    /// The current time zone that views should use when handling dates.
    @Entry public var timeZone: TimeZone = .current

    /// The current locale.
    @Entry public var locale: Locale = .current

    /// The display style used by ``Picker``.
    @Entry public var pickerStyle: any PickerStyle = .automatic

    /// The display style used by ``DatePicker``.
    @Entry public var datePickerStyle: DatePickerStyle = .automatic

    /// Whether user interaction is enabled.
    ///
    /// Set by ``View/disabled(_:)``.
    @Entry public var isEnabled: Bool = true

    /// The number of lines text can occupy and whether to reserve that space.
    @Entry public var lineLimitSettings: LineLimit?

    /// The maximum number of lines that text can occupy in a view.
    public var lineLimit: Int? {
        lineLimitSettings?.limit
    }

    /// Whether the current device has a circular screen. Primarily Android smart watches.
    @Entry public var isCircularScreen: Bool = false

    /// The display style used by ``Button``.
    @Entry public var buttonStyle: ButtonStyle?

    /// The default button style as declared by the backend.
    @MainActor
    public var defaultButtonStyle: ButtonStyle {
        backend.defaultButtonStyle()
    }

    /// The resolved ``ButtonStyle``. Either ``buttonStyle``, or ``defaultButtonStyle`` if nil.
    @MainActor
    public var resolvedButtonStyle: ButtonStyle {
        buttonStyle ?? defaultButtonStyle
    }

    /// The amount of padding that the current backend applies to the labels of buttons with the current ``ButtonStyle``.
    @MainActor
    public var buttonPadding: SIMD2<Int> {
        backend.buttonPadding(in: self)
    }

    /// The device class of the current device.
    @MainActor
    public var deviceClass: DeviceClass { backend.deviceClass }

    /// All observers set by ``View/focused(_:)`` in the environment.
    @Entry @_spi(Backends) public var widgetFocusObservers: [WidgetFocusObserver] = []

    /// A value used to make widgets programmatically gain or lose focus.
    @Entry @_spi(Backends) public var focusOverride: Focus?

    /// Whether to highlight a focused widget.
    @Entry public var focusEffectDisabled: Bool = false

    /// Whether ``TextEditor`` wraps lines at the editor's width.
    ///
    /// Recorded in the environment; backends that support wrapping should
    /// read it when configuring text editors.
    @Entry public var textEditorWraps: Bool = true
}

extension EnvironmentValues {
    func applyingTextTransforms(to string: String) -> String {
        var string = string

        switch textCase {
            case .lowercase: string = string.lowercased(with: locale)
            case .uppercase: string = string.uppercased(with: locale)
            case nil: break
        }

        return string
    }
}

/// A key that can be used to extend the environment with new properties.
public protocol EnvironmentKey<Value> {
    /// The type of value the key can hold.
    associatedtype Value
    /// The default value for the key.
    static var defaultValue: Value { get }
}
