import Foundation
import ImageFormats

#if canImport(LibPNG)
    import LibPNG
#endif

/// A view that displays an image.
public struct Image: Sendable {
    /// Whether the image is resizable.
    private var isResizable = false
    /// The image's rendering mode.
    var renderingMode: ImageRenderingMode = .original
    /// The source of the image.
    private var source: Source

    enum Source: Equatable {
        case url(URL, useFileExtension: Bool)
        case image(ImageFormats.Image<RGBA>)
        /// A pre-rendered system symbol image. Like SF Symbols on Apple
        /// platforms, symbol images size themselves relative to the current
        /// font rather than at their pixel size, and are always resizable.
        case symbol(URL)
        /// A system symbol rendered natively as an icon-font glyph (e.g.
        /// Segoe Fluent Icons on Windows), rather than a pre-rendered
        /// bitmap. Carries the glyph text. Vector glyphs stay crisp at any
        /// size/scale factor and blend correctly at any opacity.
        case symbolGlyph(String)
    }

    /// Creates an image view.
    ///
    /// `png`, `jpg`, and `webp` are supported.
    ///
    /// - Parameters:
    ///   - url: The URL of the file to display.
    ///   - useFileExtension: If `true`, the file extension is used to determine
    ///     the file type, otherwise the first few ('magic') bytes of the file
    ///     are used.
    public init(_ url: URL, useFileExtension: Bool = true) {
        source = .url(url, useFileExtension: useFileExtension)
    }

    /// Displays an image from raw pixel data.
    ///
    /// - Parameter image: The image data to display.
    public init(_ image: ImageFormats.Image<RGBA>) {
        source = .image(image)
    }

    /// Creates an image view from a file path.
    ///
    /// Convenience for `init(URL(fileURLWithPath:))`.
    public init(filePath: String) {
        self.init(URL(fileURLWithPath: filePath))
    }

    /// Creates an image view from a system symbol name.
    ///
    /// On platforms with a native icon font (Windows: Segoe Fluent Icons),
    /// symbol names render as real font glyphs. Otherwise symbol assets are
    /// looked up as `sfsymbols/<name>.imageset/<name>.png` (optionally under
    /// an `Assets.xcassets` prefix) in the resource bundles of every SwiftPM
    /// target linked into the running process — expected to be pre-rendered
    /// PNGs, e.g. exported from SF Symbols.
    public init(systemName: String) {
        #if os(Windows)
            self.init(.symbolGlyph(FluentSymbolGlyphs.glyph(for: systemName)), resizable: false)
        #else
            if let url = Self.symbolURL(named: systemName) {
                self.init(url, symbol: true)
            } else {
                self.init(URL(fileURLWithPath: ""))
            }
        #endif
    }

    private init(_ url: URL, symbol: Bool) {
        source = symbol ? .symbol(url) : .url(url, useFileExtension: true)
    }

    /// Creates an image view from a named asset.
    ///
    /// Assets are looked up as `<name>.imageset` in the resource bundles of
    /// every SwiftPM target linked into the running process. If no asset
    /// matches, the name is treated as a system symbol name, so catalog
    /// names that are also symbol names (e.g. `sparkles.2`) still resolve.
    public init(_ name: String) {
        if let url = Self.assetURL(named: name) {
            self.init(url)
        } else {
            self.init(systemName: name)
        }
    }

    /// Caches for bundle lookups and pixel decoding. Resource bundles don't
    /// change at runtime, so lookup results are memoized indefinitely — both
    /// to avoid filesystem enumeration on every view body re-evaluation and to
    /// decode each asset's pixels at most once regardless of how many `Image`
    /// nodes reference it.
    enum ResourceCache {
        struct PixelsKey: Hashable {
            var url: URL
            var useFileExtension: Bool
        }

        private static let lock = NSLock()
        private static var symbolURLs: [String: URL?] = [:]
        private static var assetURLs: [String: URL?] = [:]
        private static var pixels:
            [PixelsKey: (bytes: [UInt8], width: Int, height: Int)?] = [:]

