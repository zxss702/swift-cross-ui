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

        // Diagnostics: `SY_WEBVIEW_DEBUG` logs navigation outcomes to stderr;
        // `SY_WEBVIEW_DEVTOOLS` opens the DevTools window once the core is
        // ready — both invaluable when a page loads blank inside WebView2.
        if ProcessInfo.processInfo.environment["SY_WEBVIEW_DEBUG"] != nil,
            internalState.webViewNavigationCompletedHandlers[key] == nil
        {
            internalState.webViewNavigationCompletedHandlers[key] =
                webView.navigationCompleted.addHandler { _, args in
                    logger.warning(
                        "WebView2 navigationCompleted: success=\(args?.isSuccess ?? false) status=\(String(describing: args?.webErrorStatus)) http=\(args?.httpStatusCode ?? 0)"
                    )
                }
        }
        if ProcessInfo.processInfo.environment["SY_WEBVIEW_DEVTOOLS"] != nil,
            internalState.webViewCoreInitializedHandlers[key] == nil
        {
            internalState.webViewCoreInitializedHandlers[key] =
                webView.coreWebView2Initialized.addHandler { sender, _ in
                    try? sender?.coreWebView2?.openDevToolsWindow()
                }
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
