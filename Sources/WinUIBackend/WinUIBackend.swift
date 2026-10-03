import CWinRT
import Foundation
@_spi(Backends) import SwiftCrossUI
import UWP
import WinAppSDK
import WinSDK
import WinUI
import WinUIInterop
@preconcurrency import WindowsFoundation
import Mutex

// Many force tries are required for the WinUI backend but we don't really want them
// anywhere else so just disable the lint rule at a file level.
// swiftlint:disable force_try

extension App {
    public typealias Backend = WinUIBackend

    public var backend: WinUIBackend {
        WinUIBackend(urlSchemes: Self.metadata?.urlSchemes?.map(\.scheme))
    }
}

class WinUIApplication: SwiftApplication, @unchecked Sendable {
    static let callback = Mutex<(@MainActor (WinUIApplication, AppInstance) -> Void)?>(nil)
    static let urlSchemes = Mutex<[String]>([])

    override func onLaunched(_ args: WinUI.LaunchActivatedEventArgs) {
        // Register the schemes on each launch. Windows ignores duplicate URL
        // scheme registrations so this is safe.
        let schemes = Self.urlSchemes.withLock { $0 }
        var processName = ProcessInfo.processInfo.processName
        if processName.hasSuffix(".exe") {
            processName = String(processName.dropLast(".exe".count))
        }
        for scheme in schemes {
            ActivationRegistrationManager.registerForProtocolActivation(
                scheme,
                "",
                processName,
                ""
            )
        }

        // Adapted from https://learn.microsoft.com/en-us/windows/apps/windows-app-sdk/applifecycle/applifecycle-single-instance
        let args = try! AppInstance.getCurrent().getActivatedEventArgs()!
        let keyInstance = AppInstance.findOrRegisterForKey(processName)!
        guard keyInstance.isCurrent else {
            Self.redirectActivation(args, to: keyInstance)
        }

        Self.callback.withLock { callback in
            // We can't explicitly hop to the main actor because we haven't set up
            // our WinUI MainActor fix yet.
            MainActor.assumeIsolated {
                callback?(self, keyInstance)
            }
        }
    }

    // Adapted from https://learn.microsoft.com/en-us/windows/apps/windows-app-sdk/applifecycle/applifecycle-single-instance
    static func redirectActivation(
        _ args: AppActivationArguments,
        to keyInstance: AppInstance
    ) -> Never {
        let semaphore = DispatchSemaphore(value: 0)
        let promise = try! keyInstance.redirectActivationToAsync(args)!
        promise.completed = { _, _ in
            semaphore.signal()
        }

        semaphore.wait()

        // Bring key instance to the foreground
        do {
            try InstancingHelpers.activateProcess(withId: Int(keyInstance.processId))
        } catch {
            print(
                """
                Failed to bring key instance (pid=\(keyInstance.processId)) to \
                foreground: \(error.localizedDescription)
                """
            )
        }
        Foundation.exit(0)
    }
}