        static func symbolURL(named name: String, resolve: () -> URL?) -> URL? {
            lock.lock()
            defer { lock.unlock() }
            if let cached = symbolURLs[name] { return cached }
            let resolved = resolve()
            symbolURLs[name] = resolved
            return resolved
        }

        static func assetURL(named name: String, resolve: () -> URL?) -> URL? {
            lock.lock()
            defer { lock.unlock() }
            if let cached = assetURLs[name] { return cached }
            let resolved = resolve()
            assetURLs[name] = resolved
            return resolved
        }

        static func pixels(
            for url: URL,
            useFileExtension: Bool,
            decode: () -> (bytes: [UInt8], width: Int, height: Int)?
        ) -> (bytes: [UInt8], width: Int, height: Int)? {
            let key = PixelsKey(url: url, useFileExtension: useFileExtension)
            lock.lock()
            if let cached = pixels[key] {
                lock.unlock()
                return cached
            }
            lock.unlock()
            // Decode outside the lock: holding it across a slow decode makes
            // the prefetch task block the main thread's unrelated lookups.
            let decoded = decode()
            lock.lock()
            if let raced = pixels[key] {
                lock.unlock()
                return raced
            }
            pixels[key] = decoded
            lock.unlock()
            return decoded
        }
    }

    /// Searches the app's resource bundles for `<name>.imageset` and returns
    /// the first image file inside. Asset catalogs flatten group folders at
    /// compile time on Apple platforms, so nested groups (e.g.
    /// `badge/fileIcon`) are searched recursively.
    static func assetURL(named name: String) -> URL? {
        ResourceCache.assetURL(named: name) { assetURLUncached(named: name) }
    }

    private static func assetURLUncached(named name: String) -> URL? {
        for bundle in resourceBundleDirectories() {
            if let file = firstImageFile(
                in: bundle.appendingPathComponent("\(name).imageset")
            ) {
                return file
            }
            if let url = findImageFile(
                inImageSetNamed: name,
                under: bundle.appendingPathComponent("Assets.xcassets")
            ) {
                return url
            }
        }
        return nil
    }

    /// Recursively searches `directory` for `<name>.imageset` (any nesting
    /// depth) and returns the first image file inside.
    private static func findImageFile(inImageSetNamed name: String, under directory: URL) -> URL? {
        let direct = directory.appendingPathComponent("\(name).imageset")
        if let file = firstImageFile(in: direct) {
            return file
        }
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: .skipsHiddenFiles
        ) else {
            return nil
        }
        for entry in entries {
            guard (try? entry.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true,
                entry.pathExtension != "imageset"
            else {
                continue
            }
            if let url = findImageFile(inImageSetNamed: name, under: entry) {
                return url
            }
        }
        return nil
    }

