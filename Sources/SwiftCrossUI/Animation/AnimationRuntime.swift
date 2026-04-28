import Foundation

protocol AnimatableRuntimeValue: Sendable, Equatable {
    static func interpolate(from: Self, to: Self, progress: Double) -> Self
}

extension Double: AnimatableRuntimeValue {
    static func interpolate(from: Double, to: Double, progress: Double) -> Double {
        from + (to - from) * progress
    }
}

extension SIMD2<Int>: AnimatableRuntimeValue {
    static func interpolate(from: SIMD2<Int>, to: SIMD2<Int>, progress: Double) -> SIMD2<Int> {
        SIMD2(
            Int((Double(from.x) + Double(to.x - from.x) * progress).rounded()),
            Int((Double(from.y) + Double(to.y - from.y) * progress).rounded())
        )
    }
}

struct ViewFrame: Sendable, Equatable {
    var origin: SIMD2<Double>
    var size: SIMD2<Double>

    init(origin: SIMD2<Int>, size: SIMD2<Int>) {
        self.origin = SIMD2(Double(origin.x), Double(origin.y))
        self.size = SIMD2(Double(size.x), Double(size.y))
    }

    init(origin: SIMD2<Double>, size: SIMD2<Double>) {
        self.origin = origin
        self.size = size
    }
}

extension ViewFrame: AnimatableRuntimeValue {
    static func interpolate(from: ViewFrame, to: ViewFrame, progress: Double) -> ViewFrame {
        ViewFrame(
            origin: SIMD2(
                Double.interpolate(from: from.origin.x, to: to.origin.x, progress: progress),
                Double.interpolate(from: from.origin.y, to: to.origin.y, progress: progress)
            ),
            size: SIMD2(
                Double.interpolate(from: from.size.x, to: to.size.x, progress: progress),
                Double.interpolate(from: from.size.y, to: to.size.y, progress: progress)
            )
        )
    }
}

extension Color.Resolved: AnimatableRuntimeValue {
    static func interpolate(
        from: Color.Resolved,
        to: Color.Resolved,
        progress: Double
    ) -> Color.Resolved {
        func interpolate(_ start: Float, _ end: Float) -> Float {
            (start + (end - start) * Float(progress)).clampedToUnitInterval
        }

        return Color.Resolved(
            red: interpolate(from.red, to.red),
            green: interpolate(from.green, to.green),
            blue: interpolate(from.blue, to.blue),
            opacity: interpolate(from.opacity, to.opacity)
        )
    }
}

private extension Float {
    var clampedToUnitInterval: Float {
        max(0, min(1, self))
    }
}

struct ViewTransform: Sendable, Equatable {
    var scale: SIMD2<Double>
    var translation: SIMD2<Double>
    var rotation: Angle
    var anchor: UnitPoint

    init(
        scale: SIMD2<Double>,
        translation: SIMD2<Double>,
        rotation: Angle = .zero,
        anchor: UnitPoint
    ) {
        self.scale = scale
        self.translation = translation
        self.rotation = rotation
        self.anchor = anchor
    }

    static let identity = ViewTransform(
        scale: SIMD2(1, 1),
        translation: .zero,
        rotation: .zero,
        anchor: .center
    )
}

extension ViewTransform: AnimatableRuntimeValue {
    static func interpolate(
        from: ViewTransform,
        to: ViewTransform,
        progress: Double
    ) -> ViewTransform {
        ViewTransform(
            scale: SIMD2(
                Double.interpolate(from: from.scale.x, to: to.scale.x, progress: progress),
                Double.interpolate(from: from.scale.y, to: to.scale.y, progress: progress)
            ),
            translation: SIMD2(
                Double.interpolate(
                    from: from.translation.x,
                    to: to.translation.x,
                    progress: progress
                ),
                Double.interpolate(
                    from: from.translation.y,
                    to: to.translation.y,
                    progress: progress
                )
            ),
            rotation: Angle(
                radians: Double.interpolate(
                    from: from.rotation.radians,
                    to: to.rotation.radians,
                    progress: progress
                )
            ),
            anchor: to.anchor
        )
    }
}