public final class WinUIBackend:
    BaseAppBackend,
    BackendFeatures.ApplicationMenus,
    BackendFeatures.ExternalURLs,
    BackendFeatures.IncomingURLs,
    BackendFeatures.FileDialogs,
    BackendFeatures.CornerRadius,
    BackendFeatures.Gestures,
    BackendFeatures.AttachedMenus,
    BackendFeatures.Paths,
    BackendFeatures.Tooltips,
    BackendFeatures.ViewLabelToggleButtons,
    BackendFeatures.ContextMenus,
    BackendFeatures.Colors,
    BackendFeatures.DatePickers,
    BackendFeatures.Windowing,
    BackendFeatures.LinearGradients,
    BackendFeatures.RadialGradients,
    BackendFeatures.ScrollViewportReporting
{
    // Logging
    private struct LogLocation: Hashable, Equatable {
        let file: String
        let line: Int
        let column: Int
    }

    private var logsPerformed: Set<LogLocation> = []

    func debugLogOnce(
        _ message: String,
        file: String = #file,
        line: Int = #line,
        column: Int = #column
    ) {
        #if DEBUG
            let location = LogLocation(file: file, line: line, column: column)
            if logsPerformed.insert(location).inserted {
                logger.notice("\(message)")
            }
        #endif
    }

    public typealias Window = CustomWindow
    public typealias Widget = WinUI.FrameworkElement
    public typealias Menu = WinUI.MenuFlyout
    public typealias Path = GeometryGroupHolder

    public let defaultTableRowContentHeight = 20
    public let defaultTableCellVerticalPadding = 4
    public let defaultPaddingAmount: Double = 10
    public let requiresImageUpdateOnScaleFactorChange = false
    public let supportsMultipleWindows = true
    public let deviceClass = DeviceClass.desktop
    public let supportedDatePickerStyles: [DatePickerStyle] = [
        .automatic,
        .graphical,
        .compact,
        .wheel,
    ]
    public let supportedPickerStyles: [BackendPickerStyle] = [.menu, .radioGroup]
    public let canOverrideWindowColorScheme = true
    public let restoresWindowFrames = false

    public var scrollBarWidth: Int {
        12
    }

    var borderedButtonPadding: SIMD2<Int>?

    class InternalState {
        var buttonClickActions: [ObjectIdentifier: () -> Void] = [:]
        var toggleClickActions: [ObjectIdentifier: (Bool) -> Void] = [:]
        var switchClickActions: [ObjectIdentifier: (Bool) -> Void] = [:]
        var sliderChangeActions: [ObjectIdentifier: (Double) -> Void] = [:]
        /// Scroll viewport change handlers, keyed by ScrollViewer identity.
        /// Invoked on `viewChanging`/`viewChanged` so that lazy containers
        /// can rematerialize the visible slice while scrolling.
        var scrollViewportChangeHandlers: [ObjectIdentifier: (Double, Double) -> Void] = [:]
        var webViewNavigationStartingHandlers: [ObjectIdentifier: EventCleanup] = [:]
        var webViewNavigationCompletedHandlers: [ObjectIdentifier: EventCleanup] = [:]
        var webViewCoreInitializedHandlers: [ObjectIdentifier: EventCleanup] = [:]
        var applicationMenu: ([ResolvedMenu.Submenu], EnvironmentValues)?
        var textFieldChangeActions: [ObjectIdentifier: (String) -> Void] = [:]
        var textFieldSubmitActions: [ObjectIdentifier: () -> Void] = [:]
        var popoverDismissActions: [ObjectIdentifier: () -> Void] = [:]

        /// The context-menu flyout attached to each widget (keyed by widget
        /// identity). Rebuilt in-place on each update so that the
        /// `contextRequested` handler always reads the latest items.
        var contextMenuFlyouts: [ObjectIdentifier: WeakKeyed<MenuFlyout>] = [:]

        /// The signature of the items currently rendered into each widget's
        /// context-menu flyout, so unchanged menus aren't rebuilt on every
        /// commit (the rebuild walks the WinRT boundary per item).
        var contextMenuSignatures: [ObjectIdentifier: WeakKeyed<String>] = [:]

        /// The action boxes bound into each widget's rendered context-menu
        /// items, in render order. Updated on every update so that handlers
        /// invoke the latest closures even when the flyout isn't rebuilt.
        var contextMenuActions: [ObjectIdentifier: WeakKeyed<[ContextMenuActionBox]>] = [:]

        /// Widgets that already have a `rightTapped` context-menu handler
        /// attached.
        var contextMenuHooks: [ObjectIdentifier: WeakKeyed<Void>] = [:]

        /// Loaded `SvgImageSource`s keyed by image widget. Entries weakly
        /// reference the widget so address reuse can't match a stale source.
        var svgImageSources: [ObjectIdentifier: WeakSvgSource] = [:]

        /// The signature of the items currently rendered into each
        /// `Menu`-backed flyout, so unchanged menus aren't rebuilt on every
        /// commit (the rebuild walks the WinRT boundary per item).
        var popoverMenuSignatures: [ObjectIdentifier: WeakKeyed<String>] = [:]

        /// The action boxes bound into each `Menu`-backed flyout's items, in
        /// render order. Updated on every update so that handlers invoke the
        /// latest closures even when the flyout isn't rebuilt.
        var popoverMenuActions: [ObjectIdentifier: WeakKeyed<[ContextMenuActionBox]>] = [:]

        /// Memoized results of `size(of:whenDisplayedIn:...)` text
        /// measurements. Text measurement requires a real XAML `measure` call,
        /// which is expensive when every layout pass re-measures every
        /// `TextBlock` — the same (text, font, proposal) triples recur
        /// constantly.
        var textMeasurementCache: [TextMeasurementKey: SIMD2<Int>] = [:]

        /// The signature of the last environment applied to each TextBlock via
        /// `EnvironmentValues.apply(to:cachingIn:)`. Every property read in
        /// `apply` is a COM call (~10µs each), so skipping the whole update
        /// when the applied values are unchanged is worthwhile.
        var appliedTextBlockSignatures: [ObjectIdentifier: WeakKeyed<Int>] = [:]
    }

    /// A cache entry bound to the lifetime of a specific object. Keys are
    /// `ObjectIdentifier`s, which wrap a heap address that the allocator
    /// reuses for new objects once the old one is freed — a recycled address
    /// would otherwise match entries left behind by a dead object (e.g.
    /// skipping a fresh `TextBlock`'s font application or reusing a dead
    /// widget's flyout). The weak reference goes `nil` when its object dies,
    /// so stale entries always miss the ownership check.
    struct WeakKeyed<Value> {
        weak var object: AnyObject?
        var value: Value
    }

    struct TextMeasurementKey: Hashable {
        var text: String
        var font: Font.Resolved
        var proposedWidth: Int?
        var proposedHeight: Int?
        var lineLimit: LineLimit?
    }
    private var rootEnvironmentChangeHandler: (@Sendable @MainActor () -> Void)?

    var internalState: InternalState
    nonisolated(unsafe) private var dispatcherQueue: WinAppSDK.DispatcherQueue?

    var windows: [Window] = []

    private var measurementTextBlock: TextBlock!

    public convenience init() {
        self.init(urlSchemes: nil)
    }

    public init(urlSchemes: [String]?) {
        internalState = InternalState()
        WinUIApplication.urlSchemes.withLock { schemes in
            schemes = urlSchemes ?? []
        }
    }

    struct Error: LocalizedError {
        var message: String

        var errorDescription: String? {
            message
        }
    }

    public static func earlySetup() {
        do {
            try Self.attachToParentConsole()
        } catch {
            // We essentially just ignore if this fails because it's just a QoL
            // debugging feature, and if it fails then any warning we print likely
            // won't get seen anyway. But I don't trust my Windows knowledge enough
            // to assert that it's impossible to view logs on failure, so let's
            // print a warning anyway.
            logger.warning(
                "failed to attach to parent console",
                metadata: ["error": "\(error)"]
            )
        }
    }

    public func runMainLoop(_ callback: @escaping @MainActor () -> Void) {
        do {
            try Self.attachToParentConsole()
        } catch {
            // We essentially just ignore if this fails because it's just a QoL
            // debugging feature, and if it fails then any warning we print likely
            // won't get seen anyway. But I don't trust my Windows knowledge enough
            // to assert that it's impossible to view logs on failure, so let's
            // print a warning anyway.
            logger.warning(
                "failed to attach to parent console",
                metadata: ["error": "\(error)"]
            )
        }

        // Ensure that the app's windows adapt to DPI changes at runtime
        SetThreadDpiAwarenessContext(DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2)

        WinUIApplication.callback.withLock { launchCallback in
            launchCallback = { application, instance in
                // Keep the dispatcher running after the last window closes so
                // that transient gaps between `dismiss()` and `openWindow(...)`
                // (or just having no windows open) don't quit the app.
                application.dispatcherShutdownMode = .onExplicitShutdown

                // Log unhandled XAML exceptions to stderr before the default
                // FailFast terminates the process. This preserves diagnostics
                // (e.g. "Invalid attribute value Unknown for property X") that
                // would otherwise only be recoverable from crash dumps.
                _ = application.unhandledException.addHandler { (_, e) in
                    FileHandle.standardError.write(Data("UNHANDLED XAML EXCEPTION\n".utf8))
                    if let e {
                        FileHandle.standardError.write(
                            Data("  hr=\(String(e.exception, radix: 16))\n  msg=\(e.message)\n".utf8)
                        )
                    }
                }

                // Toggle Switch has annoying default 'internal margins' (not Control
                // margins that we can set directly) that we can luckily get rid of by
                // overriding the relevant resource values.
                _ = application.resources.insert("ToggleSwitchPreContentMargin", 0.0 as Double)
                _ = application.resources.insert("ToggleSwitchPostContentMargin", 0.0 as Double)

                // Handle theme changes
                UWP.UISettings().colorValuesChanged.addHandler { _, _ in
                    Task { @MainActor in
                        self.rootEnvironmentChangeHandler?()
                    }
                }

                // TODO: Read in previously hardcoded values from the application's
                // resources dictionary for future-proofing. Example code for getting
                // property values;
                //   let iinspectable =
                //       application.resources.lookup("ToggleSwitchPreContentMargin")!
                //       as! WindowsFoundation.IInspectable
                //   let pv: __ABI_Windows_Foundation.IPropertyValue = try! iinspectable.QueryInterface()
                //   let value = try! pv.GetDoubleImpl()

                self.measurementTextBlock = (self.createTextView() as! TextBlock)

                instance.activated.addHandler { (_, args: AppActivationArguments?) in
                    guard let args else {
                        logger.warning("Received activation with no activation arguments?")
                        return
                    }
                    self.processActivationArguments(args)
                }

                callback()
            }
        }
        WinUIApplication.main()
    }

    public func createWindow(withDefaultSize size: SIMD2<Int>?, id: String) -> Window {
        let window = CustomWindow()
        windows.append(window)
        window.closed.addHandler { _, _ in
            window.isClosed = true
            self.windows.removeAll { other in
                window === other
            }
        }

        if self.dispatcherQueue == nil {
            self.dispatcherQueue = window.dispatcherQueue
        }

        // import WinSDK
        // import CWinRT
        // @_spi(WinRTInternal) import WindowsFoundation
        // let minSizeHook: HOOKPROC = { (nCode: Int32, wParam: WPARAM, lParam: LPARAM) in
        //     if nCode >= 0 {
        //         let ptr = UnsafeRawPointer(bitPattern: Int(lParam))?
        //             .assumingMemoryBound(to: CWPRETSTRUCT.self)
        //         if let msgInfo = ptr?.pointee, msgInfo.message == WM_GETMINMAXINFO {
        //             print("Received WM_GETMINMAXINFO")

        //             // var value: HWND = .init(0)
        //             _ = try! window._inner.perform(
        //                 as: __x_ABI_CMicrosoft_CUI_CXaml_CIWindowNative.self
        //             ) { pThis in
        //                 try! CHECKED(pThis.pointee.lpVtbl.pointee.get_WindowHandle(pThis, nil))
        //             }
        //         }
        //     }
        //     return CallNextHookEx(nil, nCode, wParam, lParam)
        // }

        // _ = SetWindowsHookExW(WH_CALLWNDPROCRET, minSizeHook, nil, GetCurrentThreadId())
        // print("Registered")

        // print(GetDpiForWindow(nil))

        if let size {
            setSize(ofWindow: window, to: size)
        }
        window.applyPendingClientSize = { [weak self, weak window] in
            guard let self, let window, !window.isClosed else { return }
            self.applyPendingClientSize(of: window)
        }
        applyApplicationMenu(to: window)
        return window
    }

    public func updateWindow(_ window: Window, environment: EnvironmentValues) {
        window.updateChromeStripHeight()

        let backgroundColor: SwiftCrossUI.Color
        if let custom = environment.windowBackgroundColor {
            backgroundColor = custom
        } else {
            backgroundColor = switch environment.colorScheme {
                case .light: .white
                case .dark: .black
            }
        }
        let brush = WinUI.SolidColorBrush()
        brush.color = backgroundColor.resolve(in: environment).uwpColor
        window.grid.background = brush
    }

    public func size(ofWindow window: Window) -> SIMD2<Int> {
        let size = window.appWindow.clientSize
        let scaleFactor = window.scaleFactor
        let width = Double(size.width) / scaleFactor
        let height = Double(size.height) / scaleFactor
        let out = SIMD2(
            Int(width.rounded(.towardZero)),
            Int(height.rounded(.towardZero)) - window.contentHeightAdjustment
        )
        return out
    }

    public func isWindowProgrammaticallyResizable(_ window: Window) -> Bool {
        // TODO: Detect whether window is fullscreen
        return true
    }

    public func setSize(ofWindow window: Window, to newSize: SIMD2<Int>) {
        // AppWindow ignores resizes requested before the window has been
        // shown for the first time, so we defer them until activation.
        if !window.hasBeenShown {
            window.pendingClientSize = newSize
            return
        }
        let scaleFactor = window.scaleFactor
        let width = scaleFactor * Double(newSize.x)
        let height = scaleFactor * Double(newSize.y + window.contentHeightAdjustment)
        let size = UWP.SizeInt32(
            width: Int32(width.rounded(.towardZero)),
            height: Int32(height.rounded(.towardZero))
        )
        window.desiredClientSize = newSize
        // `resizeClient` occasionally gets dropped by AppWindow during window
        // activation, and can throw for stale windows. Failures are recovered
        // by the verification pass in `show`.
        try? window.appWindow.resizeClient(size)
    }

    /// Subclass ID for the `WM_GETMINMAXINFO` handler installed by
    /// `setSizeLimits` (arbitrary, unique per window).
    private static let minMaxSubclassID: UINT_PTR = 0x53594D58

    /// `AppWindow` exposes no min/max-size API, so limits are enforced by
    /// subclassing the window's `HWND` and answering `WM_GETMINMAXINFO`
    /// ourselves — this clamps the size *before* the resize happens, which
    /// also prevents the resize-fight flicker between the dragged size and
    /// the content's minimum.
    private static let windowMinMaxSubclassProc: SUBCLASSPROC = {
        hwnd, message, wParam, lParam, _, refData in
        // Let the default proc fill in the usual track bounds first.
        let result = DefSubclassProc(hwnd, message, wParam, lParam)
        guard message == WM_GETMINMAXINFO,
            let hwnd,
            refData != 0,
            let windowPointer = UnsafeRawPointer(bitPattern: UInt(refData)),
            let info = UnsafeMutablePointer<MINMAXINFO>(
                bitPattern: Int(bitPattern: UInt(lParam)))
        else { return result }
        let window = Unmanaged<CustomWindow>
            .fromOpaque(windowPointer)
            .takeUnretainedValue()

        // `ptMinTrackSize`/`ptMaxTrackSize` bound the whole window rect, so
        // measure the live non-client overhead (borders + any caption frame)
        // at the window's current DPI rather than guessing metrics.
        var windowRect = RECT()
        var clientRect = RECT()
        GetWindowRect(hwnd, &windowRect)
        GetClientRect(hwnd, &clientRect)
        let frameWidth =
            (windowRect.right - windowRect.left)
            - (clientRect.right - clientRect.left)
        let frameHeight =
            (windowRect.bottom - windowRect.top)
            - (clientRect.bottom - clientRect.top)

        let scale = window.scaleFactor
        let chrome = Double(window.contentHeightAdjustment) * scale
        func toWindowPixels(_ size: SIMD2<Int>) -> POINT {
            POINT(
                x: Int32(
                    (Double(size.x) * scale).rounded(.awayFromZero)) + frameWidth,
                y: Int32(
                    (Double(size.y) * scale + chrome).rounded(.awayFromZero))
                    + frameHeight
            )
        }
        if let minimum = window.minimumSizeLimit {
            info.pointee.ptMinTrackSize = toWindowPixels(minimum)
        }
        if let maximum = window.maximumSizeLimit {
            info.pointee.ptMaxTrackSize = toWindowPixels(maximum)
        }
        return result
    }

    public func setSizeLimits(
        ofWindow window: Window,
        minimum minimumSize: SIMD2<Int>,
        maximum maximumSize: SIMD2<Int>?
    ) {
        window.minimumSizeLimit = minimumSize
        window.maximumSizeLimit = maximumSize
        guard !window.minMaxSubclassInstalled, let hwnd = window.getHWND()
        else { return }
        window.minMaxSubclassInstalled = SetWindowSubclass(
            hwnd,
            Self.windowMinMaxSubclassProc,
            Self.minMaxSubclassID,
            DWORD_PTR(UInt(bitPattern: Unmanaged.passUnretained(window).toOpaque()))
        )
    }

    public func setResizeHandler(
        ofWindow window: Window,
        to action: @escaping (SIMD2<Int>) -> Void
    ) {
        window.sizeChanged.addHandler { _, args in
            // `WindowSizeChangedEventArgs.size` is already in DIPs (unlike
            // `AppWindow.clientSize` which is in physical pixels), so it must
            // not be divided by the scale factor again.
            let size = SIMD2(
                Int(Double(args!.size.width).rounded(.awayFromZero)),
                Int(Double(args!.size.height).rounded(.awayFromZero))
                    - window.contentHeightAdjustment
            )
            action(size)
        }
    }

    public func setTitle(ofWindow window: Window, to title: String) {
        window.title = title
    }

    public func setBehaviors(
        ofWindow window: Window,
        closable: Bool,
        minimizable: Bool,
        resizable: Bool
    ) {
        // Source: https://devblogs.microsoft.com/oldnewthing/20100604-00/?p=13803
        let hwnd = window.getHWND()!
        let flags = if closable { MF_ENABLED } else { MF_DISABLED | MF_GRAYED }
        EnableMenuItem(
            GetSystemMenu(hwnd, false),
            numericCast(SC_CLOSE),
            numericCast(MF_BYCOMMAND | flags)
        )

        (window.appWindow.presenter as? OverlappedPresenter)?.isMinimizable = minimizable
        (window.appWindow.presenter as? OverlappedPresenter)?.isResizable = resizable
        // A non-resizable window must not be maximizable either — otherwise
        // the maximize caption button (and double-click on the title bar)
        // would still blow it up to fullscreen.
        (window.appWindow.presenter as? OverlappedPresenter)?.isMaximizable = resizable
    }

    public func setChild(ofWindow window: Window, to widget: Widget) {
        window.setChild(widget)
        try! widget.updateLayout()
        widget.actualThemeChanged.addHandler { _, _ in
            Task { @MainActor in
                self.rootEnvironmentChangeHandler?()
            }
        }
    }

    /// The most recently shown window, used to parent system dialogs such as
    /// file pickers when no explicit anchor window is provided.
    internal static var lastShownWindow: Window?

    public func show(window: Window) {
        // `activate` fires the `activated` event synchronously, so the window
        // must be marked as shown first for the pending-size application in
        // that handler to go through.
        window.hasBeenShown = true
        activate(window: window)
        WinUIBackend.lastShownWindow = window
        // `resizeClient` is silently ignored until the window has been shown,
        // so resizes requested pre-activation are deferred to this point.
        applyPendingClientSize(of: window)
        // `resizeClient` can still be dropped by AppWindow in the moments
        // right after activation, so verify that the resize took effect and
        // retry a few times if it didn't.
        verifyClientSize(of: window, attemptsRemaining: 6)
    }

    private func verifyClientSize(
        of window: CustomWindow,
        attemptsRemaining: Int,
        stagnantChecks: Int = 0
    ) {
        guard attemptsRemaining > 0 else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(300)) {
            [weak self, weak window] in
            guard let self, let window, !window.isClosed,
                let desired = window.desiredClientSize
            else { return }
            // `appWindow.clientSize` reports the *requested* size, not what
            // the HWND actually received — when `resizeClient` is silently
            // dropped it reads as if the resize succeeded anyway. The real
            // client rect is the source of truth: a window stuck smaller
            // renders its content outside its input area (visible but
            // unclickable), so this must be caught and retried.
            guard let realPixels = self.realClientSizePixels(of: window) else {
                return
            }
            let scale = window.scaleFactor
            let desiredPixels = SIMD2(
                Int((Double(desired.x) * scale).rounded(.towardZero)),
                Int((Double(desired.y + window.contentHeightAdjustment) * scale)
                    .rounded(.towardZero))
            )
            guard abs(realPixels.x - desiredPixels.x) > 2
                || abs(realPixels.y - desiredPixels.y) > 2
            else { return }
            // Only conclude that AppWindow is clamping the request (e.g. to
            // the work area) after several consecutive unchanged readings —
            // otherwise we'd accept a wrong size while a resize was still in
            // flight.
            let stagnant = realPixels == window.lastVerifiedClientSize
                ? stagnantChecks + 1
                : 0
            if stagnant >= 3 {
                // `resizeClient` keeps reporting success without resizing the
                // HWND — push the size onto the HWND directly. The min/max
                // subclass clamps this to the permitted range automatically.
                self.applyClientSizeDirectly(to: window, desired: desired)
                return
            }
            window.lastVerifiedClientSize = realPixels
            self.setSize(ofWindow: window, to: desired)
            self.verifyClientSize(
                of: window,
                attemptsRemaining: attemptsRemaining - 1,
                stagnantChecks: stagnant
            )
        }
    }

    /// The window's real client size in physical pixels, measured on the
    /// HWND itself — unlike `appWindow.clientSize`, which can report a
    /// requested-but-unapplied size.
    private func realClientSizePixels(of window: CustomWindow) -> SIMD2<Int>? {
        guard let hwnd = window.getHWND() else { return nil }
        var rect = RECT()
        guard GetClientRect(hwnd, &rect) else { return nil }
        return SIMD2(Int(rect.right), Int(rect.bottom))
    }

    /// Resizes the window's HWND directly so its client area matches
    /// `desired` DIPs at the current scale factor. Used when AppWindow's
    /// `resizeClient` reports success but never resizes the HWND (its
    /// `clientSize` then echoes the request, hiding the failure).
    private func applyClientSizeDirectly(
        to window: CustomWindow,
        desired: SIMD2<Int>
    ) {
        guard let hwnd = window.getHWND() else { return }
        let scale = window.scaleFactor
        var windowRect = RECT()
        var clientRect = RECT()
        GetWindowRect(hwnd, &windowRect)
        GetClientRect(hwnd, &clientRect)
        let frameWidth =
            (windowRect.right - windowRect.left)
            - (clientRect.right - clientRect.left)
        let frameHeight =
            (windowRect.bottom - windowRect.top)
            - (clientRect.bottom - clientRect.top)
        let width =
            Int((Double(desired.x) * scale).rounded(.awayFromZero)) + Int(frameWidth)
        let height =
            Int((Double(desired.y + window.contentHeightAdjustment) * scale)
                .rounded(.awayFromZero)) + Int(frameHeight)
        SetWindowPos(
            hwnd,
            nil,
            0,
            0,
            Int32(width),
            Int32(height),
            UINT(SWP_NOMOVE | SWP_NOZORDER | SWP_NOACTIVATE)
        )
    }

    func applyPendingClientSize(of window: CustomWindow) {
        guard let pendingSize = window.pendingClientSize else { return }
        window.desiredClientSize = pendingSize
        setSize(ofWindow: window, to: pendingSize)
        window.pendingClientSize = nil
    }

    public func activate(window: Window) {
        do {
            try window.activate()
        } catch {
            logger.warning("Failed to activate window: \(error)")
        }
    }

    public func close(window: Window) {
        do {
            try window.close()
        } catch {
            logger.warning("Failed to close window: \(error)")
        }
    }

    public func setCloseHandler(
        ofWindow window: Window,
        to action: @escaping () -> Void
    ) {
        window.closed.addHandler { _, _ in
            action()
        }
    }

    public func openExternalURL(_ url: URL) throws {
        let promise = UWP.Launcher.launchUriAsync(WindowsFoundation.Uri(url.absoluteString))!
        let semaphore = DispatchSemaphore(value: 0)
        promise.completed = { _, status in
            semaphore.signal()

            if status != .completed {
                logger.warning("Failed to open external URL \(url)")
            }
        }

        // Block until the URL has been launched
        semaphore.wait()
    }

    public func runInMainThread(action: @escaping @MainActor () -> Void) {
        _ = try! dispatcherQueue!.tryEnqueue(.normal) {
            MainActor.assumeIsolated(action)
        }
    }

    public func show(widget _: Widget) {}

    /// The latest action/onChange closures of a rendered menu item. Click
    /// handlers capture the box rather than the closure so that the closures
    /// can be refreshed without rebuilding the flyout items.
    final class ContextMenuActionBox {
        var action: (@MainActor () -> Void)?
        var onChange: (@MainActor (Bool) -> Void)?
    }

    private func renderMenuItem(
        _ item: ResolvedMenu.Item,
        environment: EnvironmentValues,
        actionBoxes: inout [ContextMenuActionBox]
    ) -> MenuFlyoutItemBase {
        switch item {
            case .button(let label, let action):
                let widget = MenuFlyoutItem()
                widget.text = label
                let box = ContextMenuActionBox()
                box.action = action
                actionBoxes.append(box)
                widget.click.addHandler { _, _ in
                    box.action?()
                }
                widget.isEnabled = environment.isEnabled
                return widget
            case .toggle(let label, let value, let onChange):
                let widget = ToggleMenuFlyoutItem()
                widget.text = label
                widget.isChecked = value
                let box = ContextMenuActionBox()
                box.onChange = onChange
                actionBoxes.append(box)
                widget.click.addHandler { [weak widget] sender, _ in
                    let checked =
                        (sender as? ToggleMenuFlyoutItem)?.isChecked ?? widget?.isChecked
                    guard let checked else { return }
                    box.onChange?(checked)
                }
                widget.isEnabled = environment.isEnabled
                return widget
            case .separator:
                return MenuFlyoutSeparator()
            case .submenu(let submenu):
                let widget = MenuFlyoutSubItem()
                widget.text = submenu.label
                for subitem in submenu.content.items {
                    widget.items.append(
                        renderMenuItem(
                            subitem, environment: environment, actionBoxes: &actionBoxes)
                    )
                }
                return widget
            case .modifiedEnvironment(let item, let modification):
                return renderMenuItem(
                    item, environment: modification(environment), actionBoxes: &actionBoxes)
        }
    }

    /// A signature of the visible structure of a menu item: label, toggle
    /// state, enabled state, and submenu structure. Action closures are
    /// deliberately excluded — they're refreshed separately via
    /// ``ContextMenuActionBox``.
    private func contextMenuItemSignature(
        _ item: ResolvedMenu.Item,
        environment: EnvironmentValues
    ) -> String {
        let enabled = environment.isEnabled ? "1" : "0"
        switch item {
            case .button(let label, _):
                return "b\(enabled):\(label)"
            case .toggle(let label, let value, _):
                return "t\(enabled):\(label):\(value)"
            case .separator:
                return "s"
            case .submenu(let submenu):
                let inner = submenu.content.items.map {
                    contextMenuItemSignature($0, environment: environment)
                }.joined(separator: ",")
                return "m:\(submenu.label)(\(inner))"
            case .modifiedEnvironment(let item, let modification):
                return contextMenuItemSignature(
                    item, environment: modification(environment))
        }
    }

    /// Pushes the latest action/onChange closures into the boxes bound into
    /// already-rendered menu items, walking `items` in the same order they
    /// were rendered.
    private func refreshMenuItemActions(
        _ items: [ResolvedMenu.Item],
        boxes: [ContextMenuActionBox],
        index: inout Int
    ) {
        for item in items {
            switch item {
                case .button(_, let action):
                    if index < boxes.count { boxes[index].action = action }
                    index += 1
                case .toggle(_, _, let onChange):
                    if index < boxes.count { boxes[index].onChange = onChange }
                    index += 1
                case .separator:
                    break
                case .submenu(let submenu):
                    refreshMenuItemActions(submenu.content.items, boxes: boxes, index: &index)
                case .modifiedEnvironment(let item, _):
                    refreshMenuItemActions([item], boxes: boxes, index: &index)
            }
        }
    }

    public func setApplicationMenu(
        _ submenus: [ResolvedMenu.Submenu],
        environment: EnvironmentValues
    ) {
        // Stash the menu so that windows created later (e.g. via
        // `openWindow(id:)`) can populate their menu bars too.
        internalState.applicationMenu = (submenus, environment)

        // Each window gets its own menu items: a XAML element can only be the
        // child of a single parent.
        for window in windows {
            applyApplicationMenu(to: window)
        }
    }

    private func menuItemSignature(_ item: ResolvedMenu.Item) -> String {
        switch item {
            case .button(let label, _):
                return "b:\(label)"
            case .toggle(let label, let value, _):
                return "t:\(label):\(value)"
            case .separator:
                return "s"
            case .submenu(let submenu):
                let inner = submenu.content.items.map(menuItemSignature).joined(separator: ",")
                return "m:\(submenu.label)(\(inner))"
            case .modifiedEnvironment(let item, _):
                return "e(\(menuItemSignature(item)))"
        }
    }

    private func menuSignature(
        _ submenus: [ResolvedMenu.Submenu],
        environment: EnvironmentValues
    ) -> String {
        let inner = submenus.map { submenu in
            "\(submenu.label)(\(submenu.content.items.map(menuItemSignature).joined(separator: ",")))"
        }.joined(separator: "|")
        return "\(inner)#enabled:\(environment.isEnabled)"
    }

    func applyApplicationMenu(to window: CustomWindow) {
        guard let menu = internalState.applicationMenu,
            let appMenuButton = window.appMenuButton
        else { return }
        let (submenus, environment) = menu
        let signature = menuSignature(submenus, environment: environment)

        // Rebuilding the menu destroys the active flyout items: if a refresh
        // is triggered while a flyout is open (e.g. by another window's
        // activation), the clicked item may be released before its click
        // event is delivered. Skip the rebuild when nothing has changed —
        // unless the button has no flyout yet (a freshly attached button).
        guard signature != window.appliedMenuSignature || appMenuButton.flyout == nil
        else { return }
        window.appliedMenuSignature = signature

        let flyout = MenuFlyout()
        for (index, submenu) in submenus.enumerated() {
            if index > 0 {
                flyout.items.append(MenuFlyoutSeparator())
            }
            var actionBoxes: [ContextMenuActionBox] = []
            for subitem in submenu.content.items {
                flyout.items.append(
                    renderMenuItem(
                        subitem, environment: environment, actionBoxes: &actionBoxes)
                )
            }
        }
        appMenuButton.flyout = flyout
    }

    public func computeRootEnvironment(
        defaultEnvironment: EnvironmentValues
    ) -> EnvironmentValues {
        // Source: https://learn.microsoft.com/en-us/windows/apps/desktop/modernize/ui/apply-windows-themes#know-when-dark-mode-is-enabled
        let backgroundColor = try! UWP.UISettings().getColorValue(.background)

        let green = Int(backgroundColor.g)
        let red = Int(backgroundColor.r)
        let blue = Int(backgroundColor.b)
        let isLight = 5 * green + 2 * red + blue > 8 * 128

        let locale = Foundation.Locale.windowsCurrent

        return
            defaultEnvironment
                .with(\.colorScheme, isLight ? .light : .dark)
                .with(\.appPhase, windows.contains(where: \.isActive) ? .active : .inactive)
                .with(\.locale, locale)
                .with(\.calendar, locale.calendar)
    }

    public func setRootEnvironmentChangeHandler(
        to action: @escaping @Sendable @MainActor () -> Void
    ) {
        self.rootEnvironmentChangeHandler = action
    }

    public func computeWindowEnvironment(
        window: Window,
        rootEnvironment: EnvironmentValues
    ) -> EnvironmentValues {
        // TODO: Compute window scale factor (easy enough, but we would also have to keep
        //   it up-to-date then, which is kinda annoying for now)
        let titleBar = window.cachedAppWindow?.titleBar
        let scale = window.scaleFactor
        return rootEnvironment
            .with(\.scenePhase, window.isActive ? .active : .inactive)
            .with(\.windowChromeStripHeight, Double(titleBar?.height ?? 32) / scale)
            .with(
                \.windowCaptionLeadingInset,
                Double(titleBar?.leftInset ?? 0) / scale
            )
            .with(
                \.windowCaptionTrailingInset,
                Double(titleBar?.rightInset ?? 0) / scale
            )
    }

    public func setWindowEnvironmentChangeHandler(
        of window: Window,
        to action: @escaping @Sendable @MainActor () -> Void
    ) {
        // TODO: Notify when window scale factor changes

        // NB: This event fires when the window is activated _or_ deactivated.
        window.activated.addHandler { _, _ in
            if let rootHandler = self.rootEnvironmentChangeHandler {
                // Defer the refresh to the next dispatcher turn: `activated`
                // fires synchronously inside `activate()` (i.e. mid-window-
                // setup) and while menu flyouts are open. Rebuilding the
                // scene graph here reenters the activating window's own
                // `update` and tears down in-flight UI such as the clicked
                // menu item.
                _ = try? self.dispatcherQueue?.tryEnqueue(.normal) {
                    MainActor.assumeIsolated {
                        rootHandler()
                        // Don't bother calling `action` since this window's
                        // environment will be recomputed anyway.
                    }
                }
            } else {
                action()
            }
        }
    }

    var incomingURLHandler: ((URL) -> Void)?

    public func setIncomingURLHandler(to action: @escaping (URL) -> Void) {
        let isFirstCall = incomingURLHandler == nil
        self.incomingURLHandler = action

        if isFirstCall {
            // Check if this app instance was launched by a URL activation. If it
            // was a URL activation, then handle it now.
            let args = try! AppInstance.getCurrent().getActivatedEventArgs()!
            processActivationArguments(args)
        }
    }

    private func processActivationArguments(_ args: AppActivationArguments) {
        if args.kind == .protocol {
            if let data = args.data as? IProtocolActivatedEventArgs {
                let urlString = data.uri.absoluteUri
                if let url = URL(string: urlString) {
                    self.incomingURLHandler?(url)
                } else {
                    logger.warning("Failed to parse activation URL: \(urlString)")
                }
            } else {
                logger.warning("Failed to get activation URL")
            }
        }
    }

    public func createContainer() -> Widget {
        WinUI.Canvas()
    }

    public func removeAllChildren(of container: Widget) {
        let container = container as! WinUI.Canvas
        container.children.clear()
    }

    public func insert(_ child: Widget, into container: Widget, at index: Int) {
        let container = container as! WinUI.Canvas
        container.children.insertAt(UInt32(index), child)
    }

    public func swap(childAt firstIndex: Int, withChildAt secondIndex: Int, in container: Widget) {
        // TODO: Find out if there's an efficient way to do this without WinUI
        //   getting annoyed at us for having the same element in the list twice.
        let container = container as! WinUI.Canvas
        let largerIndex = UInt32(max(firstIndex, secondIndex))
        let smallerIndex = UInt32(min(firstIndex, secondIndex))
        let element1 = container.children[Int(smallerIndex)]
        let element2 = container.children[Int(largerIndex)]
        container.children.removeAt(largerIndex)
        container.children.removeAt(smallerIndex)
        container.children.insertAt(smallerIndex, element2)
        container.children.insertAt(largerIndex, element1)
    }

    public func remove(childAt index: Int, from container: Widget) {
        let container = container as! WinUI.Canvas
        container.children.removeAt(UInt32(index))
    }

    public func setPosition(ofChildAt index: Int, in container: Widget, to position: SIMD2<Int>) {
        let container = container as! WinUI.Canvas
        guard let child = container.children.getAt(UInt32(index)) else {
            logger.warning("child to set position of not found")
            return
        }

        // Attached property writes invalidate layout even when unchanged, so
        // skip redundant writes (see `setSize`).
        let left = Double(position.x)
        let top = Double(position.y)
        if WinUI.Canvas.getLeft(child) != left {
            WinUI.Canvas.setLeft(child, left)
        }
        if WinUI.Canvas.getTop(child) != top {
            WinUI.Canvas.setTop(child, top)
        }
    }

    public func createColorableRectangle() -> Widget {
        WinUI.Canvas()
    }

    public func setColor(
        ofColorableRectangle widget: Widget,
        to color: SwiftCrossUI.Color.Resolved
    ) {
        let canvas = widget as! WinUI.Canvas
        let brush = WinUI.SolidColorBrush()
        brush.color = color.uwpColor
        canvas.background = brush
    }

    public func createCornerRadiusContainer(wrapping child: Widget) -> Widget {
        child
    }

    public func setCornerRadius(of widget: Widget, to radius: Int) {
        guard
            let visual: WinAppSDK.Visual = try? widget.getVisualInternal(),
            let geometry = try? visual.compositor.createRoundedRectangleGeometry(),
            let clip = try? visual.compositor.createGeometricClip()
        else {
            logger.warning("failed to set corner radius: widget visual unavailable")
            return
        }

        geometry.cornerRadius = WindowsFoundation.Vector2(
            x: Float(radius),
            y: Float(radius)
        )

        // We assume that SwiftCrossUI has explicitly set the size of the
        // underlying widget.
        geometry.size = WindowsFoundation.Vector2(
            x: Float(widget.width),
            y: Float(widget.height)
        )

        clip.geometry = geometry

        visual.clip = clip

        // Keep the clip in sync when the widget is resized afterwards,
        // since the geometry size is only a snapshot of the current size.
        widget.sizeChanged.addHandler { _, args in
            guard let args else { return }
            geometry.size = WindowsFoundation.Vector2(
                x: Float(args.newSize.width),
                y: Float(args.newSize.height)
            )
        }
    }

    public func naturalSize(of widget: Widget) -> SIMD2<Int> {
        Self.naturalSize(of: widget)
    }

    /// A static version of `naturalSize(of:)` for convenience. Used by
    /// WinUIElementRepresentable.
    @MainActor
    public static func naturalSize(of widget: Widget) -> SIMD2<Int> {
        let allocation = WindowsFoundation.Size(
            width: .infinity,
            height: .infinity
        )

        // Some elements don't return any sort of sensible measurement before
        // they've been rendered. For said elements, we just compute their sizes
        // as best we can by roughly replicating WinUI's internal calculations.
        let noPadding = Thickness(left: 0, top: 0, right: 0, bottom: 0)
        if widget is WinUI.Slider {
            // As with buttons, slider sizing also doesn't work before the first
            // view update. The width and height I've hardcoded here were taken
            // from the WinUI source code: https://github.com/microsoft/microsoft-ui-xaml/blob/650b2c1bad272393400403ca323b3cb8745f95d0/src/controls/dev/CommonStyles/Slider_themeresources.xaml#L169
            return SIMD2(
                18 + 8,
                18 + 8
            )
        } else if widget is WinUI.ToggleSwitch {
            // WinUI sets the min-width of switches to 154 for whatever reason,
            // and I don't know how to override that default from Swift, so I'm
            // just hardcoding the size. This keeps getting jankier and
            // jankier...
            return SIMD2(
                40,
                20
            )
        } else if widget is CustomCheckBox {
            // WinUI sets quite a strange default size for checkboxes (with a
            // minimum width of 120), so we just hardcode the correct natural
            // size. The value 20 was taken from the WinUI source code:
            // https://github.com/microsoft/microsoft-ui-xaml/blob/d37afef65a0fc3219ba6b349301d685099fb129d/src/controls/dev/CommonStyles/CheckBox_themeresources.xaml#L270
            return SIMD2(20, 20)
        } else if let picker = widget as? CustomComboBox, picker.padding == noPadding {
            let label = TextBlock()
            let selectedIndex = max(Int(picker.selectedIndex), 0)
            label.text = picker.options.indices.contains(selectedIndex)
                ? picker.options[selectedIndex]
                : (picker.options.first ?? "")
            label.fontSize = picker.fontSize
            label.fontWeight = picker.fontWeight
            try! label.measure(allocation)

            // These padding values were gathered experimentally. I've found that
            // WinUI generally hardcodes padding, border thickness and such in its
            // default theme, so I feel it's safe enough to use this workaround for
            // now (until https://github.com/microsoft/microsoft-ui-xaml/issues/10278
            // gets an answer).
            let labelSize = label.desiredSize
            return SIMD2(
                Int(labelSize.width) + 50,
                // The default minimum picker height is 32 pixels
                max(Int(labelSize.height) + 12, 32)
            )
        } else if widget is ProgressRing {
            // ProgressRing appears to kind of grow to fill by default, but
            // SwiftCrossUI expects progress spinners to be fixed size, which
            // results in WinUI progress rings getting given astronomically
            // large fixed dimensions and causing crashes. To work around that,
            // we just override their 'natural size' to 32x32, which is based off
            // the defaults set in the following code from the WinUI repository:
            // https://github.com/marcelwgn/microsoft-ui-xaml/blob/ff21f9b212cea2191b959649e45e52486c8465aa/src/controls/dev/ProgressRing/ProgressRing.xaml#L12
            return SIMD2(32, 32)
        } else if let datePicker = widget as? CustomDatePicker {
            // CustomDatePicker is a StackPanel whose individual subviews need to be manually sized
            // and then added together. Its naturalSize(in:) method dispatches back here once for
            // each of its children.
            return datePicker.naturalSize()
        } else if widget is WinUI.DatePicker {
            // Width is 296:
            // https://github.com/marcelwgn/microsoft-ui-xaml/blob/ff21f9b212cea2191b959649e45e52486c8465aa/src/controls/dev/CommonStyles/DatePicker_themeresources.xaml#L261
            // Height is experimentally 29 which I don't see anywhere in that file.
            return SIMD2(296, 29)
        }

        let oldWidth = widget.width
        let oldHeight = widget.height
        defer {
            widget.width = oldWidth
            widget.height = oldHeight
        }

        widget.width = .nan
        widget.height = .nan

        try! widget.measure(allocation)

        let computedSize = widget.desiredSize
        let adjustment = sizeCorrection(for: widget)

        let out = SIMD2(
            Int(computedSize.width.rounded(.up)) + adjustment.x,
            Int(computedSize.height.rounded(.up)) + adjustment.y
        )

        return out
    }

    /// Some elements don't get their default padding/border applied until
    /// they've been rendered. For such elements we have to compute our own
    /// adjustment factors based off values taken from WinUI's default theme.
    /// We can detect such elements because their padding property will be set
    /// to zero until first render (and atm WinUIBackend doesn't set this padding
    /// property itself so this is a safe detection method).
    @MainActor
    public static func sizeCorrection(for widget: Widget) -> SIMD2<Int> {
        let adjustment: SIMD2<Int>
        let noPadding = Thickness(left: 0, top: 0, right: 0, bottom: 0)
        let computedSize = widget.desiredSize
        if let button = widget as? WinUI.Button, button.padding == noPadding {
            // WinUI buttons have padding, but the `padding` property returns
            // zero until the button has been rendered at least once. And even
            // if you manually set the button's padding, it gets ignored by
            // `measure()` before first render.
            //
            // The default in my Windows 11 VM seems to be 11 pixels either
            // side, 5 pixels above, and 6 pixels below. I found this hardcoded
            // in the WinUI repository, so hopefully it is the same everywhere...
            // Hardcoded here: https://github.com/microsoft/microsoft-ui-xaml/blob/650b2c1bad272393400403ca323b3cb8745f95d0/src/controls/dev/CommonStyles/Button_themeresources.xaml#L116
            //
            // We'll have to find a more dynamic way of correcting for WinUI's
            // measurement weirdness at some point (which will probably involve
            // figuring out how to access the `ButtonPadding` resource value
            // from Swift).
            //
            // Buttons seem to have 1 pixel of border on each side which also
            // gets ignored before first render.
            adjustment = SIMD2(
                11 + 11 + 2,
                5 + 6 + 2
            )
        } else if let toggleButton = widget as? WinUI.ToggleButton,
                  toggleButton.padding == noPadding
        {
            // See the above comment regarding Button. Very similar situation.
            adjustment = SIMD2(
                11 + 11 + 2,
                5 + 6 + 2
            )
        } else if let textField = widget as? TextBoxProtocol, textField.padding == noPadding {
            // The default padding applied to text boxes can be found here:
            // https://github.com/microsoft/microsoft-ui-xaml/blob/650b2c1bad272393400403ca323b3cb8745f95d0/src/controls/dev/CommonStyles/Common_themeresources.xaml#L12
            // However, text fields return 0x0 before rendering so our adjustment
            // just has to be the entire size of the text field. I've currently just
            // hardcoded a value obtained from one of my example apps.
            adjustment = SIMD2(64, 32)
        } else if widget is CalendarView {
            // I don't actually know why this is necessary, but without it the abbreviations for the
            // weekdays wrap, making it taller than it says it is. Value was derived by trial and
            // error.
            adjustment = SIMD2(20, 0)
        } else if
            computedSize.width == 0 && computedSize.height == 0 && widget is CalendarDatePicker
        {
            // I can't find any source on what the size of CalendarDatePicker is, but it reports 0x0
            // in at least some cases before initial render. In these cases, use a size derived
            // experimentally.
            adjustment = SIMD2(116, 32)
        } else {
            adjustment = .zero
        }
        return adjustment
    }

    public func setSize(of widget: Widget, to size: SIMD2<Int>) {
        // Writing width/height on a FrameworkElement invalidates XAML layout
        // even when the value is unchanged, so avoid redundant writes — this
        // gets called for every leaf widget on every view graph commit.
        let width = Double(max(size.x, 0))
        let height = Double(max(size.y, 0))
        if widget.width != width {
            widget.width = width
        }
        if widget.height != height {
            widget.height = height
        }
    }

    public func createTooltipContainer(wrapping child: Widget) -> Widget {
        // TODO(bbrk24): Look into removing the container, like on AppKit
        TooltipContainer(child: child)
    }

    public func updateTooltipContainer(_ widget: Widget, tooltip: String) {
        let widget = widget as! TooltipContainer
        widget.tooltip.content = tooltip
    }

    public func size(
        of text: String,
        whenDisplayedIn widget: Widget,
        proposedWidth: Int?,
        proposedHeight: Int?,
        environment: EnvironmentValues
    ) -> SIMD2<Int> {
        let cacheKey = TextMeasurementKey(
            text: text,
            font: environment.resolvedFont,
            proposedWidth: proposedWidth,
            proposedHeight: proposedHeight,
            lineLimit: environment.lineLimitSettings
        )
        if let cached = internalState.textMeasurementCache[cacheKey] {
            return cached
        }

        // Update the text view's environment and measure its desired line height
        updateTextView(measurementTextBlock, content: text, environment: environment)

        // Measure the text's size
        var size = Self.measure(
            measurementTextBlock,
            proposedWidth: proposedWidth,
            proposedHeight: proposedHeight
        )

        // TextBlocks measured outside the visual tree can slightly
        // underreport their width once hosted (especially for text requiring
        // font fallback such as CJK). Pad the measured width by a DIP so that
        // rendered text doesn't get ellipsised at exactly its measured width.
        if !text.isEmpty, proposedWidth == nil || size.x < proposedWidth! {
            size.x += 1
        }

        var usedHeight = size.y
        let lineHeight = environment.resolvedFont.lineHeight

        if let lineLimitSettings = environment.lineLimitSettings {
            let height = Int(
                Double(max(lineLimitSettings.limit, 1)) * lineHeight
            )

            if height < usedHeight || lineLimitSettings.reservesSpace {
                usedHeight = height
            }
        }

        // Make sure the text doesn't get shorter than a single line of text even if
        // it's empty.
        size.y = max(usedHeight, Int(lineHeight))
        internalState.textMeasurementCache[cacheKey] = size
        return size
    }

    private static func measure(
        _ textBlock: TextBlock,
        proposedWidth: Int?,
        proposedHeight: Int?
    ) -> SIMD2<Int> {
        let allocation = WindowsFoundation.Size(
            width: proposedWidth.map(Float.init) ?? .infinity,
            height: proposedHeight.map(Float.init) ?? .infinity
        )
        try! textBlock.measure(allocation)

        let computedSize = textBlock.desiredSize
        return SIMD2(
            Int(computedSize.width.rounded(.up)),
            Int(computedSize.height.rounded(.up))
        )
    }

    public func createTextView() -> Widget {
        let textBlock = TextBlock()
        textBlock.textWrapping = .wrap
        textBlock.textTrimming = .characterEllipsis
        textBlock.lineStackingStrategy = .blockLineHeight
        return textBlock
    }

    public func updateTextView(
        _ textView: Widget,
        content: String,
        environment: EnvironmentValues
    ) {
        let block = textView as! TextBlock
        // This gets called for every Text view on every layout pass (not just
        // commits), so skip property writes whose values are unchanged —
        // writes invalidate XAML layout/measure even when assigned the
        // existing value.
        if block.text != content {
            block.text = content
        }
        if block.isTextSelectionEnabled != environment.isTextSelectionEnabled {
            block.isTextSelectionEnabled = environment.isTextSelectionEnabled
        }
        // TODO: Font design handling (monospace vs normal)
        environment.apply(to: block, cachingIn: internalState)
    }

    public func createSimpleButton() -> Widget {
        let button = WinUI.Button()
        button.click.addHandler { [weak internalState] _, _ in
            guard let internalState else { return }
            internalState.buttonClickActions[ObjectIdentifier(button)]?()
        }
        return button
    }

    public func updateSimpleButton(
        _ button: Widget,
        label: String,
        environment: EnvironmentValues,
        action: @escaping () -> Void
    ) {
        let button = button as! WinUI.Button

        // Reassigning `content` swaps the visual child, resetting the
        // button's PointerOver state mid-hover — reuse the existing
        // TextBlock when possible so hover stays stable across commits.
        if let block = button.content as? WinUI.TextBlock {
            if block.text != label {
                block.text = label
            }
            environment.apply(to: block, cachingIn: internalState)
        } else {
            let block = createTextView() as! WinUI.TextBlock
            block.text = label
            environment.apply(to: block, cachingIn: internalState)
            button.content = block
        }

        environment.apply(to: button)
        internalState.buttonClickActions[ObjectIdentifier(button)] = action
    }

    public func createPopoverMenu() -> Menu {
        let flyout = MenuFlyout()
        flyout.placement = .bottomEdgeAlignedLeft
        return flyout
    }

    public func updatePopoverMenu(
        _ menu: Menu,
        content: ResolvedMenu,
        environment: EnvironmentValues
    ) {
        let id = ObjectIdentifier(menu)
        let signature = content.items.map {
            contextMenuItemSignature($0, environment: environment)
        }.joined(separator: "|")

        let sigEntry = internalState.popoverMenuSignatures[id]
        if sigEntry?.object !== menu || sigEntry?.value != signature {
            internalState.popoverMenuSignatures[id] =
                WeakKeyed(object: menu, value: signature)
            var actionBoxes: [ContextMenuActionBox] = []
            menu.items.clear()
            for item in content.items {
                menu.items.append(
                    renderMenuItem(item, environment: environment, actionBoxes: &actionBoxes))
            }
            internalState.popoverMenuActions[id] = WeakKeyed(object: menu, value: actionBoxes)
        } else if let actionBoxes = internalState.popoverMenuActions[id],
            actionBoxes.object === menu
        {
            var index = 0
            refreshMenuItemActions(content.items, boxes: actionBoxes.value, index: &index)
        }
    }

    public func setContextMenu(
        on widget: Widget,
        items: ResolvedMenu?,
        environment: EnvironmentValues
    ) {
        let id = ObjectIdentifier(widget)

        guard let items else {
            internalState.contextMenuFlyouts.removeValue(forKey: id)
            internalState.contextMenuSignatures.removeValue(forKey: id)
            internalState.contextMenuActions.removeValue(forKey: id)
            if widget.contextFlyout != nil {
                widget.contextFlyout = nil
            }
            return
        }

        let signature = items.items.map {
            contextMenuItemSignature($0, environment: environment)
        }.joined(separator: "|")

        let flyoutEntry = internalState.contextMenuFlyouts[id]
        let flyout = (flyoutEntry?.object === widget ? flyoutEntry?.value : nil) ?? MenuFlyout()
        internalState.contextMenuFlyouts[id] = WeakKeyed(object: widget, value: flyout)

        let sigEntry = internalState.contextMenuSignatures[id]
        if sigEntry?.object !== widget || sigEntry?.value != signature {
            internalState.contextMenuSignatures[id] =
                WeakKeyed(object: widget, value: signature)
            var actionBoxes: [ContextMenuActionBox] = []
            flyout.items.clear()
            for item in items.items {
                flyout.items.append(
                    renderMenuItem(item, environment: environment, actionBoxes: &actionBoxes)
                )
            }
            internalState.contextMenuActions[id] =
                WeakKeyed(object: widget, value: actionBoxes)
        } else if let actionBoxes = internalState.contextMenuActions[id],
            actionBoxes.object === widget
        {
            var index = 0
            refreshMenuItemActions(items.items, boxes: actionBoxes.value, index: &index)
        }

        // `UIElement.contextFlyout` doesn't reliably auto-show in XAML
        // islands (the `contextRequested` gesture doesn't reach us), so show
        // the flyout from `rightTapped` instead. The event bubbles from the
        // deepest element up, so the innermost context-menu'd view wins; its
        // handler marks the event handled which prevents ancestors from
        // re-showing their own menus.
        if internalState.contextMenuHooks[id]?.object !== widget {
            internalState.contextMenuHooks[id] = WeakKeyed(object: widget, value: ())
            widget.rightTapped.addHandler { [weak internalState, weak widget] _, args in
                guard
                    let internalState,
                    let widget,
                    let menu = internalState.contextMenuFlyouts[ObjectIdentifier(widget)],
                    menu.object === widget,
                    let args,
                    !args.handled,
                    let position = try? args.getPosition(widget)
                else { return }

                try? menu.value.showAt(widget, position)
                args.handled = true
            }
        }
    }

    public func updateButton(
        _ button: Widget,
        label: String,
        menu: Menu,
        environment: EnvironmentValues
    ) {
        let button = button as! WinUI.Button

        if let block = button.content as? WinUI.TextBlock {
            if block.text != label {
                block.text = label
            }
            environment.apply(to: block, cachingIn: internalState)
        } else {
            let block = createTextView() as! WinUI.TextBlock
            block.text = label
            environment.apply(to: block, cachingIn: internalState)
            button.content = block
        }

        environment.apply(to: button)
        if button.flyout !== menu {
            button.flyout = menu
        }
    }

    public func setButtonMenu(
        _ button: Widget,
        menu: Menu,
        environment: EnvironmentValues
    ) {
        let button = button as! WinUI.Button
        environment.apply(to: button)
        button.flyout = menu
    }

    public func createScrollContainer(for child: Widget) -> Widget {
        let scrollViewer = WinUI.ScrollViewer()
        scrollViewer.content = child
        child.horizontalAlignment = .left
        child.verticalAlignment = .top
        scrollViewer.viewChanging.addHandler { [weak internalState, weak scrollViewer] _, args in
            guard let internalState, let scrollViewer else { return }
            internalState.scrollViewportChangeHandlers[ObjectIdentifier(scrollViewer)]?(
                args?.nextView?.verticalOffset ?? scrollViewer.verticalOffset,
                scrollViewer.viewportHeight
            )
        }
        scrollViewer.viewChanged.addHandler { [weak internalState, weak scrollViewer] _, _ in
            guard let internalState, let scrollViewer else { return }
            internalState.scrollViewportChangeHandlers[ObjectIdentifier(scrollViewer)]?(
                scrollViewer.verticalOffset,
                scrollViewer.viewportHeight
            )
        }
        return scrollViewer
    }

    public func updateScrollContainer(
        _ scrollView: Widget,
        environment: EnvironmentValues,
        bounceHorizontally: Bool,
        bounceVertically: Bool,
        hasHorizontalScrollBar: Bool,
        hasVerticalScrollBar: Bool
    ) {
        guard let scrollViewer = scrollView as? WinUI.ScrollViewer else {
            logger.warning(
                "updateScrollContainer called on non-ScrollViewer widget \(type(of: scrollView))"
            )
            return
        }

        scrollViewer.isHorizontalRailEnabled = hasHorizontalScrollBar
        scrollViewer.horizontalScrollMode = hasHorizontalScrollBar ? .enabled : .disabled
        scrollViewer.horizontalScrollBarVisibility = hasHorizontalScrollBar ? .visible : .hidden

        scrollViewer.isVerticalRailEnabled = hasVerticalScrollBar
        scrollViewer.verticalScrollMode = hasVerticalScrollBar ? .enabled : .disabled
        scrollViewer.verticalScrollBarVisibility = hasVerticalScrollBar ? .visible : .hidden
    }

    public func setScrollViewportChangeHandler(
        _ scrollView: Widget,
        handler: @escaping @MainActor (Double, Double) -> Void
    ) {
        internalState.scrollViewportChangeHandlers[ObjectIdentifier(scrollView)] = handler
    }

    class CustomListView: WinUI.ListView {
        var selectionHandler: ((_ selectedIndex: Int) -> Void)?
        var currentItems: [WinUI.ListViewItem] = []
        var cachedSelectedItem: Int? = nil
    }

    public func createSelectableListView() -> Widget {
        let listView = CustomListView()
        listView.selectionMode = .single
        listView.selectionChanged.addHandler { [weak listView] _, _ in
            guard let listView else { return }
            guard listView.selectedRanges.count > 0 else {
                return
            }
            let selection = Int(listView.selectedRanges[0]!.firstIndex)
            guard selection != listView.cachedSelectedItem else {
                return
            }
            listView.selectionHandler?(selection)
        }
        return listView
    }

    public func updateSelectableListView(
        _ selectableListView: Widget,
        environment: EnvironmentValues
    ) {
        let listView = selectableListView as! CustomListView
        listView.isEnabled = environment.isEnabled
    }

    public func baseItemPadding(ofSelectableListView listView: Widget) -> EdgeInsets {
        EdgeInsets(
            top: 8,
            leading: 16,
            bottom: 8,
            trailing: 12
        )
    }

    public func minimumRowSize(ofSelectableListView listView: Widget) -> SIMD2<Int> {
        SIMD2(
            80,
            40
        )
    }

    public func setItems(
        ofSelectableListView listView: Widget,
        to items: [Widget],
        withRowHeights rowHeights: [Int]
    ) {
        let listView = listView as! CustomListView
        listView.itemContainerTransitions.clear()

        for listItem in listView.currentItems {
            listItem.content = nil
        }

        if items.count != listView.currentItems.count {
            listView.items.clear()
        }

        // We add the new items to the list but also to `listView.currentItems`.
        // This is so that we can retrieve the correct list item instances in
        // setSelectedItem. If we just use `listView.items` instead we get separate
        // incorrect instances for whatever reason (symptom is that it crashes stuff).
        var listItems: [WinUI.ListViewItem] = []
        for (index, item) in items.enumerated() {
            let listItem: WinUI.ListViewItem
            if items.count == listView.currentItems.count {
                listItem = listView.currentItems[index]
            } else {
                listItem = WinUI.ListViewItem()
            }
            listItem.horizontalContentAlignment = .left
            listItem.content = item
            listItem.padding = Thickness(left: 16, top: 8, right: 12, bottom: 8)
            if items.count != listView.currentItems.count {
                listItems.append(listItem)
                listView.items.append(listItem)
            }
        }

        if items.count != listView.currentItems.count {
            listView.currentItems = listItems
            listView.cachedSelectedItem = nil
        }
    }

    public func setSelectionHandler(
        forSelectableListView listView: Widget,
        to action: @escaping (_ selectedIndex: Int) -> Void
    ) {
        let listView = listView as! CustomListView
        listView.selectionHandler = action
    }

    public func setSelectedItem(
        ofSelectableListView listView: Widget,
        toItemAt index: Int?
    ) {
        let listView = listView as! CustomListView
        guard index != listView.cachedSelectedItem else {
            return
        }
        listView.cachedSelectedItem = index
        if let index {
            // We use `listView.currentItems` instead of `listView.items` because
            // `listView.items` isn't the original instances we added and WinUI
            // doesn't like that.
            listView.selectedItem = listView.currentItems[index]
        } else {
            listView.selectedItem = nil
        }
    }

    public func createSlider() -> Widget {
        let slider = Slider()
        slider.valueChanged.addHandler { [weak internalState, weak slider] _, event in
            guard
                let internalState,
                let slider
            else { return }

            internalState.sliderChangeActions[ObjectIdentifier(slider)]?(
                Double(event?.newValue ?? 0)
            )
        }
        slider.stepFrequency = 0.01
        return slider
    }

    public func updateSlider(
        _ slider: Widget,
        minimum: Double,
        maximum: Double,
        decimalPlaces _: Int,
        environment: EnvironmentValues,
        onChange: @escaping (Double) -> Void
    ) {
        let slider = slider as! WinUI.Slider
        slider.minimum = minimum
        slider.maximum = maximum
        environment.apply(to: slider)
        internalState.sliderChangeActions[ObjectIdentifier(slider)] = onChange
    }

    public func setValue(ofSlider slider: Widget, to value: Double) {
        let slider = slider as! WinUI.Slider
        slider.value = value
    }

    public func createPicker(style: BackendPickerStyle) -> Widget {
        switch style {
            case .menu:
                let picker = CustomComboBox()
                picker.selectionChanged.addHandler { [weak picker] _, _ in
                    guard let picker else { return }
                    picker.onChangeSelection?(Int(picker.selectedIndex))
                }

                // When hovering over a picker, its foreground changes to black,
                // when the pointer exits the picker the foreground color remains
                // black instead of returning to its regular value. I've tried various
                // variations of the solution below and it seems like the only thing
                // that works is fully recreating the brush.
                picker.pointerExited.addHandler { [weak picker] _, _ in
                    guard let picker else { return }
                    let brush = SolidColorBrush()
                    brush.color = picker.actualForegroundColor
                    picker.foreground = brush
                }

                return picker
            case .radioGroup:
                let picker = CustomRadioButtons()

                picker.selectionChanged.addHandler { [weak picker] _, _ in
                    guard let picker else { return }
                    picker.onChangeSelection?(
                        picker.selectedIndex == -1 ? nil : Int(picker.selectedIndex)
                    )
                }

                return picker
            default:
                let message = "unsupported picker style \(style)"
                logger.critical("\(message)")
                fatalError(message)
        }
    }

    public func updatePicker(
        _ picker: Widget,
        options: [String],
        environment: EnvironmentValues,
        onChange: @escaping (Int?) -> Void
    ) {
        if let picker = picker as? CustomComboBox {
            picker.onChangeSelection = onChange
            environment.apply(to: picker)
            picker.actualForegroundColor =
                environment.suggestedForegroundColor.resolve(in: environment).uwpColor

            // Only update options past this point, otherwise the early return
            // will cause issues.
            guard options.count > 0 else {
                picker.options = []
                return
            }

            if options.count == picker.items.count {
                // for i in 0 ..< options.count {
                // TODO: Understands how to get ComboBox items in WinUI
                // if picker.items.getAt(UInt32(i)) as? String != options[i] {
                // picker.items.setAt(UInt32(1), options[i])
                // }
                // }
            } else if options.count > picker.items.count {
                if !picker.items.isEmpty {
                    for i in 0..<picker.items.count {
                        // if picker.items.getAt(UInt32(i)) as? String != options[i] {
                        picker.items.setAt(UInt32(i), options[i])
                        // }
                    }
                }
                for i in picker.items.count..<options.count {
                    picker.items.append(options[i])
                }
            } else {
                for i in 0..<options.count {
                    // if picker.items.getAt(UInt32(i)) as? String != options[i] {
                    picker.items.setAt(UInt32(i), options[i])
                    // }
                }
                for i in options.count..<picker.items.count {
                    picker.items.removeAt(UInt32(i))
                }
            }

            // TODO: Proper picker updating logic
            // TODO: Picker font handling

            picker.options = options
        } else if let picker = picker as? CustomRadioButtons {
            for i in 0..<min(picker.items.count, options.count) {
                (picker.items[i] as! TextBlock).text = options[i]
            }

            if picker.items.count > options.count {
                for i in (options.count..<picker.items.count).reversed() {
                    _ = picker.items.remove(at: i)
                }
            } else {
                for option in options[picker.items.count...] {
                    let block = TextBlock()
                    block.text = option
                    environment.apply(to: block, cachingIn: internalState)
                    picker.items.append(block)
                }
            }

            picker.onChangeSelection = onChange
        }
    }

    public func setSelectedOption(ofPicker picker: Widget, to selectedOption: Int?) {
        if let picker = picker as? ComboBox {
            picker.selectedIndex = Int32(selectedOption ?? 0)
        } else if let picker = picker as? RadioButtons {
            picker.selectedIndex = Int32(selectedOption ?? -1)
        }
    }

    public func createTextEditor() -> Widget {
        let textEditor = TextBox()
        textEditor.textChanged.addHandler { [weak internalState, weak textEditor] _, _ in
            guard
                let internalState,
                let textEditor
            else { return }
            guard !textEditor.shouldBlockNextChangedSignal else {
                textEditor.shouldBlockNextChangedSignal = false
                return
            }
            // Reuse this storage because it's the same widget type as a text field
            internalState.textFieldChangeActions[ObjectIdentifier(textEditor)]?(textEditor.text)
        }
        textEditor.acceptsReturn = true
        textEditor.textWrapping = .wrap

        // Remove padding
        textEditor.padding = Thickness(left: 0, top: 0, right: 0, bottom: 0)

        // Remove border, background and the focused/hover visual states so
        // the editor reads as bare text (consistent with .plain TextFields).
        applyPlainTextControlChrome(to: textEditor)

        return textEditor
    }

    public func updateTextEditor(
        _ textEditor: Widget,
        environment: EnvironmentValues,
        onChange: @escaping (String) -> Void
    ) {
        let textEditor = (textEditor as! TextBox)
        internalState.textFieldChangeActions[ObjectIdentifier(textEditor)] = onChange
        environment.apply(to: textEditor)

        updateInputScope(of: textEditor, textContentType: environment.textContentType)
    }

    public func setContent(ofTextEditor textEditor: Widget, to content: String) {
        let textEditor = textEditor as! TextBox
        textEditor.shouldBlockNextChangedSignal = true
        textEditor.text = content
    }

    public func getContent(ofTextEditor textEditor: Widget) -> String {
        (textEditor as! TextBox).text
    }

    func updateInputScope(
        of textField: some TextBoxProtocol,
        textContentType: TextContentType
    ) {

        let inputScope: InputScopeNameValue? =
            switch textField {
                case is TextBox:
                    switch textContentType {
                        case .decimal(_): .number
                        case .digits(_): .digits
                        case .emailAddress: .emailSmtpAddress
                        case .name: .personalFullName
                        case .phoneNumber: .telephoneNumber
                        case .text: .default
                        case .url: .url
                    }
                case is PasswordBox:
                    switch textContentType {
                        case .digits(_): .numericPin
                        case .text: .password
                        default: nil
                    }
                default: nil
            }
        guard let inputScope else { return }

        let inputScopeName = InputScopeName(inputScope)

        if let inputScope = textField.inputScope,
           inputScope.names.count == 1
        {
            inputScope.names[0] = inputScopeName
        } else {
            let inputScope = InputScope()
            inputScope.names.append(inputScopeName)
            textField.inputScope = inputScope
        }
    }

    public func tag(widget: Widget, as tag: String) {
        WinUI.AutomationProperties.setName(widget, tag)
    }

    public func createImageView() -> Widget {
        let imageView = WinUI.Image()
        // Match AppKit's `.scaleAxesIndependently`: the layout system sizes
        // the element's frame and the bitmap stretches to fill it.
        imageView.stretch = .fill
        return imageView
    }

    public func updateImageView(
        _ imageView: Widget,
        rgbaData: [UInt8],
        width: Int,
        height: Int,
        targetWidth: Int,
        targetHeight: Int,
        dataHasChanged: Bool,
        environment: EnvironmentValues
    ) {
        // The bitmap's pixels only depend on rgbaData — the Image element
        // stretches to fit its layout slot via `stretch = .fill`, so a pure
        // resize (targetWidth/Height change) doesn't require re-uploading the
        // pixel data. Rebuilding a WriteableBitmap costs a full buffer copy
        // plus a per-pixel RGBA→BGRA swizzle on the UI thread, so skip it
        // whenever the pixel data is unchanged (matches the other backends).
        guard dataHasChanged else { return }

        let imageView = imageView as! WinUI.Image
        imageView.source = Self.writeableBitmap(
            rgbaData: rgbaData,
            width: width,
            height: height
        )
    }

    /// Builds a `WriteableBitmap` from straight RGBA pixels, converting to the
    /// premultiplied BGRA the pixel format expects — storing straight RGBA
    /// makes every partially-transparent pixel look washed out.
    static func writeableBitmap(
        rgbaData: [UInt8],
        width: Int,
        height: Int
    ) -> WriteableBitmap {
        let bitmap = WriteableBitmap(Int32(width), Int32(height))
        let buffer = try! bitmap.pixelBuffer.buffer!
        memcpy(buffer, rgbaData, min(Int(bitmap.pixelBuffer.length), rgbaData.count))
        for i in 0..<(width * height) {
            let offset = i * 4
            let r = UInt32(buffer[offset])
            let g = UInt32(buffer[offset + 1])
            let b = UInt32(buffer[offset + 2])
            let a = UInt32(buffer[offset + 3])
            // (+127) keeps `x * a / 255` close to the true value.
            buffer[offset] = UInt8((b * a + 127) / 255)
            buffer[offset + 1] = UInt8((g * a + 127) / 255)
            buffer[offset + 2] = UInt8((r * a + 127) / 255)
        }
        return bitmap
    }

    public func createSplitView(leadingChild: Widget, trailingChild: Widget) -> Widget {
        let splitView = CustomSplitView()
        splitView.pane = leadingChild
        splitView.content = trailingChild
        splitView.isPaneOpen = true
        splitView.displayMode = .inline
        // Match the AppKit backend's defaultLeadingWidth of 200.
        splitView.openPaneLength = 200
        // The default pane brush is `SystemControlBackgroundChromeMediumLow`,
        // which reads as a mismatched grey when the content side paints the
        // app's own background. Let the window background show through so
        // the pane and content share one colour family.
        splitView.paneBackground = WinUI.SolidColorBrush(
            UWP.Color(a: 0, r: 0, g: 0, b: 0))
        return splitView
    }

    public func setResizeHandler(
        ofSplitView splitView: Widget,
        to action: @escaping () -> Void
    ) {
        let splitView = splitView as! CustomSplitView
        splitView.sidebarResizeHandler = action
    }

    public func sidebarWidth(ofSplitView splitView: Widget) -> Int {
        let splitView = splitView as! CustomSplitView
        return Int(splitView.openPaneLength.rounded(.towardZero))
    }

    public func setSidebarWidthBounds(
        ofSplitView splitView: Widget,
        minimum minimumWidth: Int,
        maximum maximumWidth: Int
    ) {
        let splitView = splitView as! CustomSplitView
        splitView.sidebarMinimumLength = Double(max(minimumWidth, 0))
        splitView.sidebarMaximumLength = Double(max(maximumWidth, minimumWidth))
        // A closed pane has no width to clamp — and clamping `openPaneLength`
        // back to a nonzero minimum would fight `setSidebarWidth(0)` in an
        // update loop (each mutation fires `sidebarResizeHandler` which
        // schedules another commit). Reopening goes through `setSidebarWidth`,
        // which sets the width directly.
        guard splitView.isPaneOpen else { return }
        // WinUI's SplitView has no separate resize bounds — `openPaneLength`
        // is both the current width and the only control. Match the other
        // backends' semantics where setting bounds only constrains the pane
        // rather than resizing it, by clamping the current width into range.
        let newWidth = min(
            max(splitView.openPaneLength, splitView.sidebarMinimumLength),
            splitView.sidebarMaximumLength
        )
        if newWidth != splitView.openPaneLength {
            splitView.openPaneLength = newWidth
            splitView.sidebarResizeHandler?()
        }
    }

    public func setSidebarWidth(
        ofSplitView splitView: Widget,
        to width: Int
    ) {
        let splitView = splitView as! CustomSplitView
        let newWidth = max(0, Double(width))
        splitView.isPaneOpen = newWidth > 0
        if newWidth != splitView.openPaneLength {
            splitView.openPaneLength = newWidth
            splitView.sidebarResizeHandler?()
        }
    }

    public func setSplitViewPaneOnTrailingEdge(
        _ splitView: Widget,
        to isOnTrailingEdge: Bool
    ) {
        guard let splitView = splitView as? CustomSplitView else { return }
        splitView.panePlacement = isOnTrailingEdge ? .right : .left
    }

    public func createToggle() -> Widget {
        let toggle = ToggleButton()
        toggle.click.addHandler { [weak internalState] _, _ in
            guard let internalState else { return }
            internalState.toggleClickActions[ObjectIdentifier(toggle)]?(toggle.isChecked ?? false)
        }
        return toggle
    }

    public func updateToggle(
        _ toggle: Widget,
        label: String,
        environment: EnvironmentValues,
        onChange: @escaping (Bool) -> Void
    ) {
        let toggle = toggle as! ToggleButton
        let block = TextBlock()
        block.text = label
        toggle.content = block

        // Use opposite color scheme for label if checked to match WinUI's default
        // behaviour.
        environment.with(
            \.colorScheme,
            toggle.isChecked == true
                ? environment.colorScheme.opposite
                : environment.colorScheme
        ).apply(to: block)

        environment.apply(to: toggle)

        internalState.toggleClickActions[ObjectIdentifier(toggle)] = { state in
            onChange(state)

            // Update label color scheme just in case the update doesn't get
            // propagated back to us (e.g. if the user passes in a dummy binding)
            environment.with(
                \.colorScheme,
                state ? environment.colorScheme.opposite : environment.colorScheme
            ).apply(to: block)
        }
    }

    public func setState(ofToggle toggle: Widget, to state: Bool) {
        let toggle = toggle as! ToggleButton
        toggle.isChecked = state
    }

    public func createToggle(wrapping widget: Widget) -> Widget {
        let toggle = ToggleButton()
        toggle.content = widget
        toggle.click.addHandler { [weak internalState] _, _ in
            guard let internalState else { return }
            internalState.toggleClickActions[ObjectIdentifier(toggle)]?(toggle.isChecked ?? false)
        }
        return toggle
    }

    public func updateToggle(
        _ toggle: Widget,
        environment: EnvironmentValues,
        onChange: @escaping (Bool) -> Void
    ) {
        let toggle = toggle as! ToggleButton
        environment.apply(to: toggle)
        internalState.toggleClickActions[ObjectIdentifier(toggle)] = onChange
    }

    public func createSwitch() -> Widget {
        let toggleSwitch = ToggleSwitch()
        toggleSwitch.offContent = ""
        toggleSwitch.onContent = ""
        toggleSwitch.padding = Thickness(left: 0, top: 0, right: 0, bottom: 0)
        toggleSwitch.toggled.addHandler { [weak internalState] _, _ in
            guard let internalState else { return }
            internalState.switchClickActions[ObjectIdentifier(toggleSwitch)]?(toggleSwitch.isOn)
        }
        return toggleSwitch
    }

    public func updateSwitch(
        _ toggleSwitch: Widget,
        environment: EnvironmentValues,
        onChange: @escaping (Bool) -> Void
    ) {
        let toggleSwitch = toggleSwitch as! ToggleSwitch
        internalState.switchClickActions[ObjectIdentifier(toggleSwitch)] = onChange
        environment.apply(to: toggleSwitch)
    }

    public func setState(ofSwitch switchWidget: Widget, to state: Bool) {
        let switchWidget = switchWidget as! ToggleSwitch
        if switchWidget.isOn != state {
            switchWidget.isOn = state
        }
    }

    class CustomCheckBox: WinUI.CheckBox {
        var onToggle: ((Bool) -> Void)?

        func handleToggle() {
            if isChecked == nil {
                logger.warning("checkbox in limbo")
            }
            onToggle?(isChecked ?? false)
        }
    }

    public func createCheckbox() -> Widget {
        let checkbox = CustomCheckBox()

        // This natural size is hardcoded, but it's the actual visible size of
        // the checkbox. WinUI puts a bunch of extra space around checkboxes
        // by default which messes things up.
        let naturalSize = naturalSize(of: checkbox)
        checkbox.minWidth = Double(naturalSize.x)
        checkbox.minHeight = Double(naturalSize.y)

        checkbox.padding = Thickness(left: 0, top: 0, right: 0, bottom: 0)
        checkbox.checked.addHandler { [weak checkbox] _, _ in
            checkbox?.handleToggle()
        }
        checkbox.unchecked.addHandler { [weak checkbox] _, _ in
            checkbox?.handleToggle()
        }
        return checkbox
    }

    public func updateCheckbox(
        _ checkbox: Widget,
        environment: EnvironmentValues,
        onChange: @escaping (Bool) -> Void
    ) {
        let checkbox = checkbox as! CustomCheckBox
        checkbox.padding = Thickness(left: 0, top: 0, right: 0, bottom: 0)
        checkbox.onToggle = onChange
        environment.apply(to: checkbox)
    }

    public func setState(ofCheckbox checkboxWidget: Widget, to state: Bool) {
        let checkboxWidget = checkboxWidget as! CustomCheckBox
        if checkboxWidget.isChecked != state {
            checkboxWidget.isChecked = state
        }
    }

    public func showOpenDialog(
        fileDialogOptions: FileDialogOptions,
        openDialogOptions: OpenDialogOptions,
        window: Window?,
        resultHandler handleResult: @escaping (DialogResult<[URL]>) -> Void
    ) {
        let picker = FileOpenPicker()

        let window = window ?? windows[0]
        let hwnd = window.getHWND()!

        if openDialogOptions.allowSelectingDirectories && !openDialogOptions.allowSelectingFiles {
            let folderPicker = FolderPicker()
            let folderInterface: SwiftIInitializeWithWindow =
                try! folderPicker.thisPtr.QueryInterface()
            try! folderInterface.initialize(with: hwnd)
            folderPicker.fileTypeFilter.append("*")
            let promise = try! folderPicker.pickSingleFolderAsync()!
            promise.completed = { operation, status in
                let result: DialogResult<[URL]> = Self.handleAsyncOperationCompletion(
                    operation,
                    status
                ) { result in
                    return .success([URL(fileURLWithPath: result.path)])
                } onFailure: {
                    return .cancelled
                }
                handleResult(result)
            }
            return
        }

        let interface: SwiftIInitializeWithWindow = try! picker.thisPtr.QueryInterface()
        try! interface.initialize(with: hwnd)

        picker.fileTypeFilter.append("*")

        if openDialogOptions.allowMultipleSelections {
            let promise = try! picker.pickMultipleFilesAsync()!
            promise.completed = { operation, status in
                let result: DialogResult<[URL]> = Self.handleAsyncOperationCompletion(
                    operation,
                    status
                ) { result in
                    let files = Array(result).compactMap { $0 }
                        .map(\.path)
                        .map(URL.init(fileURLWithPath:))
                    return .success(files)
                } onFailure: {
                    return .cancelled
                }
                handleResult(result)
            }
        } else {
            let promise = try! picker.pickSingleFileAsync()!
            promise.completed = { operation, status in
                let result: DialogResult<[URL]> = Self.handleAsyncOperationCompletion(
                    operation,
                    status
                ) { result in
                    let file = URL(fileURLWithPath: result.path)
                    return .success([file])
                } onFailure: {
                    return .cancelled
                }
                handleResult(result)
            }
        }
    }

    public func showSaveDialog(
        fileDialogOptions: FileDialogOptions,
        saveDialogOptions: SaveDialogOptions,
        window: Window?,
        resultHandler handleResult: @escaping (DialogResult<URL>) -> Void
    ) {
        let picker = FileSavePicker()

        let window = window ?? windows[0]
        let hwnd = window.getHWND()!
        let interface: SwiftIInitializeWithWindow = try! picker.thisPtr.QueryInterface()
        try! interface.initialize(with: hwnd)

        _ = picker.fileTypeChoices.insert("Text", [".txt"].toVector())
        let promise = try! picker.pickSaveFileAsync()!
        promise.completed = { operation, status in
            let result: DialogResult<URL> = Self.handleAsyncOperationCompletion(
                operation,
                status
            ) { result in
                let file = URL(fileURLWithPath: result.path)
                return .success(file)
            } onFailure: {
                return .cancelled
            }
            handleResult(result)
        }
    }

    /// A helper method that abstracts out the common failure case handling code
    /// from all of our file dialog related async operation completion handlers.
    private static func handleAsyncOperationCompletion<T, R>(
        _ operation: AnyIAsyncOperation<T?>?,
        _ status: AsyncStatus,
        onSuccess handleSuccess: (T) -> R,
        onFailure handleFailure: () -> R
    ) -> R {
        guard let operation else {
            logger.warning(
                "operation parameter unexpectedly nil",
                metadata: [
                    "function": #function
                ]
            )
            return handleFailure()
        }

        guard
            status == .completed,
            let result = try? operation.getResults()
        else {
            if status == .error {
                logger.error(
                    "\(WindowsFoundation.Error(hr: operation.errorCode))",
                    metadata: [
                        "function": #function
                    ]
                )

                if UInt32(bitPattern: operation.errorCode) == 0x80004005 {
                    // https://github.com/microsoft/WindowsAppSDK/issues/4625#issuecomment-2281358235
                    logger.warning(
                        """
                        This may indicate that you're attempting to launch a \
                        file picker from an app launched as administrator
                        """
                    )
                }
            }
            return handleFailure()
        }

        return handleSuccess(result)
    }

    public func createTapGestureTarget(wrapping child: Widget, gesture: TapGesture) -> Widget {
        if gesture != .primary {
            fatalError("Unsupported gesture type \(gesture)")
        }
        let tapGestureTarget = TapGestureTarget()
        insert(child, into: tapGestureTarget, at: 0)
        tapGestureTarget.child = child

        // Set a background so that the click target's entire area gets hit
        // tested. The background we set is transparent so that it doesn't
        // change the visual appearance of the view.
        let brush = SolidColorBrush()
        brush.color = UWP.Color(a: 0, r: 0, g: 0, b: 0)
        tapGestureTarget.background = brush

        tapGestureTarget.pointerPressed.addHandler { [weak tapGestureTarget] _, _ in
            guard let tapGestureTarget else { return }
            tapGestureTarget.clickHandler?()
        }
        return tapGestureTarget
    }

    public func updateTapGestureTarget(
        _ tapGestureTarget: Widget,
        gesture: TapGesture,
        environment: EnvironmentValues,
        action: @escaping () -> Void
    ) {
        if gesture != .primary {
            fatalError("Unsupported gesture type \(gesture)")
        }
        let tapGestureTarget = tapGestureTarget as! TapGestureTarget
        tapGestureTarget.clickHandler = environment.isEnabled ? action : {}
    }

    public func createHoverTarget(wrapping child: Widget) -> Widget {
        let hoverTarget = HoverGestureTarget()
        insert(child, into: hoverTarget, at: 0)
        hoverTarget.child = child

        // Ensure the hover target covers the full area of the child.
        // Use a transparent background so the visual appearance doesn't change but
        // the hit-testing covers the whole region.
        let brush = SolidColorBrush()
        brush.color = UWP.Color(a: 0, r: 0, g: 0, b: 0)
        hoverTarget.background = brush

        hoverTarget.pointerEntered.addHandler { [weak hoverTarget] _, _ in
            guard let hoverTarget else { return }
            hoverTarget.enterHandler?()
        }
        hoverTarget.pointerExited.addHandler { [weak hoverTarget] _, _ in
            guard let hoverTarget else { return }
            hoverTarget.exitHandler?()
        }
        return hoverTarget
    }

    public func updateHoverTarget(
        _ hoverTarget: Widget,
        environment: EnvironmentValues,
        action: @escaping (Bool) -> Void
    ) {
        let hoverTarget = hoverTarget as! HoverGestureTarget
        hoverTarget.enterHandler = environment.isEnabled ? { action(true) } : {}
        hoverTarget.exitHandler = environment.isEnabled ? { action(false) } : {}
    }

    public func createProgressSpinner() -> Widget {
        let spinner = ProgressRing()
        spinner.isIndeterminate = true
        return spinner
    }

    public func createProgressBar() -> Widget {
        let progressBar = ProgressBar()
        progressBar.maximum = 10_000
        return progressBar
    }

    public func updateProgressBar(
        _ widget: Widget,
        progressFraction: Double?,
        environment: EnvironmentValues
    ) {
        let progressBar = widget as! ProgressBar
        if let progressFraction {
            progressBar.isIndeterminate = false
            progressBar.value = progressBar.maximum * progressFraction
        } else {
            progressBar.isIndeterminate = true
        }

        if let tint = environment.tintColor {
            let brush = SolidColorBrush()
            brush.color = tint.resolve(in: environment).uwpColor
            progressBar.foreground = brush
        }
    }

    public func createPathWidget() -> Widget {
        WinUI.Path()
    }

    public func createPath() -> Path {
        GeometryGroupHolder()
    }

    public func updatePath(
        _ path: Path,
        _ source: SwiftCrossUI.Path,
        bounds: SwiftCrossUI.Path.Rect,
        pointsChanged: Bool,
        environment: EnvironmentValues
    ) {
        path.strokeStyle = source.strokeStyle

        if pointsChanged {
            path.group.children.clear()
            applyActions(source.actions, to: path.group.children)
        }

        path.group.fillRule =
            switch source.fillRule {
                case .evenOdd:
                    .evenOdd
                case .winding:
                    .nonzero
            }
    }

    func requirePathFigure(
        _ collection: WinUI.GeometryCollection,
        lastPoint: Point
    ) -> PathFigure {
        var pathGeometry: PathGeometry
        if collection.size > 0,
           let castedLast = collection.getAt(collection.size - 1) as? PathGeometry
        {
            pathGeometry = castedLast
        } else {
            pathGeometry = PathGeometry()
            collection.append(pathGeometry)
        }

        var figure: PathFigure
        if pathGeometry.figures.size > 0 {
            // Note: the if check and force-unwrap is necessary. You can't do an `if let`
            // here because PathFigureCollection uses unsigned integers for its indices so
            // `size - 1` would underflow (causing a fatalError) if it's empty.
            figure = pathGeometry.figures.getAt(pathGeometry.figures.size - 1)!
        } else {
            figure = PathFigure()
            figure.startPoint = lastPoint
            pathGeometry.figures.append(figure)
        }

        return figure
    }

    func applyActions(_ actions: [SwiftCrossUI.Path.Action], to geometry: WinUI.GeometryCollection)
    {
        var lastPoint = Point(x: 0.0, y: 0.0)

        for action in actions {
            switch action {
                case .moveTo(let point):
                    lastPoint = Point(x: Float(point.x), y: Float(point.y))

                    if geometry.size > 0,
                       let pathGeometry = geometry.getAt(geometry.size - 1) as? PathGeometry,
                       pathGeometry.figures.size > 0
                    {
                        let figure = pathGeometry.figures.getAt(pathGeometry.figures.size - 1)!
                        if figure.segments.size > 0 {
                            let newFigure = PathFigure()
                            newFigure.startPoint = lastPoint
                            pathGeometry.figures.append(newFigure)
                        } else {
                            figure.startPoint = lastPoint
                        }
                    }
                case .lineTo(let point):
                    let wfPoint = Point(x: Float(point.x), y: Float(point.y))
                    defer { lastPoint = wfPoint }

                    let figure = requirePathFigure(geometry, lastPoint: lastPoint)

                    let segment = LineSegment()
                    segment.point = wfPoint
                    figure.segments.append(segment)
                case .quadCurve(let control, let end):
                    let wfControl = Point(x: Float(control.x), y: Float(control.y))
                    let wfEnd = Point(x: Float(end.x), y: Float(end.y))
                    defer { lastPoint = wfEnd }

                    let figure = requirePathFigure(geometry, lastPoint: lastPoint)

                    let segment = QuadraticBezierSegment()
                    segment.point1 = wfControl
                    segment.point2 = wfEnd
                    figure.segments.append(segment)
                case .cubicCurve(let control1, let control2, let end):
                    let wfControl1 = Point(x: Float(control1.x), y: Float(control1.y))
                    let wfControl2 = Point(x: Float(control2.x), y: Float(control2.y))
                    let wfEnd = Point(x: Float(end.x), y: Float(end.y))
                    defer { lastPoint = wfEnd }

                    let figure = requirePathFigure(geometry, lastPoint: lastPoint)

                    let segment = BezierSegment()
                    segment.point1 = wfControl1
                    segment.point2 = wfControl2
                    segment.point3 = wfEnd
                    figure.segments.append(segment)
                case .rectangle(let rect):
                    let rectGeo = RectangleGeometry()
                    rectGeo.rect = Rect(
                        x: Float(rect.x),
                        y: Float(rect.y),
                        width: Float(rect.width),
                        height: Float(rect.height)
                    )
                    geometry.append(rectGeo)
                case .circle(let center, let radius):
                    let ellipse = EllipseGeometry()
                    ellipse.radiusX = radius
                    ellipse.radiusY = radius
                    ellipse.center = Point(x: Float(center.x), y: Float(center.y))
                    geometry.append(ellipse)
                case .arc(
                let center,
                let radius,
                let startAngle,
                let endAngle,
                let clockwise
            ):
                    let startPoint = Point(
                        x: Float(center.x + radius * cos(startAngle)),
                        y: Float(center.y + radius * sin(startAngle))
                    )
                    let endPoint = Point(
                        x: Float(center.x + radius * cos(endAngle)),
                        y: Float(center.y + radius * sin(endAngle))
                    )
                    defer { lastPoint = endPoint }

                    let figure = requirePathFigure(geometry, lastPoint: lastPoint)

                    if startPoint != lastPoint {
                        if figure.segments.size > 0 {
                            let connector = LineSegment()
                            connector.point = startPoint
                            figure.segments.append(connector)
                        } else {
                            figure.startPoint = startPoint
                        }
                    }

                    let segment = ArcSegment()

                    if clockwise {
                        if startAngle < endAngle {
                            segment.isLargeArc = (endAngle - startAngle > .pi)
                        } else {
                            segment.isLargeArc = (startAngle - endAngle < .pi)
                        }
                        segment.sweepDirection = .clockwise
                    } else {
                        if startAngle < endAngle {
                            segment.isLargeArc = (endAngle - startAngle < .pi)
                        } else {
                            segment.isLargeArc = (startAngle - endAngle > .pi)
                        }
                        segment.sweepDirection = .counterclockwise
                    }

                    segment.point = endPoint
                    segment.size = Size(width: Float(radius), height: Float(radius))

                    figure.segments.append(segment)
                case .transform(let transform):
                    let matrixTransform = MatrixTransform()
                    matrixTransform.matrix = Matrix(
                        m11: transform.linearTransform.x,
                        m12: transform.linearTransform.z,
                        m21: transform.linearTransform.y,
                        m22: transform.linearTransform.w,
                        offsetX: transform.translation.x,
                        offsetY: transform.translation.y
                    )

                    for case let geo? in geometry {
                        if geo.transform == nil {
                            geo.transform = matrixTransform
                        } else if let group = geo.transform as? TransformGroup {
                            group.children.append(matrixTransform)
                        } else {
                            let group = TransformGroup()
                            group.children.append(geo.transform)
                            group.children.append(matrixTransform)
                            geo.transform = group
                        }
                    }

                    if geometry.size > 0,
                       let pathGeometry = geometry.getAt(geometry.size - 1) as? PathGeometry,
                       pathGeometry.figures.contains(where: { ($0?.segments.size ?? 0) > 0 })
                    {
                        // Start a new PathGeometry so that transforms don't apply going forward
                        geometry.append(PathGeometry())
                    }
                case .subpath(let actions):
                    let subGeo = GeometryGroup()
                    applyActions(actions, to: subGeo.children)
                    geometry.append(subGeo)
            }
        }

        // Cleanup: remove empty paths
        // Having empty paths in the geometry group causes rendering it to silently crash
        for i in (0..<geometry.size).reversed() {
            if let pathGeo = geometry.getAt(i) as? PathGeometry,
               pathGeo.figures.size == 0
            {
                geometry.removeAt(i)
            }
        }
    }

    public func renderPath(
        _ path: Path,
        container: Widget,
        strokeColor: SwiftCrossUI.Color.Resolved,
        fillColor: SwiftCrossUI.Color.Resolved,
        overrideStrokeStyle: StrokeStyle?
    ) {
        let winUiPath = container as! WinUI.Path
        let strokeStyle = overrideStrokeStyle ?? path.strokeStyle!

        // XAML hit-tests a shape wherever its fill or stroke brush is
        // non-null — even a fully transparent brush registers. Leave the
        // brush null for unpainted channels so transparent overlays (e.g.
        // stroke-only borders, clear fills) don't swallow pointer input that
        // should reach controls underneath.
        winUiPath.fill =
            fillColor.opacity > 0 ? WinUI.SolidColorBrush(fillColor.uwpColor) : nil
        winUiPath.stroke =
            strokeColor.opacity > 0 && strokeStyle.width > 0
            ? WinUI.SolidColorBrush(strokeColor.uwpColor) : nil
        winUiPath.strokeThickness = strokeStyle.width

        switch strokeStyle.cap {
            case .butt:
                winUiPath.strokeStartLineCap = .flat
                winUiPath.strokeEndLineCap = .flat
            case .round:
                winUiPath.strokeStartLineCap = .round
                winUiPath.strokeEndLineCap = .round
            case .square:
                winUiPath.strokeStartLineCap = .square
                winUiPath.strokeEndLineCap = .square
        }

        switch strokeStyle.join {
            case .miter(let limit):
                winUiPath.strokeMiterLimit = limit
                winUiPath.strokeLineJoin = .miter
            case .round:
                winUiPath.strokeLineJoin = .round
            case .bevel:
                winUiPath.strokeLineJoin = .bevel
        }

        winUiPath.data = path.group
    }

    public func createDatePicker() -> Widget {
        return CustomDatePicker()
    }

    public func updateDatePicker(
        _ datePicker: Widget,
        environment: EnvironmentValues,
        date: Date,
        range: ClosedRange<Date>,
        components: DatePickerComponents,
        onChange: @escaping (Date) -> Void
    ) {
        let customDatePicker = datePicker as! CustomDatePicker

        if components.contains(.hourMinuteAndSecond) {
            print(
                "DatePickerComponents.hourMinuteAndSecond is not supported in WinUIBackend. Falling back to .hourAndMinute."
            )
        }

        customDatePicker.toggleTimeView(shown: components.contains(.hourAndMinute))

        if environment.timeZone != .current {
            print("environment.timeZone is has no effect in WinUIBackend.")
        }

        let dateViewType: CustomDatePicker.DateViewType.Discriminator? =
            if components.contains(.date) {
                switch environment.datePickerStyle {
                    case .automatic, .wheel:
                        .datePicker
                    case .compact:
                        .calendarDatePicker
                    case .graphical:
                        .calendarView
                }
            } else {
                nil
            }

        customDatePicker.onChange = onChange
        customDatePicker.changeDateView(to: dateViewType)
        customDatePicker.updateIfNeeded(date: date, calendar: environment.calendar)
        customDatePicker.setDateRange(to: range)
        customDatePicker.setEnabled(to: environment.isEnabled)

        // TODO(parity): foreground color ignored
        // Setting foreground like for other views works for TimePicker and DatePicker but not for
        // CalendarView or CalendarDatePicker.
    }

    // public func createTable(rows: Int, columns: Int) -> Widget {
    //     let grid = Grid()
    //     grid.columnSpacing = 10
    //     grid.rowSpacing = 10
    //     for _ in 0..<rows {
    //         let rowDefinition = RowDefinition()
    //         rowDefinition.height = GridLength(value: 0, gridUnitType: .auto)
    //         grid.rowDefinitions.append(rowDefinition)
    //     }

    //     for _ in 0..<columns {
    //         let columnDefinition = ColumnDefinition()
    //         columnDefinition.width = GridLength(value: 0, gridUnitType: .auto)
    //         grid.columnDefinitions.append(columnDefinition)
    //     }
    //     return grid
    // }

    // public func setRowCount(ofTable table: Widget, to rows: Int) {
    //     let grid = table as! Grid
    //     grid.rowDefinitions.clear()
    //     for _ in 0..<rows {
    //         let rowDefinition = RowDefinition()
    //         rowDefinition.height = GridLength(value: 0, gridUnitType: .auto)
    //         grid.rowDefinitions.append(rowDefinition)
    //     }
    // }

    // public func setColumnCount(ofTable table: Widget, to columns: Int) {
    //     let grid = table as! Grid
    //     grid.columnDefinitions.clear()
    //     for _ in 0..<columns {
    //         let columnDefinition = ColumnDefinition()
    //         columnDefinition.width = GridLength(value: 0, gridUnitType: .auto)
    //         grid.columnDefinitions.append(columnDefinition)
    //     }
    // }

    // public func setCell(at position: CellPosition, inTable table: Widget, to widget: Widget) {
    //     let grid = table as! Grid
    //     Grid.setColumn(widget, Int32(position.column))
    //     Grid.setRow(widget, Int32(position.row))
    //     grid.children.append(widget)
    // }
}

