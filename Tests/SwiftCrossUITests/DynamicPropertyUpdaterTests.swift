import Testing

import DummyBackend
@testable import SwiftCrossUI

private final class TokenBackedStorage {
    var updateCount = 0
}

private struct TokenBackedProperty: DynamicProperty, DynamicPropertyLocationToken {
    var prefix: UInt8 = 1
    var storage: TokenBackedStorage
    var suffix: UInt16 = 2

    var dynamicPropertyLocationToken: AnyObject {
        storage
    }

    func update(
        with environment: EnvironmentValues,
        previousValue: TokenBackedProperty?
    ) {
        storage.updateCount += 1
    }
}

private struct TokenBackedBase {
    var prefix: UInt8 = 3
    var dynamic: TokenBackedProperty
    var suffix: UInt8 = 4
}

private struct UntokenedProperty: DynamicProperty {
    var storage: TokenBackedStorage

    func update(
        with environment: EnvironmentValues,
        previousValue: UntokenedProperty?
    ) {
        storage.updateCount += 1
    }
}

private struct UntokenedBase {
    var dynamic: UntokenedProperty
}

@Suite("Dynamic property updater")
struct DynamicPropertyUpdaterTests {
    @Test("Uses location tokens to build fast property updaters")
    @MainActor
    func usesLocationTokensForFastUpdaters() {
        updaterCache.removeValue(forKey: ObjectIdentifier(TokenBackedBase.self))

        let storage = TokenBackedStorage()
        let base = TokenBackedBase(
            dynamic: TokenBackedProperty(storage: storage)
        )

        let updater = DynamicPropertyUpdater(for: base)

        #expect(updater.propertyUpdaters?.count == 1)

        updater.update(
            base,
            with: EnvironmentValues(backend: DummyBackend()),
            previousValue: nil
        )

        #expect(storage.updateCount == 1)
    }

    @Test("Caches Mirror fallback when offset discovery fails")
    @MainActor
    func cachesMirrorFallback() {
        updaterCache.removeValue(forKey: ObjectIdentifier(UntokenedBase.self))

        let storage = TokenBackedStorage()
        let base = UntokenedBase(
            dynamic: UntokenedProperty(storage: storage)
        )

        let firstUpdater = DynamicPropertyUpdater(for: base)
        #expect(firstUpdater.propertyUpdaters == nil)

        let cachedUpdater =
            updaterCache[ObjectIdentifier(UntokenedBase.self)]
            as? DynamicPropertyUpdater<UntokenedBase>
        #expect(cachedUpdater?.propertyUpdaters == nil)

        let secondUpdater = DynamicPropertyUpdater(for: base)
        #expect(secondUpdater.propertyUpdaters == nil)

        secondUpdater.update(
            base,
            with: EnvironmentValues(backend: DummyBackend()),
            previousValue: nil
        )

        #expect(storage.updateCount == 1)
    }
}
