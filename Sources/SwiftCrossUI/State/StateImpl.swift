struct StateImpl<Storage: StateStorageProtocol> {
    /// The inner storage of `StateImpl`.
    ///
    /// The inner `Storage` is what stays constant between view updates.
    /// The wrapping box is used so that we can assign the storage to future
    /// state instances from the non-mutating ``update(with:previousValue:)``
    /// method. It's vital that the inner storage remains the same so that
    /// bindings can be stored across view updates.
    var box: Box<Storage>

    var storage: Storage {
        get { box.value }
        nonmutating set { box.value = newValue }
    }

    init(initialStorage: Storage) {
        self.box = Box(initialStorage)

        // Before casting the value we check the type, because casting an optional
        // to protocol Optional doesn't conform to can still succeed when the value
        // is `.some` and the wrapped type conforms to the protocol.
        storage.relinkDownstreamObservation()
    }

    var wrappedValue: Storage.Value {
        get {
            if GraphUpdateContext.isUpdating {
                storage.wasRead = true
            }
            return storage.value
        }
        nonmutating set {
            storage.value = newValue
            storage.postSet(transaction: TransactionContext.current)
        }
    }

    var projectedValue: Binding<Storage.Value> {
        // Specifically link the binding to the inner storage instead of the
        // outer box which changes with each view update.
        let storage = storage
        return Binding(
            get: {
                if GraphUpdateContext.isUpdating {
                    storage.wasRead = true
                }
                return storage.value
            },
            set: { newValue, transaction in
                storage.value = newValue
                storage.postSet(transaction: transaction)
            }
        )
    }

    func update(with environment: EnvironmentValues, previousValue: Self?) {
        if let previousValue {
            storage = previousValue.storage
        }
        if !RenderFrameContext.isRendering {
            storage.wasRead = false
        }
    }
}

protocol StateStorageProtocol: AnyObject {
    associatedtype Value
    var value: Value { get set }
    var wasRead: Bool { get set }
    var didChange: Publisher { get }
    var downstreamObservation: Cancellable? { get set }
}

extension StateStorageProtocol {
    /// Call this to publish an observation to all observers after
    /// setting a new value. This isn't in a `didSet` property accessor
    /// because we want more granular control over when it does and
    /// doesn't trigger.
    ///
    /// Additionally updates the downstream observation if the
    /// wrapped value is an `Optional<some ObservableObject>` and the
    /// current case has toggled.
    func postSet(transaction: Transaction = TransactionContext.current) {
        StateMutationContext.withTransaction(transaction) {
            relinkDownstreamObservation()
            if wasRead {
                didChange.send()
            }
        }
    }

    /// Links observable values stored inside state back into this state location.
    ///
    /// This remains a compatibility bridge for legacy ``ObservableObject`` and
    /// ``Published``. It still respects graph dependency tracking: an upstream
    /// object mutation only invalidates this state owner after the state was
    /// read by the last graph update.
    func relinkDownstreamObservation() {
        downstreamObservation?.cancel()
        downstreamObservation = nil

        guard let upstreamDidChange = downstreamPublisher else {
            return
        }

        downstreamObservation = upstreamDidChange.observe { [weak self] in
            guard let self, self.wasRead else {
                return
            }
            self.didChange.send()
        }
    }

    private var downstreamPublisher: Publisher? {
        // Before casting the value we check the type, because casting an optional
        // to a protocol Optional doesn't conform to can still succeed when the
        // value is `.some` and the wrapped type conforms to the protocol.
        if Value.self is ObservableObject.Type,
            let value = value as? ObservableObject
        {
            return value.didChange
        }

        if let value = value as? OptionalObservableObject {
            return value.didChange
        }

        return nil
    }
}