extension EnvironmentValues {
    @MainActor
    var winUIForegroundBrush: WinUI.Brush {
        let brush = SolidColorBrush()
        brush.color = suggestedForegroundColor.resolve(in: self).uwpColor
        return brush
    }

    @MainActor
    func apply(to control: WinUI.Control) {
        let resolvedFont = resolvedFont
        // Guard every write: this runs per control per layout pass and a new
        // brush instance is never equal to the old one, so unconditional
        // writes fire PropertyChanged (and invalidate PointerOver visuals)
        // even when nothing changed.
        if control.fontSize != resolvedFont.pointSize {
            control.fontSize = resolvedFont.pointSize
        }
        if control.fontWeight.weight != resolvedFont.winUIFontWeight {
            control.fontWeight.weight = resolvedFont.winUIFontWeight
        }
        let foregroundColor = suggestedForegroundColor.resolve(in: self).uwpColor
        if let brush = control.foreground as? SolidColorBrush, brush.color == foregroundColor {
        } else {
            control.foreground = winUIForegroundBrush
        }
        if control.isEnabled != isEnabled {
            control.isEnabled = isEnabled
        }
        let fontStyle: UWP.FontStyle = resolvedFont.isItalic ? .italic : .normal
        if control.fontStyle != fontStyle {
            control.fontStyle = fontStyle
        }
        if case .named(let family) = resolvedFont.identifier.kind {
            if control.fontFamily?.source != family {
                control.fontFamily = WinUI.FontFamily(family)
            }
        } else if control.fontFamily != nil {
            _ = try? control.clearValue(WinUI.Control.fontFamilyProperty)
        }
        let theme: WinUI.ElementTheme =
            switch colorScheme {
                case .light: .light
                case .dark: .dark
            }
        if control.requestedTheme != theme {
            control.requestedTheme = theme
        }
    }