    /// Returns the first image file inside an `.imageset` directory.
    private static func firstImageFile(in imageSet: URL) -> URL? {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: imageSet,
            includingPropertiesForKeys: nil
        ) else {
            return nil
        }
        return files.first { url in
            ["png", "jpg", "jpeg", "svg"].contains(url.pathExtension.lowercased())
                && !url.lastPathComponent.hasPrefix("Contents")
        }
    }

    /// Searches the app's resource bundles for `sfsymbols/<name>.imageset`
    /// and returns the first image file inside.
    static func symbolURL(named name: String) -> URL? {
        ResourceCache.symbolURL(named: name) { symbolURLUncached(named: name) }
    }

    private static func symbolURLUncached(named name: String) -> URL? {
        let bundleDirs = resourceBundleDirectories()
        let imageSetDirs = [
            "Assets.xcassets/sfsymbols/\(name).imageset",
            "sfsymbols/\(name).imageset",
        ]
        for bundle in bundleDirs {
            for dir in imageSetDirs {
                let base = bundle.appendingPathComponent(dir)
                guard let files = try? FileManager.default.contentsOfDirectory(
                    at: base,
                    includingPropertiesForKeys: nil
                ) else {
                    continue
                }
                if let file = files.first(where: {
                    ["png", "jpg", "jpeg", "svg"].contains(
                        $0.pathExtension.lowercased()
                    )
                }) {
                    return file
                }
            }
        }
        return nil
    }

    /// The resource bundle directories of the running process. SwiftPM places
    /// each target's processed resources in a `<Package>_<Target>.resources`
    /// (or `.bundle`, depending on toolchain/platform) bundle next to the
    /// executable.
    static func resourceBundleDirectories() -> [URL] {
        var dirs: [URL] = []
        // The executable's own directory (for apps with flattened resources).
        let main = Bundle.main.bundleURL
        if main.pathExtension == "resources" || main.pathExtension == "bundle" {
            dirs.append(main)
        }
        // SwiftPM's `<Package>_<Target>.bundle` lives next to the executable
        // on Darwin (inside the .app wrapper) *inside* `main`, but on
        // freestanding-bundle platforms (Windows, Linux) `main` is the
        // executable's directory itself so the bundle is a child of `main`,
        // not a sibling. Scan both.
        for scanned in [main, main.deletingLastPathComponent()] {
            // Resolve symlinks first (SwiftPM's debug/ dir is often a symlink,
            // and `contentsOfDirectory(at:)` on a symlinked directory URL can
            // return empty on Windows), then enumerate via the path-based API.
            let resolved = scanned.resolvingSymlinksInPath()
            guard
                let children = try? FileManager.default.contentsOfDirectory(
                    atPath: resolved.path
                )
            else { continue }
            for name in children {
                let url = resolved.appendingPathComponent(name)
                guard url.pathExtension == "resources" || url.pathExtension == "bundle"
                else { continue }
                if !dirs.contains(url) {
                    dirs.append(url)
                }
            }
        }
        // Also check one level deeper for nested app structures.
        if let resourceDir = Bundle.main.resourceURL, resourceDir != main {
            dirs.append(resourceDir)
        }
        return dirs
    }

    /// Makes the image resize to fit the available space.
    public func resizable() -> Self {
        var image = self
        image.isResizable = true
        return image
    }

    /// Sets the rendering mode of the image.
    ///
    /// Only `.original` and `.template` are meaningful today; both are stored
    /// but not yet interpreted by backends.
    public func renderingMode(_ renderingMode: ImageRenderingMode) -> Self {
        var image = self
        image.renderingMode = renderingMode
        return image
    }

    init(_ source: Source, resizable: Bool) {
        self.source = source
        self.isResizable = resizable
    }
}

/// The rendering mode of an ``Image``, as in SwiftUI.
public enum ImageRenderingMode: Sendable, Hashable {
    /// Render the image's original colors.
    case original
    /// Render the image as a template tinted by the foreground color.
    case template
}

extension Image {
    /// Decodes the image at `url` into raw RGBA8 pixels.
    ///
    /// `png`, `jpg`, and `webp` are supported.
    ///
    /// - Parameters:
    ///   - url: The URL of the file to decode.
    ///   - useFileExtension: If `true`, the file extension is used to determine
    ///     the file type, otherwise the first few ('magic') bytes of the file
    ///     are used.
    public static func decodePixels(
        from url: URL,
        useFileExtension: Bool = true
    ) -> (bytes: [UInt8], width: Int, height: Int)? {
        ResourceCache.pixels(for: url, useFileExtension: useFileExtension) {
            decodePixelsUncached(from: url, useFileExtension: useFileExtension)
        }
    }

    private static func decodePixelsUncached(
        from url: URL,
        useFileExtension: Bool
    ) -> (bytes: [UInt8], width: Int, height: Int)? {
        guard let data = try? Data(contentsOf: url) else {
            return nil
        }
        let bytes = Array(data)
        let image: ImageFormats.Image<RGBA>?
        let pngMagicBytes: [UInt8] = [0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]
        let isPNG =
            useFileExtension
            ? url.pathExtension.lowercased() == "png"
            : bytes.starts(with: pngMagicBytes)
        if isPNG, let decoded = decodePNG(bytes) {
            image = decoded
        } else if useFileExtension {
            image = try? .load(from: bytes, usingFileExtension: url.pathExtension)
        } else {
            image = try? .load(from: bytes)
        }
        guard let image else {
            return nil
        }
        return (image.bytes, image.width, image.height)
    }

