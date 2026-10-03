import Foundation
import UWP
import WinAppSDK
import WinSDK
import WinUI

#if canImport(SwiftCrossUI)
    import SwiftCrossUI
#else
    @_exported import SwiftCrossUI
#endif

/// Native SVG rendering through WinUI's `SvgImageSource`, which rasterises
/// vector art on the compositor at the requested pixel size.
extension WinUIBackend: BackendFeatures.SvgImages {

    public func createSvgImageView() -> Widget {
        let image = WinUI.Image()
        image.stretch = .uniform
        image.horizontalAlignment = .center
        image.verticalAlignment = .center
        return image
    }

    public func updateSvgImageView(
        _ imageView: Widget,
        url: URL,
        rasterWidth: Int,
        rasterHeight: Int,
        environment: EnvironmentValues
    ) {
        guard let image = imageView as? WinUI.Image else { return }
        let imageViewId = ObjectIdentifier(imageView)

        // Keep the loaded source when only the raster size changed — bumping
        // rasterizePixelWidth/Height re-rasterises the already-parsed vector
        // data without re-reading the file.
        if let entry = internalState.svgImageSources[imageViewId],
            entry.object === imageView, entry.url == url,
            let source = entry.source
        {
            source.rasterizePixelWidth = Double(max(0, rasterWidth))
            source.rasterizePixelHeight = Double(max(0, rasterHeight))
            return
        }

        let source = WinUI.SvgImageSource()
        source.rasterizePixelWidth = Double(max(0, rasterWidth))
        source.rasterizePixelHeight = Double(max(0, rasterHeight))
        image.source = source
        internalState.svgImageSources[imageViewId] = WeakSvgSource(
            object: imageView, url: url, source: source)

        // SvgImageSource accepts an IRandomAccessStream (absolute file://
        // URIs aren't allowed), so feed it through an in-memory stream.
        // The raster size is fixed upfront; reloading on source failure
        // would only loop, so failures leave the image empty.
        Task { @MainActor [weak image, weak source] in
            guard
                let data = try? Data(contentsOf: url),
                let image, let source
            else { return }
            do {
                let buffer = UWP.Buffer(UInt32(data.count))
                data.copyBytes(to: try buffer.buffer!, count: data.count)
                buffer.length = UInt32(data.count)

                let stream = UWP.InMemoryRandomAccessStream()
                _ = try await stream.writeAsync(buffer).get()
                try stream.seek(0)
                _ = try await source.setSourceAsync(stream).get()
            } catch {}
        }
    }
}

/// The loaded SVG source for an image widget. Weakly references the widget
/// so a new widget allocated at the same address can't reuse a stale entry.
final class WeakSvgSource {
    weak var object: AnyObject?
    let url: URL
    weak var source: WinUI.SvgImageSource?

    init(object: AnyObject, url: URL, source: WinUI.SvgImageSource) {
        self.object = object
        self.url = url
        self.source = source
    }
}
