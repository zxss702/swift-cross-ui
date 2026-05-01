extension EnvironmentValues {
    /// Persistent branch-local transaction values, as set by `.transaction`.
    @Entry var branchTransaction: Transaction = Transaction()

    /// The transient transaction for the current graph update.
    @Entry var currentTransaction: Transaction = Transaction()

    /// The transaction currently being applied to this branch of the view tree.
    public var transaction: Transaction {
        get {
            branchTransaction.overlaid(by: currentTransaction)
        }
        set {
            branchTransaction = newValue
        }
    }

    func applyingTransactionModifier(
        _ transform: @escaping (inout Transaction) -> Void
    ) -> EnvironmentValues {
        var environment = self
        var transaction = environment.branchTransaction
        transform(&transaction)
        environment.branchTransaction = transaction
        return environment
    }

    func withCurrentTransaction(_ transaction: Transaction) -> EnvironmentValues {
        var environment = self
        environment.currentTransaction = transaction
        return environment
    }

    func withoutCurrentTransaction() -> EnvironmentValues {
        var environment = self
        environment.currentTransaction = Transaction()
        return environment
    }
}