struct AnimatableProperty<Value: AnimatableRuntimeValue> {
    var key: AnimationEngine.Key
    var target: Value
    var defaultStart: Value?
    var apply: @MainActor (Value) -> Void
    var flush: @MainActor () -> Void
}

@MainActor
enum AnimationRuntime {
    typealias Completion = AnimationEngine.Completion

    static func resetPresentation(of widget: Any) {
        AnimationEngine.shared.forgetAll(
            for: ObjectIdentifier(widget as AnyObject)
        )
    }

    static func setPosition<Backend: AppBackend>(
        ofChildAt index: Int,
        in container: Backend.Widget,
        to position: SIMD2<Int>,
        environment: EnvironmentValues,
        backend: Backend
    ) {
        setPosition(
            ofChildAt: index,
            in: container,
            to: position,
            animationKey: nil,
            environment: environment,
            backend: backend
        )
    }

    static func setFrame<Backend: AppBackend>(
        ofChildAt index: Int,
        in container: Backend.Widget,
        child childWidget: Backend.Widget,
        to frame: ViewFrame,
        environment: EnvironmentValues,
        backend: Backend
    ) {
        setFrame(
            ofChildAt: index,
            in: container,
            child: childWidget,
            to: frame,
            animationKey: nil,
            environment: environment,
            backend: backend
        )
    }

    static func setFrame<Backend: AppBackend>(
        ofChildAt index: Int,
        in container: Backend.Widget,
        child childWidget: Backend.Widget,
        to frame: ViewFrame,
        animationKey: ObjectIdentifier?,
        environment: EnvironmentValues,
        backend: Backend
    ) {
        let target = frame.clampedToNonNegativeSize

        AnimationEngine.shared.cancel(key: self.key(for: childWidget, property: "frame"))
        AnimationEngine.shared.cancel(key: self.key(for: childWidget, property: "size"))
        AnimationEngine.shared.cancel(key: self.key(for: container, property: "child-position-\(index)"))
        if let animationKey {
            AnimationEngine.shared.cancel(
                key: AnimationEngine.Key(owner: animationKey, property: "position")
            )
        }

        backend.setPosition(
            ofChildAt: index,
            in: container,
            to: target.originVector
        )
        backend.setSize(of: childWidget, to: target.sizeVector)
        backend.flushLayout(of: container)
    }

    static func setPosition<Backend: AppBackend>(
        ofChildAt index: Int,
        in container: Backend.Widget,
        to position: SIMD2<Int>,
        animationKey: ObjectIdentifier?,
        environment: EnvironmentValues,
        backend: Backend
    ) {
        let key = animationKey.map { AnimationEngine.Key(owner: $0, property: "position") }
            ?? key(for: container, property: "child-position-\(index)")
        AnimationEngine.shared.cancel(key: key)
        backend.setPosition(ofChildAt: index, in: container, to: position)
        backend.flushLayout(of: container)
    }

    static func resetPosition(
        ofChildAt index: Int,
        in container: Any
    ) {
        AnimationEngine.shared.cancel(
            key: key(for: container, property: "child-position-\(index)")
        )
    }

    static func setSize<Backend: AppBackend>(
        of widget: Backend.Widget,
        to size: SIMD2<Int>,
        environment: EnvironmentValues,
        backend: Backend
    ) {
        AnimationEngine.shared.cancel(key: key(for: widget, property: "size"))
        backend.setSize(of: widget, to: size.clampedToNonNegative)
        backend.flushLayout(of: widget)
    }

    static func setColor<Backend: AppBackend>(
        ofColorableRectangle widget: Backend.Widget,
        to color: Color.Resolved,
        environment: EnvironmentValues,
        backend: Backend
    ) {
        animate(
            AnimatableProperty(
                key: key(for: widget, property: "color"),
                target: color,
                defaultStart: nil,
                apply: { backend.setColor(ofColorableRectangle: widget, to: $0) },
                flush: {}
            ),
            environment: environment,
            backend: backend
        )
    }