    /// Decodes PNG data with libpng's simplified API. Mirrors
    /// `ImageFormats.Image.loadPNG` but sets `PNG_IMAGE_FLAG_16BIT_sRGB`:
    /// for 16-bit-per-component files libpng otherwise defaults to assuming
    /// linear-light input (the simplified API ignores the transfer curves
    /// declared by iCCP/cICP colour-profile chunks, e.g. Display-P3 exports),
    /// then encodes the output as sRGB — visibly washing colours out.
    /// Treating 16-bit input as sRGB-encoded preserves the stored values,
    /// which is what platform image renderers (NSImage etc.) effectively show.
    private static func decodePNG(_ bytes: [UInt8]) -> ImageFormats.Image<RGBA>? {
        #if canImport(LibPNG)
            var image = png_image()
            memset(&image, 0, MemoryLayout<png_image>.size)
            image.version = 1  // PNG_IMAGE_VERSION

            guard png_image_begin_read_from_memory(&image, bytes, bytes.count) != 0 else {
                return nil
            }

            image.format = 3  // PNG_FORMAT_RGBA
            image.flags |= 0x04  // PNG_IMAGE_FLAG_16BIT_sRGB

            var rgbaBytes = [UInt8](repeating: 0, count: Int(image.width * image.height * 4))
            guard png_image_finish_read(&image, nil, &rgbaBytes, 0, nil) != 0 else {
                png_image_free(&image)
                return nil
            }

            return ImageFormats.Image<RGBA>(
                width: Int(image.width),
                height: Int(image.height),
                bytes: rgbaBytes
            )
        #else
            return try? ImageFormats.Image<RGBA>.loadPNG(from: bytes)
        #endif
    }

    /// Decoded RGBA8 pixels of a named bundled asset, or `nil` if the asset
    /// does not exist or cannot be decoded.
    public static func assetPixels(
        named name: String
    ) -> (bytes: [UInt8], width: Int, height: Int)? {
        guard let url = assetURL(named: name) else {
            return nil
        }
        return decodePixels(from: url)
    }

    /// Decodes every bundled image asset on a background thread so that
    /// later `Image` layouts hit the pixel cache instead of decoding
    /// synchronously mid-transition (which stalls page pushes noticeably on
    /// debug builds where the decoder is unoptimized).
    public static func prefetchBundledAssets() {
        var files: [URL] = []
        for bundle in resourceBundleDirectories() {
            guard
                let enumerator = FileManager.default.enumerator(
                    at: bundle,
                    includingPropertiesForKeys: nil
                )
            else { continue }
            for case let url as URL in enumerator {
                let ext = url.pathExtension.lowercased()
                if ext == "png" || ext == "jpg" || ext == "jpeg" || ext == "webp" {
                    files.append(url)
                }
            }
        }
        Task.detached(priority: .utility) {
            for file in files {
                _ = decodePixels(from: file)
            }
        }
    }
}

extension Image: View {
    public var body: some View { return EmptyView() }
}

extension Image: TypeSafeView {
    func layoutableChildren<Backend: BaseAppBackend>(
        backend: Backend,
        children: ImageChildren
    ) -> [LayoutSystem.LayoutableChild] {
        []
    }

    func children<Backend: BaseAppBackend>(
        backend: Backend,
        snapshots: [ViewGraphSnapshotter.NodeSnapshot]?,
        environment: EnvironmentValues
    ) -> ImageChildren {
        let children = ImageChildren(backend: backend)
        if case .symbolGlyph = source {
            children.symbolWidget = Self.makeSymbolWidget(backend: backend)
        }
        return children
    }

