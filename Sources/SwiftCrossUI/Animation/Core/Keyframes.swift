import Foundation

/// A sequence of keyframes for a single animatable value.
public protocol KeyframeTrackContent<Value> {
    associatedtype Value: Animatable
    associatedtype Body: KeyframeTrackContent where Body.Value == Value

    var body: Body { get }
}

extension KeyframeTrackContent where Body == Self {
    public var body: Self {
        self
    }
}

/// A collection of keyframe tracks.
public protocol Keyframes<Value> {
    associatedtype Value
    associatedtype Body: Keyframes where Body.Value == Value

    var body: Body { get }
}

extension Keyframes where Body == Self {
    public var body: Self {
        self
    }
}

/// A linear keyframe.
public struct LinearKeyframe<Value: Animatable>: KeyframeTrackContent {
    public typealias Body = LinearKeyframe<Value>

    public var value: Value
    public var duration: TimeInterval
    public var timingCurve: UnitCurve

    public init(_ to: Value, duration: TimeInterval, timingCurve: UnitCurve = .linear) {
        self.value = to
        self.duration = duration
        self.timingCurve = timingCurve
    }
}

/// A cubic keyframe.
public struct CubicKeyframe<Value: Animatable>: KeyframeTrackContent {
    public typealias Body = CubicKeyframe<Value>

    public var value: Value
    public var duration: TimeInterval
    public var startVelocity: Value?
    public var endVelocity: Value?

    public init(
        _ to: Value,
        duration: TimeInterval,
        startVelocity: Value? = nil,
        endVelocity: Value? = nil
    ) {
        self.value = to
        self.duration = duration
        self.startVelocity = startVelocity
        self.endVelocity = endVelocity
    }
}

/// A spring keyframe.
public struct SpringKeyframe<Value: Animatable>: KeyframeTrackContent {
    public typealias Body = SpringKeyframe<Value>

    public var value: Value
    public var duration: TimeInterval?
    public var spring: Spring
    public var startVelocity: Value?

    public init(
        _ to: Value,
        duration: TimeInterval? = nil,
        spring: Spring = Spring(),
        startVelocity: Value? = nil
    ) {
        self.value = to
        self.duration = duration
        self.spring = spring
        self.startVelocity = startVelocity
    }
}

/// An instantaneous keyframe.
public struct MoveKeyframe<Value: Animatable>: KeyframeTrackContent {
    public typealias Body = MoveKeyframe<Value>

    public var value: Value

    public init(_ to: Value) {
        self.value = to
    }
}

/// A keyframe track for a root value or one of its writable properties.
public struct KeyframeTrack<Root, TrackValue: Animatable, Content>: Keyframes
where Content: KeyframeTrackContent, Content.Value == TrackValue {
    public typealias Value = Root
    public typealias Body = KeyframeTrack<Root, TrackValue, Content>

    public var keyPath: WritableKeyPath<Root, TrackValue>?
    public var content: Content

    public init(
        @KeyframeTrackContentBuilder<Root> content: () -> Content
    ) where Root == TrackValue {
        self.keyPath = nil
        self.content = content()
    }

    public init(
        _ keyPath: WritableKeyPath<Root, TrackValue>,
        @KeyframeTrackContentBuilder<TrackValue> content: () -> Content
    ) {
        self.keyPath = keyPath
        self.content = content()
    }
}

/// A timeline for evaluated keyframes.
public struct KeyframeTimeline<Value> {
    public var initialValue: Value
    var duration: TimeInterval
    var applyAtTime: (inout Value, TimeInterval) -> Void

    public init(initialValue: Value) {
        self.initialValue = initialValue
        self.duration = 0
        self.applyAtTime = { _, _ in }
    }

    init(
        initialValue: Value,
        duration: TimeInterval,
        applyAtTime: @escaping (inout Value, TimeInterval) -> Void
    ) {
        self.initialValue = initialValue
        self.duration = duration
        self.applyAtTime = applyAtTime
    }

    public func value(time: TimeInterval) -> Value {
        var value = initialValue
        applyAtTime(&value, time)
        return value
    }

    func apply(to value: inout Value, time: TimeInterval) {
        applyAtTime(&value, time)
    }
}

public struct EmptyKeyframeTrackContent<Value: Animatable>: KeyframeTrackContent {
    public typealias Body = EmptyKeyframeTrackContent<Value>

