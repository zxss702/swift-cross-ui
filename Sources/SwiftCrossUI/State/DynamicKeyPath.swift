#if canImport(Darwin)
    import func Darwin.memcmp
#elseif canImport(Glibc)
    import func Glibc.memcmp
#elseif canImport(WinSDK)
    import func WinSDK.memcmp
#elseif canImport(Android)
    import func Android.memcmp
#endif

/// A type similar to KeyPath, but that can be constructed at run time given
/// an instance of a struct, and the value of the desired property.
///
/// Construction fails if the property doesn't expose a stable reference token,
/// or if that token's in-memory representation is not unique within the struct.
/// SwiftCrossUI's dynamic property wrappers expose their internal storage
/// object as that token.
struct DynamicKeyPath<Base, Value> {
    /// The property's offset within instances of `Base`.
    var offset: Int

    /// Constructs a key path given an instance of the base type, and the
    /// value of the desired property.
    ///
    /// The initializer will find a stable reference token inside the property,
    /// then search for that token inside the base instance. The difference
    /// between those two token offsets is the property's offset. If such an
    /// offset can't be found or isn't unique, then the initialiser returns
    /// `nil`.
    ///
    /// - Parameters:
    ///   - value: The value to construct a key path to.
    ///   - base: The value to construct a key path from.
    ///   - label: The property's label, if any. Only used for debugging.
    init?(
        forProperty value: Value,
        of base: Base,
        label: String? = nil
    ) {
        guard let valueWithToken = value as? any DynamicPropertyLocationToken else {
            logger.warning(
                "no location token found for dynamic property",
                metadata: ["property": "\(label ?? "<unknown>")"]
            )
            return nil
        }

        guard
            let offset = Self.offsetUsingLocationToken(
                valueWithToken.dynamicPropertyLocationToken,
                property: value,
                base: base,
                label: label
            )
        else {
            return nil
        }

        self.offset = offset
    }

    private static func offsetUsingLocationToken(
        _ token: AnyObject,
        property: Value,
        base: Base,
        label: String?
    ) -> Int? {
        var tokenPointer = UInt(bitPattern: Unmanaged.passUnretained(token).toOpaque())

        guard
            let tokenOffsetInProperty = uniqueMatchOffset(
                of: &tokenPointer,
                in: property
            )
        else {
            logger.warning(
                "no token offset found for dynamic property",
                metadata: ["property": "\(label ?? "<unknown>")"]
            )
            return nil
        }

        let propertyAlignment = MemoryLayout<Value>.alignment
        let propertySize = MemoryLayout<Value>.size
        let baseStructSize = MemoryLayout<Base>.size
        let pointerSize = MemoryLayout<UInt>.size

        var matches: Set<Int> = []
        withUnsafeBytes(of: base) { basePointer in
            withUnsafeBytes(of: &tokenPointer) { tokenPointerBytes in
                guard
                    let baseAddress = basePointer.baseAddress,
                    let tokenPointerAddress = tokenPointerBytes.baseAddress
                else {
                    return
                }

                var index = 0
                while index + pointerSize <= baseStructSize {
                    let isMatch =
                        memcmp(
                            baseAddress.advanced(by: index),
                            tokenPointerAddress,
                            pointerSize
                        ) == 0

                    if isMatch {
                        let propertyOffset = index - tokenOffsetInProperty
                        if propertyOffset >= 0,
                            propertyOffset + propertySize <= baseStructSize,
                            propertyOffset % propertyAlignment == 0
                        {
                            matches.insert(propertyOffset)
                        }
                    }

                    index += 1
                }
            }
        }

        guard let offset = matches.first else {
            logger.warning(
                "no offset found for dynamic property",
                metadata: ["property": "\(label ?? "<unknown>")"]
            )
            return nil
        }

        guard matches.count == 1 else {
            logger.warning(
                "multiple offsets found for dynamic property",
                metadata: ["property": "\(label ?? "<unknown>")"]
            )
            return nil
        }

        return offset
    }

    private static func uniqueMatchOffset<Needle, Haystack>(
        of needle: inout Needle,
        in haystack: Haystack
    ) -> Int? {
        let needleSize = MemoryLayout<Needle>.size
        let haystackSize = MemoryLayout<Haystack>.size
        var matches: [Int] = []

        withUnsafeBytes(of: haystack) { haystackPointer in
            withUnsafeBytes(of: &needle) { needlePointer in
                guard
                    let haystackAddress = haystackPointer.baseAddress,
                    let needleAddress = needlePointer.baseAddress
                else {
                    return
                }

                var index = 0
                while index + needleSize <= haystackSize {
                    if memcmp(
                        haystackAddress.advanced(by: index),
                        needleAddress,
                        needleSize
                    ) == 0 {
                        matches.append(index)
                    }
                    index += 1
                }
            }
        }

        guard matches.count == 1 else {
            return nil
        }

        return matches[0]
    }

    /// Gets the property's value on the given instance.
    ///
    /// - Parameter base: The instance to get the property on.
    /// - Returns: This property's value on `base`.
    func get(_ base: Base) -> Value {
        withUnsafeBytes(of: base) { buffer in
            buffer.baseAddress!.advanced(by: offset)
                .assumingMemoryBound(to: Value.self)
                .pointee
        }
    }

    /// Sets the property's value to a new value on the given instance.
    ///
    /// - Parameters:
    ///   - base: The instance to set the property on.
    ///   - newValue: The new value of the property.
    func set(_ base: inout Base, _ newValue: Value) {
        withUnsafeMutableBytes(of: &base) { buffer in
            buffer.baseAddress!.advanced(by: offset)
                .assumingMemoryBound(to: Value.self)
                .pointee = newValue
        }
    }
}