    @MainActor
    func apply(to textBlock: WinUI.TextBlock) {
        apply(to: textBlock, cachingIn: nil)
    }

    @MainActor
    func apply(to textBlock: WinUI.TextBlock, cachingIn internalState: WinUIBackend.InternalState?) {
        let resolvedFont = resolvedFont
        let foregroundColor = suggestedForegroundColor.resolve(in: self).uwpColor
        if let internalState {
            var hasher = Hasher()
            hasher.combine(resolvedFont.pointSize)
            hasher.combine(resolvedFont.winUIFontWeight)
            hasher.combine(resolvedFont.lineHeight)
            hasher.combine(resolvedFont.isItalic)
            if case .named(let family) = resolvedFont.identifier.kind {
                hasher.combine(family)
            }
            hasher.combine(foregroundColor.r)
            hasher.combine(foregroundColor.g)
            hasher.combine(foregroundColor.b)
            hasher.combine(foregroundColor.a)
            let signature = hasher.finalize()
            let id = ObjectIdentifier(textBlock)
            if let entry = internalState.appliedTextBlockSignatures[id],
                entry.object === textBlock, entry.value == signature
            {
                return
            }
            internalState.appliedTextBlockSignatures[id] =
                WinUIBackend.WeakKeyed(object: textBlock, value: signature)
        }
        // Guard every write: this runs per Text view per layout pass, and
        // XAML invalidates on writes even when the value is unchanged.
        if textBlock.fontSize != resolvedFont.pointSize {
            textBlock.fontSize = resolvedFont.pointSize
        }
        if textBlock.fontWeight.weight != resolvedFont.winUIFontWeight {
            textBlock.fontWeight.weight = resolvedFont.winUIFontWeight
        }
        if let brush = textBlock.foreground as? SolidColorBrush, brush.color == foregroundColor {
        } else {
            textBlock.foreground = winUIForegroundBrush
        }
        if textBlock.lineHeight != resolvedFont.lineHeight {
            textBlock.lineHeight = resolvedFont.lineHeight
        }

        let fontStyle: UWP.FontStyle = resolvedFont.isItalic ? .italic : .normal
        if textBlock.fontStyle != fontStyle {
            textBlock.fontStyle = fontStyle
        }
        // A `.system` font keeps the default family: clearing an explicitly
        // set family restores it (the family persists if only assigned when
        // the resolved font is named).
        if case .named(let family) = resolvedFont.identifier.kind {
            if textBlock.fontFamily?.source != family {
                textBlock.fontFamily = WinUI.FontFamily(family)
            }
        } else if textBlock.fontFamily != nil {
            _ = try? textBlock.clearValue(WinUI.TextBlock.fontFamilyProperty)
        }
    }
}