    public init() {}
}

public struct CombinedKeyframeTrackContent<Value: Animatable>: KeyframeTrackContent {
    public typealias Body = CombinedKeyframeTrackContent<Value>

    var components: [AnyKeyframeTrackContent<Value>]

    init(components: [AnyKeyframeTrackContent<Value>]) {
        self.components = components
    }
}

public struct EmptyKeyframes<Value>: Keyframes {
    public typealias Body = EmptyKeyframes<Value>

    public init() {}
}

public struct CombinedKeyframes<Value>: Keyframes {
    public typealias Body = CombinedKeyframes<Value>

    var components: [AnyKeyframes<Value>]

    init(components: [AnyKeyframes<Value>]) {
        self.components = components
    }
}

struct KeyframeSegment<Value: Animatable> {
    enum Interpolation {
        case linear(UnitCurve)
        case cubic
        case spring(Spring)
        case move
    }

    var to: Value
    var duration: TimeInterval
    var interpolation: Interpolation
}

protocol AnyKeyframeTrackContentRuntime {
    func erasedKeyframeSegments() -> Any
}

protocol KeyframeTrackContentRuntime: KeyframeTrackContent, AnyKeyframeTrackContentRuntime {
    func keyframeSegments() -> [KeyframeSegment<Value>]
}

extension KeyframeTrackContentRuntime {
    func erasedKeyframeSegments() -> Any {
        keyframeSegments()
    }
}

struct AnyKeyframeTrackContent<Value: Animatable>: KeyframeTrackContentRuntime {
    typealias Body = AnyKeyframeTrackContent<Value>

    private var segments: () -> [KeyframeSegment<Value>]

    init<Content: KeyframeTrackContent>(_ content: Content)
    where Content.Value == Value {
        segments = {
            makeKeyframeSegments(from: content)
        }
    }

    func keyframeSegments() -> [KeyframeSegment<Value>] {
        segments()
    }
}

protocol AnyKeyframesRuntime {
    func erasedTimeline(initialValue: Any) -> Any
}

protocol KeyframesRuntime: Keyframes, AnyKeyframesRuntime {
    func makeTimeline(initialValue: Value) -> KeyframeTimeline<Value>
}

extension KeyframesRuntime {
    func erasedTimeline(initialValue: Any) -> Any {
        guard let initialValue = initialValue as? Value else {
            return KeyframeTimeline(initialValue: initialValue)
        }
        return makeTimeline(initialValue: initialValue)
    }
}

struct AnyKeyframes<Value>: KeyframesRuntime {
    typealias Body = AnyKeyframes<Value>

    private var timeline: (Value) -> KeyframeTimeline<Value>

    init<Content: Keyframes>(_ content: Content) where Content.Value == Value {
        timeline = {
            makeKeyframeTimeline(from: content, initialValue: $0)
        }
    }

    func makeTimeline(initialValue: Value) -> KeyframeTimeline<Value> {
        timeline(initialValue)
    }
}

extension LinearKeyframe: KeyframeTrackContentRuntime {
    func keyframeSegments() -> [KeyframeSegment<Value>] {
        [KeyframeSegment(to: value, duration: duration, interpolation: .linear(timingCurve))]
    }
}

extension CubicKeyframe: KeyframeTrackContentRuntime {
    func keyframeSegments() -> [KeyframeSegment<Value>] {
        [KeyframeSegment(to: value, duration: duration, interpolation: .cubic)]
    }
}

extension SpringKeyframe: KeyframeTrackContentRuntime {
    func keyframeSegments() -> [KeyframeSegment<Value>] {
        [
            KeyframeSegment(
                to: value,
                duration: duration ?? spring.duration,
                interpolation: .spring(spring)
            )
        ]
    }
}

extension MoveKeyframe: KeyframeTrackContentRuntime {
    func keyframeSegments() -> [KeyframeSegment<Value>] {
        [KeyframeSegment(to: value, duration: 0, interpolation: .move)]
    }
}

extension EmptyKeyframeTrackContent: KeyframeTrackContentRuntime {
    func keyframeSegments() -> [KeyframeSegment<Value>] {
        []
    }
}

extension CombinedKeyframeTrackContent: KeyframeTrackContentRuntime {
    func keyframeSegments() -> [KeyframeSegment<Value>] {
        components.flatMap { $0.keyframeSegments() }
    }
}

