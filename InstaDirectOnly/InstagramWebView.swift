import SwiftUI
import WebKit

/// WKWebViewへの参照を保持する型
class WebViewRef {
    weak var webView: WKWebView?
}

struct InstagramWebView: UIViewRepresentable {
    @Binding var isLoading: Bool
    @Binding var webViewRef: WebViewRef?
    @Binding var loadError: String?

    static let dmURL = URL(string: "https://www.instagram.com/direct/inbox/")!

    /// DM利用に必要なURLパターン
    private static let allowedPaths: [String] = [
        "/direct",
        "/accounts/login",
        "/accounts/onetap",
        "/accounts/emailsignup",
        "/challenge",
        "/api/v1",
        "/oauth",
    ]

    /// 許可するホスト（CDN・認証系）
    private static let allowedHosts: [String] = [
        "cdninstagram.com",
        "fbcdn.net",
        "facebook.com",
        "fbsbx.com",
    ]

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        // Cookieを永続化してログイン状態を維持
        config.websiteDataStore = .default()
        config.allowsInlineMediaPlayback = true

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.backgroundColor = .black

        // モバイルSafariのUser-Agentを設定
        webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"

        webView.load(URLRequest(url: Self.dmURL))

        DispatchQueue.main.async {
            let ref = WebViewRef()
            ref.webView = webView
            self.webViewRef = ref
        }

        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // MARK: - URL判定

    /// 指定URLがDM利用に必要かどうかを判定
    static func isAllowedURL(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }

        // CDN・認証系ホストは全て許可
        if allowedHosts.contains(where: { host.contains($0) }) {
            return true
        }

        // Instagramドメインの場合、パスで判定
        if host.contains("instagram.com") {
            let path = url.path.lowercased()
            // ルートパスは許可（リダイレクト中に通過する）
            if path == "/" || path.isEmpty {
                return true
            }
            return allowedPaths.contains(where: { path.hasPrefix($0) })
        }

        return false
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, WKNavigationDelegate {
        let parent: InstagramWebView
        private var hasCompletedInitialLoad = false

        init(_ parent: InstagramWebView) {
            self.parent = parent
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.allow)
                return
            }

            // about:blank等は許可
            if url.scheme == "about" {
                decisionHandler(.allow)
                return
            }

            if InstagramWebView.isAllowedURL(url) {
                decisionHandler(.allow)
            } else {
                // ブロック対象のURL → DM画面にリダイレクト
                decisionHandler(.cancel)
                if hasCompletedInitialLoad {
                    webView.load(URLRequest(url: InstagramWebView.dmURL))
                }
            }
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            parent.isLoading = true
            // 新規ロード開始時にエラーをクリア
            if parent.loadError != nil {
                parent.loadError = nil
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.isLoading = false
            hasCompletedInitialLoad = true
            injectCSS(into: webView)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            handleNavigationError(error)
        }

        func webView(
            _ webView: WKWebView,
            didFailProvisionalNavigation navigation: WKNavigation!,
            withError error: Error
        ) {
            handleNavigationError(error)
        }

        /// 共通のロード失敗処理。
        /// 許可外URLのブロックやユーザ操作によるキャンセル (NSURLErrorCancelled) は
        /// 「エラー」ではないので無視する。
        private func handleNavigationError(_ error: Error) {
            parent.isLoading = false
            let nsError = error as NSError
            if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
                return
            }
            parent.loadError = error.localizedDescription
        }

        /// フィードや不要なUIを隠すCSSを注入
        private func injectCSS(into webView: WKWebView) {
            let js = """
            (function() {
                var style = document.createElement('style');
                style.textContent = `
                    /* 下部ナビゲーションバーを非表示 */
                    div[role="tablist"],
                    nav:has(a[href="/"]):not(:has(a[href*="direct"])) {
                        display: none !important;
                    }
                    /* アプリ誘導バナーを非表示 */
                    div[class*="banner"],
                    div[class*="Banner"],
                    a[href*="app-store"],
                    div:has(> a[href*="itunes.apple.com"]) {
                        display: none !important;
                    }
                `;
                document.head.appendChild(style);
            })();
            """
            webView.evaluateJavaScript(js)
        }
    }
}