extension Font.Resolved {
    var winUIFontWeight: UInt16 {
        switch weight {
            case .ultraLight:
                100
            case .thin:
                200
            case .light:
                300
            case .regular:
                400
            case .medium:
                500
            case .semibold:
                600
            case .bold:
                700
            case .heavy:
                800
            case .black:
                900
        }
    }
}

final class CustomComboBox: ComboBox {
    var options: [String] = []
    var onChangeSelection: ((Int?) -> Void)?
    var actualForegroundColor: UWP.Color = UWP.Color(a: 255, r: 0, g: 0, b: 0)
}

final class CustomRadioButtons: RadioButtons {
    var onChangeSelection: ((Int?) -> Void)?
}

final class CustomSplitView: SplitView {
    var sidebarResizeHandler: (() -> Void)?
    /// The bounds most recently applied by `setSidebarWidthBounds`, mirrored
    /// here so the divider drag clamps to the same range.
    var sidebarMinimumLength = 0.0
    var sidebarMaximumLength = Double.infinity
    private var dividerDragStart: (x: Double, length: Double)?
    private lazy var resizeCursor = WinAppSDK.InputSystemCursor.create(.sizeWestEast)

    /// Half the width of the divider's hit zone, in DIPs.
    private static let dividerHitHalfWidth = 6.0

