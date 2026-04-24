import Foundation
import Mutex

#if canImport(Observation)
    import Observation
#endif

final class ObservationTrackingState: @unchecked Sendable {
    private let generation = Mutex(0)

    func beginTracking() -> Int {
        generation.withLock { generation in
            generation += 1
            return generation
        }
    }

    func isCurrent(_ currentGeneration: Int) -> Bool {
        generation.withLock { generation in
            generation == currentGeneration
        }
    }
}

@MainActor
protocol ViewModelObserver: AnyObject, Sendable {
    var observationTrackingState: ObservationTrackingState { get }

    func viewModelDidChange<Backend: AppBackend>(backend: Backend)
}

extension ViewModelObserver {
    func observe<Backend: AppBackend, Result>(
        in backend: Backend,
        _ computation: () -> Result
    ) -> Result {
        withObservationTrackingIfAvailable(
            state: observationTrackingState,
            apply: computation,
            onChange: { [weak self, backend] in
                backend.runInMainThread {
                    self?.viewModelDidChange(backend: backend)
                }
            }
        )
    }
}

@inline(__always)
func withObservationTrackingIfAvailable<T>(
    state: ObservationTrackingState,
    apply: () -> T,
    onChange: @escaping @Sendable () -> Void
) -> T {
    #if canImport(Observation)
        if #available(macOS 14.0, iOS 17.0, tvOS 17.0, watchOS 10.0, visionOS 1.0, *) {
            let generation = state.beginTracking()
            return withObservationTracking(
                apply,
                onChange: { [weak state] in
                    guard let state, state.isCurrent(generation) else {
                        return
                    }
                    onChange()
                }
            )
        }
    #endif

    return apply()
}
