// Re-export the real `Observation` module when it ships with the toolchain
// (it provides `@Observable` / `@ObservationIgnored` / `Observable`
// cross-platform). `ObservationPolyfill` back-ports the same names for older
// toolchains; re-exporting both would make them ambiguous.
#if canImport(Observation)
    @_exported import Observation
#elseif os(iOS) || os(macOS) || os(tvOS) || os(watchOS)
    @_exported import ObservationPolyfill
#endif
