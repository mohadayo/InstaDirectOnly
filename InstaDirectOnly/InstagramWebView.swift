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
        // target="_blank" / window.open で開かれるリンクを WKUIDelegate で受け取り、
        // 許可 URL なら同 WebView でロードする（デフォルト動作だと silent fail する）
        webView.uiDelegate = context.coordinator
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

    /// host が domain と完全一致するか、domain のサブドメインかを判定する。
    /// `host.contains(domain)` のような部分一致は使わない
    /// （`evil-instagram.com.attacker.example` 等の偽装を拒否するため）
    private static func isHost(_ host: String, equalToOrSubdomainOf domain: String) -> Bool {
        return host == domain || host.hasSuffix("." + domain)
    }

    /// path が target と完全一致するか、`target/` で始まるかを判定する。
    /// `hasPrefix` 単独だと `/directfake` を誤って許可してしまうため、
    /// セグメント境界を意識した一致を行う
    private static func pathMatches(_ path: String, target: String) -> Bool {
        return path == target || path.hasPrefix(target + "/")
    }

    /// 許可する URL スキーム。`http` / `https` のみを通し、`javascript:` `data:`
    /// `file:` `ftp:` などホスト位置に既知ドメインを埋め込んだ細工 URL を排除する。
    static let allowedSchemes: Set<String> = ["http", "https"]

    /// 指定URLがDM利用に必要かどうかを判定
    static func isAllowedURL(_ url: URL) -> Bool {
        // スキームの allowlist 検査を最初に行う。
        // 例: `javascript://www.instagram.com/direct/inbox/` のように、ホスト位置に
        // 既知ドメイン文字列を埋め込んだ URL は `url.host` が
        // "www.instagram.com" を返しうるため、scheme で先に弾く必要がある。
        guard let scheme = url.scheme?.lowercased(),
              allowedSchemes.contains(scheme) else {
            return false
        }
        guard let host = url.host?.lowercased() else { return false }

        // CDN・認証系ホストは「完全一致 or サブドメイン」のみ許可
        if allowedHosts.contains(where: { Self.isHost(host, equalToOrSubdomainOf: $0) }) {
            return true
        }

        // Instagramドメインの場合、パスで判定
        if Self.isHost(host, equalToOrSubdomainOf: "instagram.com") {
            let path = url.path.lowercased()
            // ルートパスは許可（リダイレクト中に通過する）
            if path == "/" || path.isEmpty {
                return true
            }
            return allowedPaths.contains(where: { Self.pathMatches(path, target: $0) })
        }

        return false
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
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

        // MARK: - WKUIDelegate

        /// target="_blank" / window.open による新規ウィンドウ要求のハンドラ。
        /// WKWebView は標準では新規ウィンドウを開けないため、デリゲート未実装だと
        /// リンクをタップしても「無反応」になる（silent fail）。
        /// ここでは URL allowlist を満たす場合のみ同じ WebView でロードし、
        /// 許可外 URL は何もしない（外部ブラウザに飛ばさない＝ DM 外への離脱導線を作らない）。
        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            if let url = navigationAction.request.url,
               InstagramWebView.isAllowedURL(url) {
                webView.load(navigationAction.request)
            }
            return nil
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

        /// フィードや不要なUIを隠すCSSを注入。
        /// `didFinish` は同一 document の SPA 的な遷移ごとに発火するため、
        /// 単純に `<style>` を append すると DOM に同じ要素が累積する。
        /// 固定 ID を付け、既に存在する場合は再注入をスキップする
        /// （フルリロード後は document が作り直されて ID も消えるため、
        /// 必要なタイミングでは正しく再注入される）。
        private func injectCSS(into webView: WKWebView) {
            let js = """
            (function() {
                var STYLE_ID = 'idoa-injected-style';
                if (document.getElementById(STYLE_ID)) {
                    return;
                }
                var style = document.createElement('style');
                style.id = STYLE_ID;
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
