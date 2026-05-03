import Foundation

struct LayoutInputKey: Hashable {
    var type: ObjectIdentifier
    var values: [AnyHashable]
}

@MainActor
protocol LayoutInputKeyProvider {
    var layoutInputKey: AnyHashable? { get }
}

enum LayoutInputKeys {
    static func make(_ type: Any.Type, values: [AnyHashable] = []) -> AnyHashable {
        AnyHashable(LayoutInputKey(type: ObjectIdentifier(type), values: values))
    }

    @MainActor
    static func key<V: View>(for view: V) -> AnyHashable? {
        if let key = (view as? any LayoutInputKeyProvider)?.layoutInputKey {
            return key
        }
        return nil
    }

    @MainActor
    static func wrapping<V: View>(
        _ type: Any.Type,
        child: V,
        values: [AnyHashable] = []
    ) -> AnyHashable? {
        guard let childKey = key(for: child) else {
            return nil
        }
        return make(type, values: values + [childKey])
    }
}

extension EnvironmentValues {
    @MainActor
    var layoutInputFingerprint: AnyHashable {
        LayoutInputKeys.make(
            EnvironmentValues.self,
            values: [
                AnyHashable(String(describing: resolvedFont)),
                AnyHashable(String(describing: multilineTextAlignment)),
                AnyHashable(String(describing: lineLimitSettings)),
                AnyHashable(windowScaleFactor),
                AnyHashable(isEnabled),
            ]
        )
    }
}
