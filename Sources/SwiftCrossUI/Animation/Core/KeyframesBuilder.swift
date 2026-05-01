/// A builder for keyframe track content.
@resultBuilder
public struct KeyframeTrackContentBuilder<Value: Animatable> {
    public static func buildExpression<K: KeyframeTrackContent>(_ expression: K) -> K
    where K.Value == Value {
        expression
    }

    public static func buildBlock() -> EmptyKeyframeTrackContent<Value> {
        EmptyKeyframeTrackContent()
    }

    public static func buildPartialBlock<K: KeyframeTrackContent>(first: K) -> K
    where K.Value == Value {
        first
    }

    public static func buildPartialBlock<
        Accumulated: KeyframeTrackContent,
        Next: KeyframeTrackContent
    >(
        accumulated: Accumulated,
        next: Next
    ) -> CombinedKeyframeTrackContent<Value>
    where Accumulated.Value == Value, Next.Value == Value {
        CombinedKeyframeTrackContent(
            components: [
                AnyKeyframeTrackContent(accumulated),
                AnyKeyframeTrackContent(next),
            ]
        )
    }

    public static func buildEither<First: KeyframeTrackContent, Second: KeyframeTrackContent>(
        first component: First
    ) -> Conditional<Value, First, Second>
    where First.Value == Value, Second.Value == Value {
        Conditional(storage: .first(component))
    }

    public static func buildEither<First: KeyframeTrackContent, Second: KeyframeTrackContent>(
        second component: Second
    ) -> Conditional<Value, First, Second>
    where First.Value == Value, Second.Value == Value {
        Conditional(storage: .second(component))
    }

    public struct Conditional<
        ConditionalValue: Animatable,
        First: KeyframeTrackContent,
        Second: KeyframeTrackContent
    >: KeyframeTrackContent where First.Value == ConditionalValue, Second.Value == ConditionalValue {
        public typealias Value = ConditionalValue
        public typealias Body = Conditional

        enum Storage {
            case first(First)
            case second(Second)
        }

        var storage: Storage
    }
}

/// A builder for keyframes.
@resultBuilder
public struct KeyframesBuilder<Value> {
    public static func buildExpression<Content: KeyframeTrackContent>(
        _ expression: Content
    ) -> Content where Content.Value == Value, Value: Animatable {
        expression
    }

    public static func buildExpression<Content: Keyframes>(_ expression: Content) -> Content
    where Content.Value == Value {
        expression
    }

    public static func buildBlock() -> EmptyKeyframes<Value> {
        EmptyKeyframes()
    }

    public static func buildPartialBlock<Content: Keyframes>(first: Content) -> Content
    where Content.Value == Value {
        first
    }

    public static func buildPartialBlock<Content: KeyframeTrackContent>(
        first: Content
    ) -> Content where Content.Value == Value, Value: Animatable {
        first
    }

    public static func buildPartialBlock<Accumulated: Keyframes, Next: Keyframes>(
        accumulated: Accumulated,
        next: Next
    ) -> CombinedKeyframes<Value>
    where Accumulated.Value == Value, Next.Value == Value {
        CombinedKeyframes(
            components: [
                AnyKeyframes(accumulated),
                AnyKeyframes(next),
            ]
        )
    }

    public static func buildPartialBlock<
        Accumulated: KeyframeTrackContent,
        Next: KeyframeTrackContent
    >(
        accumulated: Accumulated,
        next: Next
    ) -> CombinedKeyframeTrackContent<Value>
    where Accumulated.Value == Value, Next.Value == Value, Value: Animatable {
        CombinedKeyframeTrackContent(
            components: [
                AnyKeyframeTrackContent(accumulated),
                AnyKeyframeTrackContent(next),
            ]
        )
    }

    public static func buildFinalResult<Content: KeyframeTrackContent>(
        _ component: Content
    ) -> KeyframeTrack<Value, Value, Content> where Content.Value == Value, Value: Animatable {
        KeyframeTrack { component }
    }

    public static func buildFinalResult<Content: Keyframes>(_ component: Content) -> Content
    where Content.Value == Value {
        component
    }
}

extension KeyframeTrackContentBuilder.Conditional: KeyframeTrackContentRuntime {
    func keyframeSegments() -> [KeyframeSegment<ConditionalValue>] {
        switch storage {
            case .first(let content):
                AnyKeyframeTrackContent(content).keyframeSegments()
            case .second(let content):
                AnyKeyframeTrackContent(content).keyframeSegments()
        }
    }
}
