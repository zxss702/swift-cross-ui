import Foundation
#if canImport(FoundationNetworking)
    import FoundationNetworking
#endif
import ImageFormats

/// The current phase of an ``AsyncImage``'s loading lifecycle.
public enum AsyncImagePhase: Sendable {
    /// No image has been loaded yet.
    case empty

    /// The image loaded successfully.
    case success(Image)

    /// The image failed to load.
    case failure(any Error)

    /// The loaded image, if the phase is ``success``.
    public var image: Image? {
        if case .success(let image) = self {
            return image
        }
        return nil
    }

    /// The error that occurred, if the phase is ``failure``.
    public var error: (any Error)? {
        if case .failure(let error) = self {
            return error
        }
        return nil
    }
}

/// A view that asynchronously loads and displays an image from a URL.
///
/// The image is fetched with `URLSession` and decoded by the `ImageFormats`
/// package. `png`, `jpg`, and `webp` are supported.
public struct AsyncImage<Content: View>: View {
    /// The image's current loading phase.
    @State private var phase = AsyncImagePhase.empty

    /// The URL of the image to load.
    private let url: URL?

    /// The scale to apply to the loaded image.
    private let scale: Double

    /// A builder producing the view for each loading phase.
    private let content: (AsyncImagePhase) -> Content

    /// Creates an image view that loads an image from a URL, customizing the
    /// displayed view for each loading phase.
    public init(
        url: URL?,
        scale: Double = 1,
        @ViewBuilder content: @escaping (AsyncImagePhase) -> Content
    ) {
        self.url = url
        self.scale = scale
        self.content = content
    }

    /// Creates an image view with a plain content closure (not routed
    /// through ``ViewBuilder``).
    init(
        url: URL?,
        scale: Double = 1,
        plainContent content: @escaping (AsyncImagePhase) -> Content
    ) {
        self.url = url
        self.scale = scale
        self.content = content
    }

    public var body: some View {
        content(phase)
            .task(id: url) {
                await loadImage()
            }
    }

    /// Fetches and decodes the image, updating ``phase``.
    private func loadImage() async {
        guard let url else {
            phase = .empty
            return
        }
        guard url.isFileURL else {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                guard let image = Self.decode(data) else {
                    phase = .failure(DecodingError.dataCorrupted(
                        .init(codingPath: [], debugDescription: "Unsupported image format")
                    ))
                    return
                }
                phase = .success(image)
            } catch {
                phase = .failure(error)
            }
            return
        }
        if let image = Self.decode(url) {
            phase = .success(image)
        } else {
            phase = .failure(DecodingError.dataCorrupted(
                .init(codingPath: [], debugDescription: "Could not decode image at \(url.path)")
            ))
        }
    }

    /// Decodes image data into an ``Image``.
    private static func decode(_ data: Data) -> Image? {
        guard let decoded = try? ImageFormats.Image<RGBA>.load(from: Array(data)) else {
            return nil
        }
        return Image(decoded)
    }

    /// Decodes the image file at the given URL into an ``Image``.
    private static func decode(_ url: URL) -> Image? {
        guard let data = try? Data(contentsOf: url) else {
            return nil
        }
        return decode(data)
    }
}

extension AsyncImage where Content == AnyView {
    /// Creates an image view that loads an image from a URL, displaying the
    /// image on success and an empty view while loading or on failure.
    public init(url: URL?, scale: Double = 1) {
        self.init(url: url, scale: scale, plainContent: { phase in
            switch phase {
                case .success(let image):
                    return AnyView(image.resizable().aspectRatio(contentMode: .fit))
                case .failure, .empty:
                    return AnyView(EmptyView())
            }
        })
    }
}