    static func setCornerRadius<Backend: AppBackend>(
        of widget: Backend.Widget,
        to radius: Int,
        environment: EnvironmentValues,
        backend: Backend
    ) {
        animate(
            AnimatableProperty(
                key: key(for: widget, property: "corner-radius"),
                target: Double(radius),
                defaultStart: nil,
                apply: { backend.setCornerRadius(of: widget, to: max(0, Int($0.rounded()))) },
                flush: {}
            ),
            environment: environment,
            backend: backend
        )
    }

    static func setOpacity<Backend: AppBackend>(
        of widget: Backend.Widget,
        to opacity: Double,
        environment: EnvironmentValues,
        backend: Backend,
        defaultStart: Double? = nil,
        completion: Completion? = nil
    ) {
        animate(
            AnimatableProperty(
                key: key(for: widget, property: "opacity"),
                target: opacity.clampedToUnitInterval,
                defaultStart: defaultStart,
                apply: { backend.setOpacity(of: widget, to: $0.clampedToUnitInterval) },
                flush: {}
            ),
            environment: environment,
            backend: backend,
            completion: completion
        )
    }

    static func setTransform<Backend: AppBackend>(
        of widget: Backend.Widget,
        to transform: ViewTransform,
        environment: EnvironmentValues,
        backend: Backend,
        bounds: SIMD2<Int>? = nil,
        defaultStart: ViewTransform? = nil,
        completion: Completion? = nil
    ) {
        animate(
            AnimatableProperty(
                key: key(for: widget, property: "transform"),
                target: transform.clampedForBackend,
                defaultStart: defaultStart?.clampedForBackend,
                apply: {
                    let transform = $0.clampedForBackend
                    backend.setTransform(
                        of: widget,
                        scale: transform.scale,
                        translation: transform.translation,
                        rotation: transform.rotation,
                        anchor: transform.anchor,
                        bounds: bounds
                    )
                },
                flush: {}
            ),
            environment: environment,
            backend: backend,
            completion: completion
        )
    }

    static func trackCompletion(
        owner: AnyObject,
        completion: @escaping @MainActor () -> Void
    ) -> Completion {
        AnimationEngine.shared.completion(
            owner: ObjectIdentifier(owner),
            action: completion
        )
    }

    static func trackCompletion(
        keys: Set<AnimationEngine.Key>,
        completion: @escaping @MainActor () -> Void
    ) -> Completion {
        AnimationEngine.shared.completion(
            keys: keys,
            action: completion
        )
    }

    static func recordAnimationWrites<Result>(
        _ body: () -> Result
    ) -> (result: Result, keys: Set<AnimationEngine.Key>) {
        AnimationEngine.shared.recordAnimationWrites(body)
    }

    static func cancelCompletion(_ completion: Completion?) {
        completion?.cancel()
    }

    private static func animate<Backend: AppBackend, Value>(
        _ property: AnimatableProperty<Value>,
        environment: EnvironmentValues,
        backend: Backend,
        completion: Completion? = nil
    ) {
        AnimationEngine.shared.write(
            property,
            transaction: environment.transaction,
            scheduleFrame: { backend.scheduleAnimationFrame(action: $0) },
            completion: completion
        )
    }

    private static func key(for widget: Any, property: String) -> AnimationEngine.Key {
        AnimationEngine.Key(
            owner: ObjectIdentifier(widget as AnyObject),
            property: property
        )
    }
}

private extension ViewFrame {
    var clampedToNonNegativeSize: ViewFrame {
        ViewFrame(
            origin: origin,
            size: SIMD2(Swift.max(0, size.x), Swift.max(0, size.y))
        )
    }

    var originVector: SIMD2<Int> {
        SIMD2(
            LayoutSystem.roundSize(origin.x),
            LayoutSystem.roundSize(origin.y)
        )
    }

