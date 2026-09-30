import Foundation

/// Additional interaction-related modifiers mirroring the SwiftUI surface.
extension View {
    /// Sets whether this view responds to hit-testing.
    ///
    /// Recorded in the environment; backends honor it when installing
    /// pointer handlers (full propagation is pending).
    public func allowsHitTesting(_ enabled: Bool) -> some View {
        environment(\.allowsHitTesting, enabled)
    }

    /// Marks `value` of the given focus binding as this view's default focus
    /// target.
    ///
    /// Recorded in the environment; a focus manager consumes it when the view
    /// first appears (backend support pending).
    public func defaultFocus(
        _ binding: FocusState<Bool>.Binding,
        _ value: Bool
    ) -> some View {
        environment(\.defaultFocusValue, (binding.wrappedValue, value))
    }

    /// Applies a style to lists within this view.
    ///
    /// Backends read ``EnvironmentValues/listStyle`` when rendering lists.
    public func listStyle(_ style: ListStyle) -> some View {
        environment(\.listStyle, style)
    }
}

extension EnvironmentValues {
    /// Whether hit-testing is enabled for the view.
    @Entry public var allowsHitTesting: Bool = true

    /// The default-focus binding value of the view, if any.
    @Entry @_spi(Backends) public var defaultFocusValue: (Bool, Bool)? = nil

    /// The minimum scale factor text within the view can shrink to.
    @Entry public var minimumScaleFactor: Double = 1.0

    /// The scroll view's default scroll anchor, if set.
    @Entry @_spi(Backends) public var defaultScrollAnchor: UnitPoint? = nil

    /// The view's drop shadow description, if any.
    @Entry @_spi(Backends) public var shadowValue: ShadowValue? = nil

    /// The safe area regions and edges the view ignores, if any.
    @Entry @_spi(Backends) public var ignoredSafeArea: (regions: SafeAreaRegions, edges: Edge.Set)? = nil

    /// Accessibility traits added to the view.
    @Entry @_spi(Backends) public var addedAccessibilityTraits: AccessibilityTraits = []

    /// Accessibility traits removed from the view.
    @Entry @_spi(Backends) public var removedAccessibilityTraits: AccessibilityTraits = []

    /// Whether the view is hidden from accessibility clients.
    @Entry @_spi(Backends) public var accessibilityHidden: Bool = false

    /// A scroll position request recorded by
    /// ``View/scrollPosition(id:anchor:)``, if any.
    @Entry @_spi(Backends) public var scrollPositionRequest: ScrollPositionRequest? = nil

    /// The URL of the document represented by the window, recorded by
    /// ``View/navigationDocument(_:)``.
    @Entry @_spi(Backends) public var navigationDocumentURL: URL? = nil
}

/// A request to keep the scroll view's position bound to an identifiable
/// element, as recorded by ``View/scrollPosition(id:anchor:)``.
public struct ScrollPositionRequest {
    /// A binding to the id of the currently anchored element.
    public var id: Binding<AnyHashable?>
    /// The preferred anchor for the bound element.
    public var anchor: UnitPoint?

    /// Creates a request from a typed binding, erasing the element id to
    /// `AnyHashable`.
    public init<ID: Hashable>(id: Binding<ID?>, anchor: UnitPoint?) {
        self.id = Binding<AnyHashable?>(
            get: { id.wrappedValue.map { AnyHashable($0) } },
            set: { newValue in
                id.wrappedValue = newValue.flatMap { $0.base as? ID }
            }
        )
        self.anchor = anchor
    }
}

/// Accessibility traits describing a view's behavior, as in SwiftUI.
public struct AccessibilityTraits: OptionSet, Sendable, Hashable {
    public let rawValue: UInt

    public init(rawValue: UInt) {
        self.rawValue = rawValue
    }

    /// The element is a button.
    public static let isButton = AccessibilityTraits(rawValue: 1 << 0)
    /// The element is a header.
    public static let isHeader = AccessibilityTraits(rawValue: 1 << 1)
    /// The element is currently selected.
    public static let isSelected = AccessibilityTraits(rawValue: 1 << 2)
    /// The element is a link.
    public static let isLink = AccessibilityTraits(rawValue: 1 << 3)
    /// The element is a search field.
    public static let isSearchField = AccessibilityTraits(rawValue: 1 << 4)
    /// The element is an image.
    public static let isImage = AccessibilityTraits(rawValue: 1 << 5)
    /// The element plays a sound when activated.
    public static let playsSound = AccessibilityTraits(rawValue: 1 << 6)
    /// The element is a keyboard key.
    public static let isKeyboardKey = AccessibilityTraits(rawValue: 1 << 7)
    /// The element is a static text.
    public static let isStaticText = AccessibilityTraits(rawValue: 1 << 8)
    /// The element provides a summary of this app on launch.
    public static let isSummaryElement = AccessibilityTraits(rawValue: 1 << 9)
    /// The element frequently updates its label or value.
    public static let updatesFrequently = AccessibilityTraits(rawValue: 1 << 10)
    /// The element starts a media session when activated.
    public static let startsMediaSession = AccessibilityTraits(rawValue: 1 << 11)
    /// The element allows direct touch interaction.
    public static let allowsDirectInteraction = AccessibilityTraits(rawValue: 1 << 12)
    /// The element causes an automatic page turn when activated.
    public static let causesPageTurn = AccessibilityTraits(rawValue: 1 << 13)
    /// The element is modal.
    public static let isModal = AccessibilityTraits(rawValue: 1 << 14)
    /// The element is a toggle.
    public static let isToggle = AccessibilityTraits(rawValue: 1 << 15)
}