    private func dividerX() -> Double {
        panePlacement == .right
            ? actualWidth - openPaneLength
            : openPaneLength
    }

    private func isOverDivider(_ e: PointerRoutedEventArgs?) -> Bool {
        guard isPaneOpen,
            let point = try? e?.getCurrentPoint(self)
        else { return false }
        return abs(Double(point.position.x) - dividerX()) <= Self.dividerHitHalfWidth
    }

    override func onPointerPressed(_ e: PointerRoutedEventArgs!) throws {
        if isOverDivider(e), let point = try? e.getCurrentPoint(self) {
            dividerDragStart = (Double(point.position.x), openPaneLength)
            _ = try? capturePointer(e.pointer)
            e.handled = true
            return
        }
        try super.onPointerPressed(e)
    }

    override func onPointerMoved(_ e: PointerRoutedEventArgs!) throws {
        if let drag = dividerDragStart,
            let point = try? e.getCurrentPoint(self)
        {
            let direction = panePlacement == .right ? -1.0 : 1.0
            let newLength = min(
                max(
                    drag.length + direction * (Double(point.position.x) - drag.x),
                    sidebarMinimumLength
                ),
                sidebarMaximumLength
            )
            if newLength != openPaneLength {
                openPaneLength = newLength
                sidebarResizeHandler?()
            }
            e.handled = true
            return
        }
        protectedCursor = isOverDivider(e) ? resizeCursor : nil
        try super.onPointerMoved(e)
    }

