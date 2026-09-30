import Foundation
import UWP
import WinUI
import WindowsFoundation
import CWinRT
import WinSDK

@_spi(Backends) import SwiftCrossUI

extension WinUIBackend: BackendFeatures.WebViews {
    public func createWebView() -> Widget {
        // Note: `WinUI.WebView2` must not be subclassed here. The generated
        // subclassing machinery crashes for `WebView2` when the app runs in a
        // single-threaded COM apartment (which `WebView2` itself requires).
        WinUI.WebView2()
    }

    public func updateWebView(
        _ webView: Widget,
        environment: EnvironmentValues,
        onNavigate: @escaping (URL) -> Void
    ) {
        guard let webView = webView as? WinUI.WebView2 else { return }
        let key = ObjectIdentifier(webView)
        internalState.webViewNavigationStartingHandlers[key]?.dispose()
        internalState.webViewNavigationStartingHandlers[key] =
            webView.navigationStarting.addHandler { _, args in
                guard let uri = args?.uri, let url = URL(string: uri) else { return }
                onNavigate(url)
            }
    }

    public func navigateWebView(_ webView: Widget, to url: URL) {
        guard let webView = webView as? WinUI.WebView2 else { return }
        if let core = webView.coreWebView2 {
            try? core.navigate(url.absoluteString)
        } else {
            webView.source = WindowsFoundation.Uri(url.absoluteString)
        }
    }
}