    var sizeVector: SIMD2<Int> {
        SIMD2(
            LayoutSystem.roundSize(size.x),
            LayoutSystem.roundSize(size.y)
        )
    }
}

private extension Double {
    var clampedToUnitInterval: Double {
        max(0, min(1, self))
    }
}

private extension SIMD2 where Scalar == Int {
    var clampedToNonNegative: SIMD2<Int> {
        SIMD2(Swift.max(0, x), Swift.max(0, y))
    }
}

private extension ViewTransform {
    var clampedForBackend: ViewTransform {
        ViewTransform(
            scale: SIMD2(max(0, scale.x), max(0, scale.y)),
            translation: translation,
            rotation: rotation,
            anchor: anchor
        )
    }
}

@MainActor
final class AnimationEngine {
    struct Key: Hashable {
        var owner: ObjectIdentifier
        var property: String
    }

    final class Completion {
        fileprivate let id: Int
        fileprivate weak var engine: AnimationEngine?
        fileprivate var isCancelled = false

        fileprivate init(id: Int, engine: AnimationEngine) {
            self.id = id
            self.engine = engine
        }

        @MainActor
        func cancel() {
            isCancelled = true
            engine?.completions[id] = nil
        }
    }

    private enum CompletionWait {
        case owner(ObjectIdentifier)
        case keys(Set<Key>)
    }

    private struct CompletionState {
        var wait: CompletionWait
        var action: @MainActor () -> Void
    }

    private final class AnimationWriteRecorder {
        var keys: Set<Key> = []
    }

    static let shared = AnimationEngine()

    private var animations: [Key: any RunningAnimationProtocol] = [:]
    private var presentationValues: [Key: Any] = [:]
    private var completions: [Int: CompletionState] = [:]
    private var writeRecorders: [AnimationWriteRecorder] = []
    private var nextCompletionID = 0
    private var scheduleFrame: ((@escaping @MainActor @Sendable () -> Void) -> Void)?
    private var frameScheduled = false
    private var frameFlushes: [@MainActor () -> Void] = []

    func completion(
        owner: ObjectIdentifier,
        action: @escaping @MainActor () -> Void
    ) -> Completion {
        nextCompletionID += 1
        let completion = Completion(id: nextCompletionID, engine: self)
        completions[completion.id] = CompletionState(wait: .owner(owner), action: action)
        drainCompletions()
        return completion
    }

    func completion(
        keys: Set<Key>,
        action: @escaping @MainActor () -> Void
    ) -> Completion {
        nextCompletionID += 1
        let completion = Completion(id: nextCompletionID, engine: self)
        completions[completion.id] = CompletionState(wait: .keys(keys), action: action)
        drainCompletions()
        return completion
    }

    func recordAnimationWrites<Result>(
        _ body: () -> Result
    ) -> (result: Result, keys: Set<Key>) {
        let recorder = AnimationWriteRecorder()
        writeRecorders.append(recorder)
        let result = body()
        _ = writeRecorders.popLast()
        return (result, recorder.keys)
    }

    func forgetAll(for owner: ObjectIdentifier) {
        animations = animations.filter { element in
            element.key.owner != owner
        }
        presentationValues = presentationValues.filter { element in
            element.key.owner != owner
        }
        completions = completions.filter { _, state in
            switch state.wait {
                case .owner(let stateOwner):
                    return stateOwner != owner
                case .keys(let keys):
                    return !keys.contains { $0.owner == owner }
            }
        }
    }

    func cancel(key: Key) {
        animations[key] = nil
        drainCompletions()
    }