    override func onPointerReleased(_ e: PointerRoutedEventArgs!) throws {
        dividerDragStart = nil
        try super.onPointerReleased(e)
    }

    override func onPointerCaptureLost(_ e: PointerRoutedEventArgs!) throws {
        dividerDragStart = nil
        try super.onPointerCaptureLost(e)
    }
}

final class TapGestureTarget: WinUI.Canvas {
    var clickHandler: (() -> Void)?
    var child: WinUI.FrameworkElement?
}

final class HoverGestureTarget: WinUI.Canvas {
    var enterHandler: (() -> Void)?
    var exitHandler: (() -> Void)?
    var child: WinUI.FrameworkElement?
}

final class TooltipContainer: WinUI.Canvas {
    var child: WinUI.FrameworkElement
    var tooltip: ToolTip

    init(child: WinUI.FrameworkElement) {
        self.child = child
        self.tooltip = ToolTip()

        super.init()

        children.append(child)
        ToolTipService.setToolTip(self, tooltip)
    }
}

class SwiftIInitializeWithWindow: WindowsFoundation.IUnknown {
    override class var IID: WindowsFoundation.IID {
        WindowsFoundation.IID(
            Data1: 0x3E68_D4BD,
            Data2: 0x7135,
            Data3: 0x4D10,
            Data4: (0x80, 0x18, 0x9F, 0xB6, 0xD9, 0xF3, 0x3F, 0xA1)
        )
    }

    func initialize(with hwnd: HWND) throws {
        _ = try perform(as: IInitializeWithWindow.self) { pThis in
            try CHECKED(pThis.pointee.lpVtbl.pointee.Initialize(pThis, hwnd))
        }
    }
}

public class CustomWindow: WinUI.Window {
    /// The app-menu button hosted at the leading edge of the chrome strip.
    /// Created by the window-chrome view graph and attached via
    /// `attachAppMenuButton`; its flyout mirrors the application menu.
    var appMenuButton: WinUI.Button?

    /// The element currently registered as the window's caption drag region
    /// via `setTitleBar` (created by the window-chrome view graph).
    var dragElement: WinUI.FrameworkElement?

    /// The container hosted in the top grid row that holds the chrome strip's
    /// view-graph content (app menu, back button, title, toolbar items).
    /// A `Canvas` matches the backend's generic-container model (children are
    /// positioned absolutely by the chrome view graph).
    var chromeContainer = WinUI.Canvas()

    var child: WinUIBackend.Widget?
    var grid: WinUI.Grid
    var cachedAppWindow: WinAppSDK.AppWindow!
    var isActive = false
    /// `true` once `show` has been called for the first time. Resize requests
    /// made before this point are deferred because `AppWindow` ignores them.
    var hasBeenShown = false
    var pendingClientSize: SIMD2<Int>?
    /// The last client size we actually asked AppWindow for. Used by `show`'s
    /// post-activation verification pass to detect dropped resizes.
    var desiredClientSize: SIMD2<Int>?
    /// The client size observed by the previous verification pass, used to
    /// detect platform clamping when a requested size never materialises.
    var lastVerifiedClientSize: SIMD2<Int>?
    /// `true` once the window has been closed. All members that talk to the
    /// window's underlying WinRT objects become unsafe to call at that point.
    var isClosed = false
    /// Called from the `activated` event handler to apply `pendingClientSize`
    /// once the window is really up.
    var applyPendingClientSize: (() -> Void)?
    var currentAlert: WinUIBackend.Alert?

