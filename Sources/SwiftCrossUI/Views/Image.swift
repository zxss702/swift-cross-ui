import Foundation
import ImageFormats

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
    /// Symbol assets are looked up as `sfsymbols/<name>.imageset/<name>.png`
    /// (optionally under an `Assets.xcassets` prefix) in the resource bundles
    /// of every SwiftPM target linked into the running process. Symbols are
    /// expected to be pre-rendered PNGs, e.g. exported from SF Symbols.
    public init(systemName: String) {
        if let url = Self.symbolURL(named: systemName) {
            self.init(url, symbol: true)
        } else {
            self.init(URL(fileURLWithPath: ""))
        }
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
            defer { lock.unlock() }
            if let cached = pixels[key] { return cached }
            let decoded = decode()
            pixels[key] = decoded
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
        if useFileExtension {
            image = try? .load(from: bytes, usingFileExtension: url.pathExtension)
        } else {
            image = try? .load(from: bytes)
        }
        guard let image else {
            return nil
        }
        return (image.bytes, image.width, image.height)
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
        ImageChildren(backend: backend)
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
        if let image {
            var idealSize = ViewSize(Double(image.width), Double(image.height))
            if case .symbol(let symURL) = source {
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
                if children.isContainerEmpty {
                    backend.insert(
                        children.imageWidget.into(),
                        into: children.container.into(),
                        at: 0
                    )
                    backend.setPosition(ofChildAt: 0, in: children.container.into(), to: .zero)
                }
                children.isContainerEmpty = false
            } else {
                if !children.isContainerEmpty {
                    backend.removeAllChildren(of: children.container.into())
                }
                children.isContainerEmpty = true
            }
            children.imageChanged = false
            children.lastScaleFactor = environment.windowScaleFactor
        }
        backend.setSize(of: children.container.into(), to: size)
        backend.setSize(of: children.imageWidget.into(), to: size)
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
    var imageChanged = false
    var isContainerEmpty = true
    var lastScaleFactor: Double = 1

    init<Backend: BaseAppBackend>(backend: Backend) {
        container = AnyWidget(backend.createContainer())
        imageWidget = AnyWidget(backend.createImageView())
    }

    public var widgets: [AnyWidget] = []
    public var erasedNodes: [ErasedViewGraphNode] = []
}