    /// Creates the icon-font widget for glyph-based symbols when the backend
    /// supports ``BackendFeatures/SymbolViews``.
    @MainActor
    private static func makeSymbolWidget<Backend: BaseAppBackend>(
        backend: Backend
    ) -> AnyWidget? {
        guard
            let casted = backend as? any BaseAppBackend & BackendFeatures.SymbolViews
        else { return nil }
        func make<NewBackend: BaseAppBackend & BackendFeatures.SymbolViews>(
            _ backend: NewBackend
        ) -> AnyWidget {
            AnyWidget(backend.createSymbolView())
        }
        return make(casted)
    }

    func asWidget<Backend: BaseAppBackend>(
        _ children: ImageChildren,
        backend: Backend
    ) -> Backend.Widget {
        children.container.into()
    }

    func computeLayout<Backend: BaseAppBackend>(
        _ widget: Backend.Widget,
        children: ImageChildren,
        proposedSize: ProposedViewSize,
        environment: EnvironmentValues,
        backend: Backend
    ) -> ViewLayoutResult {
        let image: ImageFormats.Image<RGBA>?
        if source != children.cachedImageSource {
            switch source {
                case .url(let url, let useFileExtension):
                    if let decoded = Image.decodePixels(
                        from: url,
                        useFileExtension: useFileExtension
                    ) {
                        image = ImageFormats.Image<RGBA>(
                            width: decoded.width,
                            height: decoded.height,
                            bytes: decoded.bytes
                        )
                    } else {
                        image = nil
                    }
                case .symbol(let url):
                    image = Image.decodePixels(from: url).map { decoded in
                        ImageFormats.Image<RGBA>(
                            width: decoded.width,
                            height: decoded.height,
                            bytes: decoded.bytes
                        )
                    }
                case .symbolGlyph:
                    // Glyphs render via the backend's icon font; there is no
                    // bitmap to decode.
                    image = nil
                case .image(let sourceImage):
                    image = sourceImage
            }

            children.cachedImageSource = source
            children.cachedImage = image
            children.imageChanged = true
        } else {
            image = children.cachedImage
        }

        let size: ViewSize
        if case .symbolGlyph = source, children.symbolWidget != nil {
            // Icon-font glyphs size to the current font's em square, like
            // SF Symbols sizing to the point size.
            let fontSize = environment.font
                .resolve(in: environment.fontResolutionContext).pointSize
            let idealSize = ViewSize(
                fontSize.rounded(.awayFromZero),
                fontSize.rounded(.awayFromZero)
            )
            if isResizable {
                size = proposedSize.replacingUnspecifiedDimensions(by: idealSize)
            } else {
                size = idealSize
            }
        } else if let image {
            var idealSize = ViewSize(Double(image.width), Double(image.height))
            if case .symbol = source {
                // Symbol images behave like SF Symbols: they hug the current
                // font size (scaled by aspect ratio) instead of their pixel
                // size, and only expand to fill a proposal when explicitly
                // made resizable.
                let fontSize = environment.font
                    .resolve(in: environment.fontResolutionContext).pointSize
                let aspect = idealSize.width / max(idealSize.height, 1)
                idealSize = ViewSize(
                    (fontSize * aspect).rounded(.awayFromZero),
                    fontSize
                )
            }
            if isResizable {
                size = proposedSize.replacingUnspecifiedDimensions(by: idealSize)
            } else {
                size = idealSize
            }
        } else {
            size = .zero
        }

        return ViewLayoutResult.leafView(size: size)
    }