/// The regions of the safe area a view can ignore, as in SwiftUI.
public struct SafeAreaRegions: OptionSet, Sendable, Hashable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    /// The region occupied by toolbars and bars.
    public static let container = SafeAreaRegions(rawValue: 1 << 0)
    /// The region occupied by content insets.
    public static let keyboard = SafeAreaRegions(rawValue: 1 << 1)
    /// All safe area regions.
    public static let all: SafeAreaRegions = [.container, .keyboard]
}

extension View {
    /// Applies a strikethrough decoration to text within this view.
    ///
    /// Carried through the environment; text views read
    /// ``EnvironmentValues/textStrikethrough``.
    public func strikethrough(_ active: Bool = true, color: Color? = nil) -> some View {
        environment(\.textStrikethrough, active)
    }

    /// Applies an underline decoration to text within this view.
    ///
    /// Carried through the environment; text views read
    /// ``EnvironmentValues/textUnderline``.
    public func underline(_ active: Bool = true, color: Color? = nil) -> some View {
        environment(\.textUnderline, active)
    }

    /// Sets the minimum scale factor that text within this view can shrink
    /// to when truncating.
    ///
    /// Carried through the environment for text views.
    public func minimumScaleFactor(_ factor: Double) -> some View {
        environment(\.minimumScaleFactor, factor)
    }

    /// Sets the scroll view's default scroll anchor.
    ///
    /// Recorded in the environment for scroll views.
    public func defaultScrollAnchor(_ anchor: UnitPoint) -> some View {
        environment(\.defaultScrollAnchor, anchor)
    }

    /// Adds a shadow to the view.
    ///
    /// The parameters are carried through the environment; backends read them
    /// when rendering the view's layer.
    public func shadow(
        color: Color = Color(white: 0, opacity: 0.33),
        radius: Double,
        x: Double = 0,
        y: Double = 0
    ) -> some View {
        environment(\.shadowValue, ShadowValue(color: color, radius: radius, x: x, y: y))
    }

    /// Expands the safe area of this view into the given regions.
    ///
    /// Recorded in the environment; backends read it when computing safe
    /// area insets.
    public func ignoresSafeArea(
        _ regions: SafeAreaRegions = .all,
        edges: Edge.Set = .all
    ) -> some View {
        environment(\.ignoredSafeArea, (regions: regions, edges: edges))
    }

    /// Adds the given accessibility traits to the view.
    ///
    /// Recorded in the environment for backends' accessibility bridges.
    public func accessibilityAddTraits(_ traits: AccessibilityTraits) -> some View {
        environment(\.addedAccessibilityTraits, traits)
    }

    /// Removes the given accessibility traits from the view.
    ///
    /// Recorded in the environment for backends' accessibility bridges.
    public func accessibilityRemoveTraits(_ traits: AccessibilityTraits) -> some View {
        environment(\.removedAccessibilityTraits, traits)
    }

    /// Hides the view from accessibility clients, as in SwiftUI.
    ///
    /// Recorded in the environment for backends' accessibility bridges.
    public func accessibilityHidden(_ hidden: Bool) -> some View {
        environment(\.accessibilityHidden, hidden)
    }

    /// Sets the tint color within this view, as in SwiftUI.
    ///
    /// Backends apply it to controls that honor tint (e.g. progress bars).
    public func tint<S: ShapeStyle>(_ style: S) -> some View {
        environment(\.tintColor, style)
    }

    /// Disables the clipping applied to scrollable views, as in SwiftUI.
    ///
    /// Recorded in the environment; backends consume it as they gain
    /// explicit scroll-clip handling (scroll views currently never clip
    /// beyond their bounds unless the platform does so).
    public func scrollClipDisabled(_ disabled: Bool = true) -> some View {
        environment(\.scrollClipDisabled, disabled)
    }

    /// Sets the pointer style shown while hovering over this view, as in
    /// SwiftUI.
    ///
    /// Recorded in the environment; backends apply it once their pointer
    /// machinery learns to consume it.
    public func pointerStyle(_ style: PointerStyle) -> some View {
        environment(\.pointerStyle, style)
    }

