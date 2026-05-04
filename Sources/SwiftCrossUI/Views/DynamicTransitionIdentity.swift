import Foundation

struct DynamicTransitionIdentity: Hashable {
    var type: ObjectIdentifier
    var id: AnyHashable?

    init<V>(type: V.Type, id: AnyHashable? = nil) {
        self.type = ObjectIdentifier(type)
        self.id = id
    }
}