    func commit<Backend: BaseAppBackend>(
        _ widget: Backend.Widget,
        children: ImageChildren,
        layout: ViewLayoutResult,
        environment: EnvironmentValues,
        backend: Backend
    ) {
        let size = layout.size.vector
        let hasResized = children.cachedImageDisplaySize != size
        children.cachedImageDisplaySize = size

        if case .symbolGlyph(let glyph) = source, let symbolWidget = children.symbolWidget {
            // Native icon-font path: no pixels involved — the backend draws
            // the glyph at the laid-out em size with the environment's
            // foreground color.
            if let casted = backend as? any BaseAppBackend & BackendFeatures.SymbolViews {
                func update<NewBackend: BaseAppBackend & BackendFeatures.SymbolViews>(
                    _ backend: NewBackend
                ) {
                    backend.updateSymbolView(
                        symbolWidget.into(),
                        glyph: glyph,
                        fontSize: Double(size.y),
                        environment: environment
                    )
                }
                update(casted)
            }
            setDisplayedWidget(symbolWidget, children: children, backend: backend)
            backend.setSize(of: children.container.into(), to: size)
            // Give the glyph widget its natural measured size rather than the
            // em square: icon glyphs have ink that legitimately extends past
            // the em box (wider strokes at heavier weights, optical overhang),
            // and squeezing the widget into the em square clips those strokes.
            // The container doesn't clip its children, so centring the
            // naturally-sized glyph keeps it optically centred while letting
            // the full ink show.
            let naturalSize = backend.naturalSize(of: symbolWidget.into())
            backend.setSize(of: symbolWidget.into(), to: naturalSize)
            backend.setPosition(
                ofChildAt: 0,
                in: children.container.into(),
                to: (size &- naturalSize) / 2
            )
            return
        }

        if children.imageChanged
            || hasResized
            || (backend.requiresImageUpdateOnScaleFactorChange
                && children.lastScaleFactor != environment.windowScaleFactor)
        {
            if let image = children.cachedImage {
                backend.updateImageView(
                    children.imageWidget.into(),
                    rgbaData: image.bytes,
                    width: image.width,
                    height: image.height,
                    targetWidth: size.x,
                    targetHeight: size.y,
                    dataHasChanged: children.imageChanged,
                    environment: environment
                )
            }
            children.imageChanged = false
            children.lastScaleFactor = environment.windowScaleFactor
        }
        setDisplayedWidget(
            children.cachedImage == nil ? nil : children.imageWidget,
            children: children,
            backend: backend
        )
        backend.setSize(of: children.container.into(), to: size)
        backend.setSize(of: children.imageWidget.into(), to: size)
    }

    /// Swaps the widget hosted inside the image's container, inserting the
    /// given widget only when it differs from what's currently displayed.
    @MainActor
    private func setDisplayedWidget<Backend: BaseAppBackend>(
        _ widget: AnyWidget?,
        children: ImageChildren,
        backend: Backend
    ) {
        if children.insertedWidget === widget { return }
        backend.removeAllChildren(of: children.container.into())
        if let widget {
            backend.insert(widget.into(), into: children.container.into(), at: 0)
            backend.setPosition(ofChildAt: 0, in: children.container.into(), to: .zero)
        }
        children.insertedWidget = widget
    }
}

/// Image's persistent storage. Only exposed with the `package` access level
/// in order for backends to implement the `Image.inspect(_:_:)` modifier.
@_spi(Backends) public class ImageChildren: ViewGraphNodeChildren {
    var cachedImageSource: Image.Source? = nil
    var cachedImage: ImageFormats.Image<RGBA>? = nil
    var cachedImageDisplaySize: SIMD2<Int> = .zero
    var container: AnyWidget
    public var imageWidget: AnyWidget
    /// The icon-font widget used when the image source is
    /// ``Image/Source/symbolGlyph`` and the backend supports
    /// ``BackendFeatures/SymbolViews``.
    var symbolWidget: AnyWidget?
    /// The widget currently hosted inside ``container``.
    var insertedWidget: AnyWidget?
    var imageChanged = false
    var lastScaleFactor: Double = 1

    init<Backend: BaseAppBackend>(backend: Backend) {
        container = AnyWidget(backend.createContainer())
        imageWidget = AnyWidget(backend.createImageView())
    }

    public var widgets: [AnyWidget] = []
    public var erasedNodes: [ErasedViewGraphNode] = []
}