    /// Groups the view's geometry so matched-geometry transitions treat it
    /// as a unit, as in SwiftUI.
    ///
    /// Currently a no-op; geometry transitions are not yet implemented.
    public func geometryGroup() -> some View {
        self
    }

    /// Associates a document URL with the enclosing window's title bar, as
    /// in SwiftUI.
    ///
    /// Recorded in the environment; backends consume it when they surface
    /// document proxies.
    public func navigationDocument(_ url: URL) -> some View {
        environment(\.navigationDocumentURL, url)
    }

    /// Binds the scroll position of the nearest enclosing scroll view to
    /// the element with the given id, as in SwiftUI.
    ///
    /// Recorded in the environment; backends consume it once their scroll
    /// containers expose position control.
    public func scrollPosition<ID: Hashable>(
        id: Binding<ID?>,
        anchor: UnitPoint? = nil
    ) -> some View {
        environment(\.scrollPositionRequest, ScrollPositionRequest(id: id, anchor: anchor))
    }
}

/// A pointer style, mirroring the subset of SwiftUI's `PointerStyle` used by
/// apps.
public enum PointerStyle: Sendable, Hashable {
    /// The platform's default pointer.
    case `default`
    /// A pointer indicating a link.
    case link
    /// A pointer indicating editable horizontal text.
    case horizontalText
    /// A pointer indicating a vertically resizable region.
    case rowResize
    /// A pointer indicating a horizontally resizable region.
    case columnResize
    /// A pointer indicating a region that can be grabbed.
    case grabIdle
    /// A pointer indicating a region that is grabbed.
    case grabActive
}

/// A drop shadow description, as recorded by ``View/shadow(color:radius:x:y:)``.
public struct ShadowValue: Sendable, Hashable {
    /// The shadow's color.
    public var color: Color
    /// The shadow's blur radius.
    public var radius: Double
    /// The shadow's horizontal offset.
    public var x: Double
    /// The shadow's vertical offset.
    public var y: Double
}

/// A drag gesture, mirroring the SwiftUI surface.
///
/// The gesture's value and callbacks are recorded on the view for backends to
/// drive; pointer-driven recognition in backends is pending.
public struct DragGesture: Sendable {
    /// The value passed to `onChanged`/`onEnded` callbacks.
    public struct Value: Sendable {
        /// The gesture's translation since it started.
        public var translation: CGSize
        /// The pointer's current location.
        public var location: CGPoint
        /// The pointer's location when the gesture started.
        public var startLocation: CGPoint
        /// The predicted end translation.
        public var predictedEndTranslation: CGSize
        /// The predicted end location.
        public var predictedEndLocation: CGPoint
    }

    /// The minimum distance the pointer must travel before the gesture
    /// succeeds.
    public var minimumDistance: Double
    /// The coordinate space the gesture is evaluated in.
    public var coordinateSpace: CoordinateSpace

    var onChanged: ((Value) -> Void)?
    var onEnded: ((Value) -> Void)?

    /// Creates a drag gesture.
    public init(minimumDistance: Double = 10, coordinateSpace: CoordinateSpace = .local) {
        self.minimumDistance = minimumDistance
        self.coordinateSpace = coordinateSpace
    }

    /// Registers an action performed when the gesture's value changes.
    public func onChanged(_ action: @escaping (Value) -> Void) -> DragGesture {
        var gesture = self
        gesture.onChanged = action
        return gesture
    }

    /// Registers an action performed when the gesture ends.
    public func onEnded(_ action: @escaping (Value) -> Void) -> DragGesture {
        var gesture = self
        gesture.onEnded = action
        return gesture
    }
}

/// The coordinate space a gesture is evaluated in, as in SwiftUI.
public enum CoordinateSpace: Sendable, Hashable {
    /// The local coordinate space of the view.
    case local
    /// The global coordinate space.
    case global
    /// A named coordinate space.
    case named(AnyHashable)
}

/// A view that records an installed gesture for backend consumption.
struct GestureView<Content: View>: View {
    var content: Content
    var gesture: Any

    var body: some View {
        content
    }
}

extension View {
    /// Attaches a gesture to the view.
    ///
    /// The gesture is recorded on the view; gesture recognition in backends
    /// is pending.
    public func gesture(_ gesture: DragGesture) -> some View {
        GestureView(content: self, gesture: gesture)
    }
}

/// A role describing the semantic intent of a button or control, as in
/// SwiftUI.
public struct ButtonRole: Sendable, Hashable {
    enum Kind: Sendable, Hashable {
        case normal, destructive, cancel
    }
    var kind: Kind

    /// The default button role.
    public static let normal = ButtonRole(kind: .normal)
    /// A role that indicates a destructive action.
    public static let destructive = ButtonRole(kind: .destructive)
    /// A role that indicates a cancellation action.
    public static let cancel = ButtonRole(kind: .cancel)
}