    /// The signature of the menu most recently applied to this window's menu
    /// bar. Used to skip destructive rebuilds when nothing has changed (a
    /// rebuild releases the flyout items, including any that are mid-click).
    var appliedMenuSignature: String?

    /// Content-area size limits in DIPs, enforced at the OS level by the
    /// `WM_GETMINMAXINFO` subclass proc. The chrome strip lives inside the
    /// client area, so `contentHeightAdjustment` is folded in when
    /// converting to physical window sizes.
    var minimumSizeLimit: SIMD2<Int>?
    var maximumSizeLimit: SIMD2<Int>?
    var minMaxSubclassInstalled = false

    /// The height of the system caption-button strip in DIPs. The chrome
    /// strip matches it exactly so the caption buttons and the chrome content
    /// share a single row.
    var captionStripHeight: Double {
        let height = cachedAppWindow?.titleBar.height ?? 32
        return Double(height) / scaleFactor
    }

    /// The amount of height to subtract off the window height to obtain the
    /// window's available content height.
    var contentHeightAdjustment: Int {
        Int(captionStripHeight.rounded(.awayFromZero))
    }

    /// The last observed scale factor. `GetDpiForWindow` can transiently
    /// report 96 DPI while the window is being created or moved between
    /// monitors, so once a real (non-1.0) scale has been observed we don't
    /// regress to 1.0 — otherwise consecutive resizes convert between DIPs
    /// and pixels with inconsistent scales and the window size ping-pongs.
    private var cachedScaleFactor: Double?

    var scaleFactor: Double {
        func cache(_ fresh: Double) -> Double {
            if fresh != 1 || (cachedScaleFactor ?? 1) == 1 {
                cachedScaleFactor = fresh
            }
            return cachedScaleFactor!
        }

        // I'm leaving this code here for future travellers. Be warned that this always
        // seems to return 100% even if the scale factor is set to 125% in settings.
        // Perhaps it's only the device's built-in default scaling? But that seems pretty
        // useless, and isn't what the docs seem to imply.
        //
        //   var deviceScaleFactor = SCALE_125_PERCENT
        //   _ = GetScaleFactorForMonitor(monitor, &deviceScaleFactor)

        // GetDpiForWindow returns the window's actual DPI (unlike
        // GetDpiForMonitor which always seems to report 96 DPI on some
        // systems even when the display is scaled).
        if let hwnd = cachedAppWindow.getHWND() {
            let dpi = GetDpiForWindow(hwnd)
            if dpi != 0 {
                return cache(Double(dpi) / Double(USER_DEFAULT_SCREEN_DPI))
            }

            let monitor = MonitorFromWindow(hwnd, DWORD(bitPattern: MONITOR_DEFAULTTONEAREST))!

            var x: UINT = 0
            var y: UINT = 0
            let result = GetDpiForMonitor(monitor, MDT_EFFECTIVE_DPI, &x, &y)

            if result == S_OK {
                return cache(Double(x) / Double(USER_DEFAULT_SCREEN_DPI))
            }
        }

        if let cachedScaleFactor {
            return cachedScaleFactor
        }
        logger.warning("failed to get window scale factor, defaulting to 1.0")
        return 1
    }

    public override init() {
        grid = WinUI.Grid()

        super.init()

        let chromeRowDefinition = WinUI.RowDefinition()
        let contentRowDefinition = WinUI.RowDefinition()
        grid.rowDefinitions.append(chromeRowDefinition)
        grid.rowDefinitions.append(contentRowDefinition)

        // The chrome strip occupies the whole top row. It hosts the chrome
        // view graph's content (app menu, back button, title, toolbar items
        // and a flexible drag region) as a single row alongside the system
        // caption buttons, as in the Windows Settings app. The drag region is
        // a dedicated element inside the chrome content — elements registered
        // via `setTitleBar` treat their bounds as non-client area, so keeping
        // it out from under the interactive controls preserves their input.
        grid.children.append(chromeContainer)
        WinUI.Grid.setRow(chromeContainer, 0)
        WinUI.Grid.setColumn(chromeContainer, 0)
        self.content = grid

        // NB: This event fires when the window is activated _or_ deactivated.
        self.activated.addHandler { [weak self] _, args in
            switch args?.windowActivationState {
                case .codeActivated, .pointerActivated: self?.isActive = true
                case .deactivated: self?.isActive = false
                // NB: The compiler apparently thinks we didn't exhaustively switch
                // over this enum without this `default` (even after adding a `case nil`).
                // Might be because it doesn't treat the underlying C enum as a Swift enum?
                default: break
            }
            self?.applyPendingClientSize?()
        }

        // Caching appWindow is apparently a good idea in terms of performance:
        // https://github.com/thebrowsercompany/swift-winrt/issues/199#issuecomment-2611006020
        cachedAppWindow = appWindow

        // Extend content into the title bar so that the chrome strip doubles
        // as the window's title bar, like other modern WinUI apps. The system
        // still draws the native minimize/maximize/close buttons at the top
        // right; the tall height option makes them nearly square and level
        // with the chrome strip (the Windows Settings look).
        extendsContentIntoTitleBar = true
        cachedAppWindow.titleBar.iconShowOptions = .hideIconAndSystemMenu
        cachedAppWindow.titleBar.preferredHeightOption = .tall
        if WinAppSDK.AppWindowTitleBar.isCustomizationSupported() {
            let transparent = UWP.Color(a: 0, r: 0, g: 0, b: 0)
            cachedAppWindow.titleBar.buttonBackgroundColor = transparent
            cachedAppWindow.titleBar.buttonInactiveBackgroundColor = transparent
        }

        grid.rowDefinitions[0]!.height = WinUI.GridLength(
            value: captionStripHeight,
            gridUnitType: .pixel
        )
    }

    /// Keeps the chrome strip row exactly as tall as the system caption
    /// buttons so they share a single visual row.
    func updateChromeStripHeight() {
        grid.rowDefinitions[0]!.height = WinUI.GridLength(
            value: captionStripHeight,
            gridUnitType: .pixel
        )
    }

    public func setChild(_ child: WinUIBackend.Widget) {
        self.child = child
        // Insert content *before* the chrome container so the chrome strip
        // stays topmost in z-order — a content visual that spills above its
        // row (Grid does not clip to rows) would otherwise paint over the
        // strip's controls and swallow their hover feedback.
        grid.children.insertAt(0, child)
        WinUI.Grid.setRow(child, 1)
        WinUI.Grid.setColumn(child, 0)
    }
}

public final class GeometryGroupHolder {
    var group = GeometryGroup()
    var strokeStyle: StrokeStyle?
}

@MainActor
final class CustomDatePicker: StackPanel {
    override init() {
        super.init()
        self.spacing = 10
    }

    deinit {
        timeChangedEvent?.dispose()
        dateChangedEvent?.dispose()
    }

    enum DateViewType {
        case calendarView(CalendarView)
        case calendarDatePicker(CalendarDatePicker)
        case datePicker(WinUI.DatePicker)

        var asControl: Control {
            switch self {
                case .calendarView(let calendarView): calendarView
                case .calendarDatePicker(let calendarDatePicker): calendarDatePicker
                case .datePicker(let datePicker): datePicker
            }
        }

        enum Discriminator {
            case calendarView
            case calendarDatePicker
            case datePicker
        }

        var discriminator: Discriminator {
            switch self {
                case .calendarView(_): .calendarView
                case .calendarDatePicker(_): .calendarDatePicker
                case .datePicker(_): .datePicker
            }
        }
    }

    private var dateView: DateViewType?
    private var timeView: TimePicker?
    private var date = Date()
    private var calendar = Calendar.current
    private var needsUpdate = false
    var onChange: ((Date) -> Void)?
    private var timeChangedEvent: EventCleanup?
    private var dateChangedEvent: EventCleanup?

    func toggleTimeView(shown: Bool) {
        guard shown != (self.timeView != nil) else { return }

        if shown {
            let timeView = TimePicker()
            children.append(timeView)
            self.timeView = timeView
            timeChangedEvent = timeView.timeChanged.addHandler { [unowned self] _, change in
                guard let change else { return }
                self.date =
                    calendar.startOfDay(for: date)
                        + Double(change.newTime.duration) / ticksPerSecond
                self.onChange?(self.date)
            }
            needsUpdate = true
        } else {
            timeChangedEvent?.dispose()
            timeChangedEvent = nil
            children.removeAtEnd()
            self.timeView = nil
        }
    }

    func setEnabled(to isEnabled: Bool) {
        dateView?.asControl.isEnabled = isEnabled
        timeView?.isEnabled = isEnabled
    }

    func changeDateView(to newDiscriminator: DateViewType.Discriminator?) {
        guard newDiscriminator != dateView?.discriminator else { return }

        dateChangedEvent?.dispose()
        if dateView != nil {
            children.removeAt(0)
        }

        switch newDiscriminator {
            case .calendarView:
                let calendarView = CalendarView()
                dateView = .calendarView(calendarView)
                children.insertAt(0, calendarView)
                orientation = .vertical
                dateChangedEvent = calendarView.selectedDatesChanged.addHandler {
                    [unowned self] _, _ in

                    guard calendarView.selectedDates.size > 0 else {
                        let (dateTime, _) = foundationDateToComponents(self.date)
                        calendarView.selectedDates.append(dateTime)
                        return
                    }

                    self.date = componentsToFoundationDate(
                        dateTime: calendarView.selectedDates.getAt(0),
                        timeSpan: timeView?.selectedTime
                    )

                    if calendarView.selectedDates.size > 1 {
                        self.needsUpdate = true
                    }

                    self.onChange?(self.date)
                }
                needsUpdate = true
            case .calendarDatePicker:
                let calendarDatePicker = CalendarDatePicker()
                dateView = .calendarDatePicker(calendarDatePicker)
                children.insertAt(0, calendarDatePicker)
                orientation = .horizontal
                dateChangedEvent = calendarDatePicker.dateChanged.addHandler {
                    [unowned self] _, change in

                    guard let newDate = change?.newDate else { return }
                    self.date = componentsToFoundationDate(
                        dateTime: newDate,
                        timeSpan: timeView?.selectedTime
                    )
                    self.onChange?(self.date)
                }
                needsUpdate = true
            case .datePicker:
                let datePicker = WinUI.DatePicker()
                dateView = .datePicker(datePicker)
                children.insertAt(0, datePicker)
                orientation = .horizontal
                dateChangedEvent = datePicker.selectedDateChanged.addHandler {
                    [unowned self] _, _ in

                    guard let selectedDate = datePicker.selectedDate else { return }
                    self.date = componentsToFoundationDate(
                        dateTime: selectedDate,
                        timeSpan: timeView?.selectedTime
                    )
                    self.onChange?(self.date)
                }
                needsUpdate = true
            case nil:
                break
        }
    }

    func setDateRange(to range: ClosedRange<Date>) {
        guard let dateView else { return }

        let (startDate, _) = foundationDateToComponents(range.lowerBound)
        let (endDate, _) = foundationDateToComponents(range.upperBound)

        switch dateView {
            case .calendarView(let calendarView):
                calendarView.minDate = startDate
                calendarView.maxDate = endDate
            case .calendarDatePicker(let calendarDatePicker):
                calendarDatePicker.minDate = startDate
                calendarDatePicker.maxDate = endDate
            case .datePicker(let datePicker):
                datePicker.minYear = startDate
                datePicker.maxYear = endDate
        }
    }

    func updateIfNeeded(date: Date, calendar: Calendar) {
        if !needsUpdate && date == self.date && calendar == self.calendar { return }
        defer { needsUpdate = false }

        self.date = date
        self.calendar = calendar

        let (dateTime, timeSpan) = foundationDateToComponents(date)

        switch dateView {
            case .calendarView(let calendarView):
                calendarView.calendarIdentifier = identifier(for: calendar)
                switch calendarView.selectedDates.size {
                    case 0:
                        calendarView.selectedDates.append(dateTime)
                    case 1:
                        calendarView.selectedDates.setAt(0, dateTime)
                    default:
                        calendarView.selectedDates.clear()
                        calendarView.selectedDates.setAt(0, dateTime)
                }
            case .calendarDatePicker(let calendarDatePicker):
                calendarDatePicker.calendarIdentifier = identifier(for: calendar)
                calendarDatePicker.date = dateTime
            case .datePicker(let datePicker):
                datePicker.selectedDate = dateTime
            case nil:
                break
        }

        if let timeView {
            timeView.selectedTime = timeSpan
        }
    }

    private func identifier(for calendar: Calendar) -> String {
        switch calendar.identifier {
            case .chinese: return "ChineseLunarCalendar"
            case .gregorian, .iso8601: return "GregorianCalendar"
            case .hebrew: return "HebrewCalendar"
            case .islamicTabular: return "HijriCalendar"
            case .islamicUmmAlQura: return "UmAlQuraCalendar"
            case .japanese: return "JapaneseCalendar"
            case .persian: return "PersianCalendar"
            case .republicOfChina: return "TaiwanCalendar"
            #if compiler(>=6.2)
                case .vietnamese: return "VietnameseLunarCalendar"
            #endif
            case let id:
                print("Unsupported calendar identifier '\(id)'. Falling back to Gregorian.")
                return "GregorianCalendar"
        }
    }

    // Magic numbers taken from https://stackoverflow.com/a/5471380/6253337
    private let ticksPerSecond: Double = 10_000_000
    private let unixEpochInUniversalTime: Int64 = 116_444_736_000_000_000

    private func foundationDateToComponents(_ date: Date) -> (DateTime, TimeSpan) {
        let timeInterval = date.timeIntervalSince(calendar.startOfDay(for: date))

        return (
            DateTime(
                universalTime: Int64(
                    date.timeIntervalSince1970 * ticksPerSecond + Double(unixEpochInUniversalTime)
                )
            ),
            TimeSpan(duration: Int64(timeInterval * ticksPerSecond))
        )
    }

    private func componentsToFoundationDate(dateTime: DateTime, timeSpan: TimeSpan?) -> Date {
        let baseDate = Date(
            timeIntervalSince1970: Double(dateTime.universalTime - unixEpochInUniversalTime)
                / ticksPerSecond
        )

        if let timeSpan {
            let time = Double(timeSpan.duration) / ticksPerSecond
            return calendar.startOfDay(for: baseDate) + time
        } else {
            return baseDate
        }
    }

    func naturalSize() -> SIMD2<Int> {
        let timeViewSize =
            if timeView != nil {
                // Width is 242, as shown in the WinUI repository:
                // https://github.com/marcelwgn/microsoft-ui-xaml/blob/ff21f9b212cea2191b959649e45e52486c8465aa/src/controls/dev/CommonStyles/TimePicker_themeresources.xaml#L116
                // Height is experimentally 29 which I don't see anywhere in that file.
                SIMD2(242, 29)
            } else {
                SIMD2<Int>.zero
            }

        let dateViewSize =
            if let dateControl = dateView?.asControl {
                WinUIBackend.naturalSize(of: dateControl)
            } else {
                SIMD2<Int>.zero
            }

        if orientation == .horizontal {
            return SIMD2(
                x: timeViewSize.x + dateViewSize.x + Int(self.spacing),
                y: max(timeViewSize.y, dateViewSize.y)
            )
        } else {
            return SIMD2(
                x: max(timeViewSize.x, dateViewSize.x),
                y: timeViewSize.y + dateViewSize.y + Int(self.spacing)
            )
        }
    }
}

extension WinUI.FrameworkElement {
    var shouldBlockNextChangedSignal: Bool {
        get {
            (self.tag as? [String: Any])?["shouldBlockNextChangedSignal"] as? Bool ?? false
        }
        set {
            var value = self.tag as? [String: Any] ?? [:]
            value["shouldBlockNextChangedSignal"] = newValue
            self.tag = value
        }
    }
}