#if os(Windows)
    /// Maps SF Symbol names to Segoe Fluent Icons codepoints. The font itself
    /// chains to Segoe MDL2 Assets on Windows versions lacking a glyph.
    /// SF Symbols with no Fluent counterpart resolve to the closest single
    /// glyph. Unknown names are a hard failure — a missing mapping must be
    /// added rather than silently rendering an unrelated glyph.
    enum FluentSymbolGlyphs {
        static func glyph(for name: String) -> String {
            guard let codepoint = codepoints[name],
                let scalar = Unicode.Scalar(UInt32(codepoint))
            else {
                preconditionFailure(
                    "unmapped SF Symbol name for Segoe Fluent Icons: \(name)")
            }
            return String(scalar)
        }

        private static let codepoints: [String: UInt16] = [
            "app.badge": 0xECAA, // AppIconDefault
            "arrow.2.squarepath": 0xE895, // Sync
            "arrow.branch": 0xEF90, // Flow
            "arrow.clockwise": 0xE72C, // Refresh
            "arrow.clockwise.circle": 0xE895, // Sync
            "arrow.down.circle": 0xE896, // Download
            "arrow.down.to.line": 0xE896, // Download
            "arrow.left.arrow.right": 0xE880, // StatusDataTransfer
            "arrow.triangle.2.circlepath": 0xE895, // Sync
            "arrow.triangle.branch": 0xEF90, // Flow
            "arrow.trianglehead.pull": 0xEBD3, // CloudDownload
            "arrow.up.document": 0xE898, // Upload
            "arrow.up.forward.app": 0xE72D, // Share
            "arrow.up.to.line": 0xE898, // Upload
            "arrow.uturn.backward": 0xE7A7, // Undo
            "arrow.uturn.left": 0xE7A7, // Undo
            "brain.head.profile": 0xEA80, // Lightbulb
            "bubble.fill": 0xE8BD, // Message
            "bubble.left.and.bubble.right": 0xE8F2, // ChatBubbles
            "bubble.left.and.bubble.right.fill": 0xE8F2, // ChatBubbles
            "character.magnify": 0xE71E, // Zoom
            "checklist": 0xE9D5, // CheckList
            "checkmark": 0xE73E, // CheckMark
            "checkmark.circle": 0xF13E, // StatusCircleCheckmark
            "checkmark.circle.fill": 0xEC61, // CompletedSolid
            "checkmark.seal.fill": 0xEB95, // Certificate
            "checkmark.square.fill": 0xE73A, // CheckboxComposite
            "chevron.backward": 0xE76B, // ChevronLeft
            "chevron.down": 0xE70D, // ChevronDown
            "chevron.forward": 0xE76C, // ChevronRight
            "chevron.left": 0xE76B, // ChevronLeft
            "chevron.left.forwardslash.chevron.right": 0xE943, // Code
            "chevron.right": 0xE76C, // ChevronRight
            "chevron.up": 0xE70E, // ChevronUp
            "circle": 0xEA3A, // CircleRing
            "clock.arrow.trianglehead.2.counterclockwise.rotate.90": 0xE81C, // History
            "cloud": 0xE753, // Cloud
            "curlybraces": 0xE943, // Code
            "curlybraces.square": 0xE943, // Code
            "cylinder.split.1x2": 0xE965, // MediaStorageTower
            "doc": 0xE8A5, // Document
            "doc.badge.arrow.up": 0xEDE1, // Export
            "doc.badge.clock": 0xE81C, // History
            "doc.badge.plus": 0xECC8, // AddTo
            "doc.richtext": 0xE7C3, // Page
            "doc.richtext.fill": 0xE729, // PageSolid
            "doc.text": 0xE7C3, // Page
            "doc.text.magnifyingglass": 0xE721, // Search
            "doc.zipper": 0xE96A, // StorageTape
            "document.on.document": 0xE8C8, // Copy
            "dot.scope": 0xF272, // Bullseye
            "ellipsis": 0xE712, // More
            "exclamationmark.triangle.fill": 0xE7BA, // Warning
            "eye": 0xE7B3, // RedEye
            "eye.slash": 0xED1A, // Hide
            "eye.square": 0xE8FF, // Preview
            "film": 0xE8B2, // Movies
            "finder": 0xE721, // Search
            "folder": 0xE8B7, // Folder
            "folder.badge.plus": 0xE8F4, // NewFolder
            "folder.badge.questionmark": 0xF89A, // FolderSelect
            "folder.fill": 0xE8D5, // FolderFill
            "function": 0xE8EF, // Calculator
            "gear": 0xE713, // Settings
            "hammer.fill": 0xEC7A, // DeveloperTools
            "hand.raised": 0xF271, // PointerHand
            "hand.raised.slash": 0xF271, // PointerHand
            "hand.tap": 0xE7C9, // TouchPointer
            "icloud.and.arrow.down": 0xEBD3, // CloudDownload
            "icloud.and.arrow.up": 0xE898, // Upload
            "info.circle": 0xE946, // Info
            "list.bullet.clipboard": 0xF0E3, // ClipboardList
            "list.bullet.rectangle": 0xE8FD, // BulletedList
            "magnifyingglass": 0xE721, // Search
            "mic": 0xE720, // Microphone
            "mic.fill": 0xF8B1, // MicrophoneSolidBold
            "mic.slash": 0xEC54, // MicOff
            "minus": 0xE738, // Remove
            "minus.circle": 0xF140, // StatusCircleBlock
            "paintpalette.fill": 0xE790, // Color
            "paperclip": 0xE723, // Attach
            "paperplane": 0xE724, // Send
            "pause": 0xE769, // Pause
            "pause.fill": 0xE769, // Pause
            "pencil": 0xE70F, // Edit
            "pencil.line": 0xE70F, // Edit
            "person.2.wave.2.fill": 0xE716, // People
            "person.badge.clock": 0xE8CF, // ContactPresence
            "person.badge.key": 0xE72E, // Lock
            "person.badge.plus": 0xE8FA, // AddFriend
            "person.fill.questionmark": 0xE779, // ContactInfo
            "photo": 0xE91B, // Photo
            "photo.on.rectangle.angled": 0xE7AA, // PhotoCollection
            "play": 0xE768, // Play
            "play.fill": 0xE768, // Play
            "play.rectangle": 0xE786, // Slideshow
            "play.rectangle.on.rectangle": 0xE786, // Slideshow
            "plus": 0xE710, // Add
            "plus.message": 0xE8BD, // Message
            "pointer.arrow.ipad": 0xE7C9, // TouchPointer
            "questionmark": 0xE897, // Help
            "rectangle.on.rectangle": 0xE73F, // BackToWindow
            "rectangle.portrait.and.arrow.right": 0xE89B, // LeaveChat
            "return": 0xE751, // ReturnKey
            "safari": 0xE774, // Globe
            "seal": 0xEB95, // Certificate
            "server.rack": 0xE965, // MediaStorageTower
            "sidebar.left": 0xE90C, // DockLeft
            "sidebar.right": 0xE90D, // DockRight
            "sparkles.2": 0xE735, // FavoriteStarFill
            "square": 0xE739, // Checkbox
            "square.and.arrow.down": 0xE896, // Download
            "stop.circle": 0xF2D9, // CirclePause
            "swift": 0xE943, // Code
            "tag": 0xE8EC, // Tag
            "terminal": 0xE756, // CommandPrompt
            "terminal.fill": 0xE756, // CommandPrompt
            "text.bubble.badge.clock.fill": 0xE8BD, // Message
            "textformat": 0xE8D2, // Font
            "timer": 0xE916, // Stopwatch
            "trash": 0xE74D, // Delete
            "waveform": 0xE8D6, // Audio
            "xmark": 0xE711, // Cancel
            "xmark.circle.fill": 0xEB90, // StatusErrorFull
        ]
    }
#endif