    func write<Value: AnimatableRuntimeValue>(
        _ property: AnimatableProperty<Value>,
        transaction: Transaction,
        scheduleFrame: @escaping (@escaping @MainActor @Sendable () -> Void) -> Void,
        completion: Completion? = nil
    ) {
        guard let animation = transaction.effectiveAnimation else {
            animations[property.key] = nil
            remember(property.target, for: property.key)
            property.apply(property.target)
            property.flush()
            drainCompletions()
            return
        }

        let start =
            (animations[property.key]?.currentValue as? Value)
            ?? (presentationValues[property.key] as? Value)
            ?? property.defaultStart
            ?? property.target

        if start == property.target {
            animations[property.key] = nil
            remember(property.target, for: property.key)
            property.apply(property.target)
            property.flush()
            drainCompletions()
            return
        }

        animations[property.key] = RunningAnimation(
            key: property.key,
            start: start,
            target: property.target,
            animation: animation,
            apply: property.apply,
            flush: property.flush
        )
        for recorder in writeRecorders {
            recorder.keys.insert(property.key)
        }
        self.scheduleFrame = scheduleFrame
        ensureFrameScheduled()
        if completion != nil {
            drainCompletions()
        }
    }

    private func remember<Value>(_ value: Value, for key: Key) {
        presentationValues[key] = value
    }

    private func ensureFrameScheduled() {
        guard !frameScheduled, !animations.isEmpty, let scheduleFrame else {
            return
        }

        frameScheduled = true
        scheduleFrame { [weak self] in
            self?.tickFrame()
        }
    }

    private func tickFrame() {
        frameScheduled = false

        let now = ProcessInfo.processInfo.systemUptime
        frameFlushes = []
        for key in Array(animations.keys) {
            guard let animation = animations[key] else {
                continue
            }
            if animation.tick(at: now) {
                presentationValues[key] = animation.currentValue
                animations[key] = nil
            } else {
                presentationValues[key] = animation.currentValue
            }
        }

        let flushes = frameFlushes
        frameFlushes = []
        for flush in flushes {
            flush()
        }

        drainCompletions()

        if animations.isEmpty {
            scheduleFrame = nil
        } else {
            ensureFrameScheduled()
        }
    }

    private func drainCompletions() {
        let readyIDs = completions.compactMap { id, state in
            switch state.wait {
                case .owner(let owner):
                    animations.keys.contains { $0.owner == owner } ? nil : id
                case .keys(let keys):
                    animations.keys.contains { keys.contains($0) } ? nil : id
            }
        }
        for id in readyIDs {
            guard let state = completions.removeValue(forKey: id) else {
                continue
            }
            state.action()
        }
    }

    fileprivate func deferFlush(_ flush: @escaping @MainActor () -> Void) {
        frameFlushes.append(flush)
    }
}

@MainActor
private protocol RunningAnimationProtocol: AnyObject {
    var currentValue: Any { get }
    func tick(at now: TimeInterval) -> Bool
}

@MainActor
private final class RunningAnimation<Value: AnimatableRuntimeValue>: RunningAnimationProtocol {
    let key: AnimationEngine.Key
    let start: Value
    let target: Value
    let animation: Animation
    let apply: @MainActor (Value) -> Void
    let flush: @MainActor () -> Void
    let startTime: TimeInterval
    var latest: Value

    init(
        key: AnimationEngine.Key,
        start: Value,
        target: Value,
        animation: Animation,
        apply: @escaping @MainActor (Value) -> Void,
        flush: @escaping @MainActor () -> Void
    ) {
        self.key = key
        self.start = start
        self.target = target
        self.animation = animation
        self.apply = apply
        self.flush = flush
        self.startTime = ProcessInfo.processInfo.systemUptime
        self.latest = start
    }

    var currentValue: Any {
        latest
    }

    func tick(at now: TimeInterval) -> Bool {
        let elapsed = now - startTime
        if animation.isComplete(at: elapsed) {
            latest = target
            apply(latest)
            AnimationEngine.shared.deferFlush(flush)
            return true
        }

        latest = Value.interpolate(
            from: start,
            to: target,
            progress: animation.value(at: elapsed)
        )
        apply(latest)
        AnimationEngine.shared.deferFlush(flush)

        return false
    }
}