extension KeyframeTrack: KeyframesRuntime {
    func makeTimeline(initialValue: Root) -> KeyframeTimeline<Root> {
        let segments = makeKeyframeSegments(from: content)
        let initialTrackValue: TrackValue
        if let keyPath {
            initialTrackValue = initialValue[keyPath: keyPath]
        } else {
            initialTrackValue = initialValue as! TrackValue
        }
        let trackTimeline = makeTrackTimeline(
            initialValue: initialTrackValue,
            segments: segments
        )
        return KeyframeTimeline(
            initialValue: initialValue,
            duration: trackTimeline.duration
        ) { root, time in
            let value = trackTimeline.value(time: time)
            if let keyPath {
                root[keyPath: keyPath] = value
            } else {
                root = value as! Root
            }
        }
    }

    private func makeTrackTimeline(
        initialValue: TrackValue,
        segments: [KeyframeSegment<TrackValue>]
    ) -> KeyframeTimeline<TrackValue> {
        let duration = segments.reduce(0) { $0 + $1.duration }
        return KeyframeTimeline(
            initialValue: initialValue,
            duration: duration
        ) { value, time in
            var previous = initialValue
            var elapsed = 0.0
            for segment in segments {
                let segmentEnd = elapsed + segment.duration
                if segment.duration == 0 {
                    previous = segment.to
                    elapsed = segmentEnd
                    continue
                }
                if time <= segmentEnd {
                    value = interpolate(
                        from: previous,
                        to: segment.to,
                        segment: segment,
                        time: max(0, time - elapsed)
                    )
                    return
                }
                elapsed = segmentEnd
                previous = segment.to
            }
            value = segments.last?.to ?? initialValue
        }
    }

    private func interpolate(
        from: TrackValue,
        to: TrackValue,
        segment: KeyframeSegment<TrackValue>,
        time: TimeInterval
    ) -> TrackValue {
        guard segment.duration > 0 else {
            return to
        }
        let progress = min(max(time / segment.duration, 0), 1)
        var value = from
        let delta = to.animatableData - from.animatableData
        switch segment.interpolation {
            case .linear(let curve):
                value.animatableData = from.animatableData
                    + delta.scaled(by: curve.value(at: progress))
            case .cubic:
                let curve = UnitCurve.easeInOut
                value.animatableData = from.animatableData
                    + delta.scaled(by: curve.value(at: progress))
            case .spring(let spring):
                value.animatableData = from.animatableData
                    + spring.value(target: delta, time: time)
            case .move:
                value = to
        }
        return value
    }
}

extension EmptyKeyframes: KeyframesRuntime {
    func makeTimeline(initialValue: Value) -> KeyframeTimeline<Value> {
        KeyframeTimeline(initialValue: initialValue)
    }
}

extension CombinedKeyframes: KeyframesRuntime {
    func makeTimeline(initialValue: Value) -> KeyframeTimeline<Value> {
        let timelines = components.map {
            $0.makeTimeline(initialValue: initialValue)
        }
        let duration = timelines.map(\.duration).max() ?? 0
        return KeyframeTimeline(
            initialValue: initialValue,
            duration: duration
        ) { value, time in
            for timeline in timelines {
                timeline.apply(to: &value, time: time)
            }
        }
    }
}

private func makeKeyframeSegments<Content: KeyframeTrackContent>(
    from content: Content
) -> [KeyframeSegment<Content.Value>] {
    if let runtime = content as? any AnyKeyframeTrackContentRuntime {
        return runtime.erasedKeyframeSegments() as? [KeyframeSegment<Content.Value>] ?? []
    }
    guard Content.Body.self != Content.self else {
        return []
    }
    return makeKeyframeSegments(from: content.body)
}

func makeKeyframeTimeline<Content: Keyframes>(
    from content: Content,
    initialValue: Content.Value
) -> KeyframeTimeline<Content.Value> {
    if let runtime = content as? any AnyKeyframesRuntime {
        return runtime.erasedTimeline(initialValue: initialValue)
            as? KeyframeTimeline<Content.Value> ?? KeyframeTimeline(
                initialValue: initialValue
            )
    }
    guard Content.Body.self != Content.self else {
        return KeyframeTimeline(initialValue: initialValue)
    }
    return makeKeyframeTimeline(from: content.body, initialValue: initialValue)
}
