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
    /// `WKWebView.estimatedProgress` を 0.0〜1.0 で反映する。
    /// SwiftUI 側で上部の薄いプログレスバーを描画するために使う。
    @Binding var loadProgress: Double

    static let dmURL = URL(string: "https://www.instagram.com/direct/inbox/")!

    /// DM利用に必要なURLパターン
    private static let allowedPaths: [String] = [
        "/direct",
        "/accounts/login",
        "/accounts/onetap",
        "/accounts/emailsignup",
        // ユーザーがアプリ内からログアウトできるようにする。
        // `pathMatches` の意味論により、完全一致 `/accounts/logout` と
        // サブパス `/accounts/logout/ajax/`（ログアウト POST 用）の両方が通過する。
        // 一方 `/accounts/logoutall` のような prefix lookalike は引き続き拒否される。
        "/accounts/logout",
        // ログイン画面から「パスワードを忘れた」を辿った際の再設定フロー。
        // `pathMatches` のセグメント境界一致により、`/accounts/password/reset`、
        // `/accounts/password/reset/`、`/accounts/password/reset/confirm/` 等を通過させる。
        // 一方 `/accounts/password/change/`（設定画面側）や `/accounts/password` 単体は
        // 親パスとして拒否されるため、DM 用途以外の導線は開かない。
        "/accounts/password/reset",
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

    /// DM 以外の UI（フィードナビゲーション・アプリ誘導バナー等）を視覚的に隠す CSS。
    /// `WKUserScript(.atDocumentStart)` と `didFinish` 後の `evaluateJavaScript` の
    /// 両方から参照されるため、ここで一元定義する。
    static let hideUnwantedUICSS: String = """
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
    """

    /// CSS を `<style id="idoa-injected-style">` として `document.head` に挿入する JS。
    /// 同一 ID の `<style>` が既に存在する場合は何もしない（SPA 遷移ごとの重複追加防止）。
    /// `WKUserScript(.atDocumentStart)` と `evaluateJavaScript` の両方から実行できる。
    static let injectStyleJS: String = """
    (function() {
        var STYLE_ID = 'idoa-injected-style';
        if (document.getElementById(STYLE_ID)) {
            return;
        }
        var style = document.createElement('style');
        style.id = STYLE_ID;
        style.textContent = `\(Self.hideUnwantedUICSS)`;
        (document.head || document.documentElement).appendChild(style);
    })();
    """

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        // Cookieを永続化してログイン状態を維持
        config.websiteDataStore = .default()
        config.allowsInlineMediaPlayback = true

        // DM 以外の UI を視覚的に隠す CSS をドキュメント生成直後に注入する。
        // `didFinish` 後の `evaluateJavaScript` だけだと初期レンダリング後にスタイルが
        // 適用され、フィードバーやバナーが一瞬見える（FOUC）。`.atDocumentStart` で
        // ユーザースクリプトとして登録することで、初回レイアウトより前に適用される。
        let userContentController = WKUserContentController()
        let userScript = WKUserScript(
            source: Self.injectStyleJS,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )
        userContentController.addUserScript(userScript)
        config.userContentController = userContentController

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

        // 読み込み進捗 (estimatedProgress) を KVO で観測し、@Binding 経由で UI に反映する。
        // 観測は Coordinator が保持する `progressObservation` トークンで管理され、
        // Coordinator の解放（= UIViewRepresentable の解体）と同時に invalidate される。
        context.coordinator.startObservingProgress(of: webView)

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

    /// path が `..` あるいは `.` をセグメントとして含む（パストラバーサル）かを判定する。
    /// Foundation の `URL.path` は `/direct/../explore/` のような入力をそのまま返すため、
    /// `pathMatches` の prefix 検査だけだと「先頭が `/direct/` で始まる」という理由で
    /// allowlist を素通りしてしまう。ブラウザ側でサーバ送信時にパスが解決されると、
    /// 結果として `/explore/` 等の本来ブロックすべきパスに到達し得るので、
    /// `.` / `..` セグメントを含むパスは早期に拒否する（deny-by-default）。
    private static func hasPathTraversal(_ path: String) -> Bool {
        for component in path.split(separator: "/", omittingEmptySubsequences: true) {
            if component == ".." || component == "." {
                return true
            }
        }
        return false
    }

    /// 許可する URL スキーム。`http` / `https` のみを通し、`javascript:` `data:`
    /// `file:` `ftp:` などホスト位置に既知ドメインを埋め込んだ細工 URL を排除する。
    static let allowedSchemes: Set<String> = ["http", "https"]

    /// Web Content Process がクラッシュした際にリロードすべき URL を決定する。
    /// クラッシュ前に表示していた URL が allowlist を満たす場合はその URL を返し
    /// （DM スレッド閲覧中のクラッシュからもスレッド位置を保持して復帰させる）、
    /// それ以外（URL 未確定／許可外 URL 表示中）は安全側に倒して `dmURL` を返す。
    /// `webViewWebContentProcessDidTerminate(_:)` から呼ばれるが、テスト容易性の
    /// ために delegate 経路と切り離した静的ヘルパーとして公開する。
    static func urlToReloadAfterContentProcessTermination(currentURL: URL?) -> URL {
        if let url = currentURL, Self.isAllowedURL(url) {
            return url
        }
        return Self.dmURL
    }

    /// Web Content Process クラッシュ自動復帰のレート制限ウィンドウ（秒）。
    /// この期間内のクラッシュ回数で自動リロードの停止可否を判定する。
    static let crashRecoveryWindow: TimeInterval = 30

    /// レート制限ウィンドウ内に許容する自動復帰回数。
    /// `crashRecoveryMaxAttempts` 回目までは自動リロードし、`crashRecoveryMaxAttempts + 1`
    /// 回目以降は自動復帰を停止してエラーオーバーレイを表示する。
    static let crashRecoveryMaxAttempts: Int = 3

    /// 自動復帰停止時にエラーオーバーレイへ表示するメッセージ。
    /// ユーザは `再試行` ボタン経由で再ロードを手動トリガーできる。
    static let crashRecoveryGiveUpMessage: String =
        "Web Content Process が短時間で繰り返し終了しました。再試行ボタンで再読み込みしてください。"

    /// `timestamps` をウィンドウ内のものに絞り込んで返す。
    /// テスト容易性のために切り出している（時刻判定をモックしやすい）。
    static func recentCrashTimestamps(
        _ timestamps: [Date],
        now: Date,
        window: TimeInterval = crashRecoveryWindow
    ) -> [Date] {
        return timestamps.filter { now.timeIntervalSince($0) < window }
    }

    /// 直近ウィンドウ内のクラッシュ回数がしきい値以上なら自動復帰を止めるべき。
    /// `timestamps` は最新試行を含めて呼び出すこと（呼び元で append してから渡す）。
    static func shouldStopAutoRecovery(
        timestamps: [Date],
        now: Date,
        window: TimeInterval = crashRecoveryWindow,
        maxAttempts: Int = crashRecoveryMaxAttempts
    ) -> Bool {
        let recent = recentCrashTimestamps(timestamps, now: now, window: window)
        return recent.count > maxAttempts
    }

    /// `WKWebView` が内部的に使う `WebKitErrorDomain` の文字列。Apple 公開ヘッダーには
    /// シンボルが無いため、`(error as NSError).domain` との比較用にここに集約しておく。
    static let webKitErrorDomain: String = "WebKitErrorDomain"

    /// `decisionHandler(.cancel)` や許可外スキーム到達などで `WKWebView` 自身が
    /// 発火する「無視して問題ないエラー」コード。`WebKitErrorDomain` 配下：
    /// - `101`: `WebKitErrorCannotShowURL` — 直後に `dmURL` への再ロードで上書きされるので無害
    /// - `102`: `WebKitErrorFrameLoadInterruptedByPolicyChange` — ポリシー判断による中断
    static let ignorableWebKitErrorCodes: Set<Int> = [101, 102]

    /// 「ユーザーへのエラー表示が不要なナビゲーションエラー」かを判定する。
    /// 役割は 2 つ：
    /// 1. `NSURLErrorDomain` / `NSURLErrorCancelled` — ユーザーによる戻る・許可外 URL ブロックなど
    /// 2. `WebKitErrorDomain` の中断系コード — `decidePolicyFor(.cancel)` 経路で発生しうる
    ///
    /// 上記いずれにも当てはまらない、通信失敗や TLS エラー等の「本物のエラー」は
    /// 引き続きエラーオーバーレイで報告する。
    static func isIgnorableNavigationError(_ error: Error) -> Bool {
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
            return true
        }
        if nsError.domain == webKitErrorDomain
            && ignorableWebKitErrorCodes.contains(nsError.code) {
            return true
        }
        return false
    }

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
            // `/direct/../explore/` のようなトラバーサル付きパスは
            // prefix 一致では allowlist を素通りしてしまうため、ここで明示的に拒否する。
            if Self.hasPathTraversal(path) {
                return false
            }
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
        /// `WKWebView.estimatedProgress` の KVO 観測トークン。
        /// `deinit` で必ず `invalidate()` する（Coordinator 寿命より長い WebView は無いが、
        /// SwiftUI 再生成時の二重観測を防ぐためにも明示的に解放する）。
        private var progressObservation: NSKeyValueObservation?
        /// Web Content Process クラッシュの直近タイムスタンプ。
        /// `webViewWebContentProcessDidTerminate(_:)` で append し、ウィンドウ外の値は
        /// 評価時に `recentCrashTimestamps` で除去する。
        private var crashRecoveryTimestamps: [Date] = []

        init(_ parent: InstagramWebView) {
            self.parent = parent
        }

        deinit {
            progressObservation?.invalidate()
        }

        /// `webView.estimatedProgress` を KVO で観測し、メインスレッドで `loadProgress` を更新する。
        /// `options: [.new, .initial]` で初期値も流すことで、UI のラグを最小化する。
        func startObservingProgress(of webView: WKWebView) {
            progressObservation?.invalidate()
            progressObservation = webView.observe(
                \.estimatedProgress,
                options: [.new, .initial]
            ) { [weak self] webView, _ in
                let value = webView.estimatedProgress
                if Thread.isMainThread {
                    self?.parent.loadProgress = value
                } else {
                    DispatchQueue.main.async {
                        self?.parent.loadProgress = value
                    }
                }
            }
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
                // ブロック対象のURL → ナビゲーション自体をキャンセル。
                // この時点で `WKWebView` は元のページのまま動かないので、
                // 既に許可済みページ（DM スレッド・ログイン・oauth 等）にいる場合は
                // その場に留まり、閲覧位置（例: /direct/t/<id>/）を保持する。
                // 何らかの事情で許可外ページに到達してしまっている場合のみ、
                // 保険として DM 受信箱へリダイレクトする。
                decisionHandler(.cancel)
                if hasCompletedInitialLoad {
                    if let currentURL = webView.url,
                       InstagramWebView.isAllowedURL(currentURL) {
                        return
                    }
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
        /// 許可外URLのブロックやユーザ操作によるキャンセル (NSURLErrorCancelled)、
        /// および `decidePolicyFor(.cancel)` 経路で WKWebView 自身が発火する
        /// `WebKitErrorDomain` の中断系コード (101 / 102) は「エラー」ではないので無視する。
        /// 判定本体は `InstagramWebView.isIgnorableNavigationError` に集約し、
        /// テストから直接呼べる形にしている。
        private func handleNavigationError(_ error: Error) {
            parent.isLoading = false
            if InstagramWebView.isIgnorableNavigationError(error) {
                return
            }
            parent.loadError = error.localizedDescription
        }

        /// SPA 的な soft navigation（History API による遷移）では document が
        /// 再生成されず `WKUserScript(.atDocumentStart)` が再発火しないため、
        /// `didFinish` のタイミングでも CSS の冪等な再注入を行う。
        /// `injectStyleJS` 自身が固定 ID で重複追加を防いでいるため、フル
        /// ロード後の二重注入も安全（既存 `<style>` が見つかれば早期 return）。
        private func injectCSS(into webView: WKWebView) {
            webView.evaluateJavaScript(InstagramWebView.injectStyleJS)
        }

        /// Web Content Process がクラッシュしたときに呼ばれる。
        /// 何もしないと `WKWebView` は空の白ビューのままユーザに残る（操作不能）。
        /// Apple 公式の推奨パターンとして、クラッシュ前の URL（許可済みのみ）を
        /// 再ロードして自動復帰させる。許可外 URL を表示していた場合や URL 未確定
        /// の場合は安全側に倒して DM 受信箱へ戻す。
        /// 再ロードの前にエラーオーバーレイの残骸をクリアし、`isLoading` 表示が
        /// 古い値で固着しないよう一旦リセットする。
        ///
        /// レート制限: 短時間に繰り返しクラッシュした場合（`crashRecoveryWindow` 内に
        /// `crashRecoveryMaxAttempts` 回を超過）は自動復帰を停止し、エラーオーバーレイ
        /// を表示する。これによりロード→クラッシュ→ロード の無限ループとバッテリー
        /// 浪費を防ぐ。ユーザは `再試行` ボタンで手動復帰でき、その時点で
        /// `crashRecoveryTimestamps` をクリアして次の連続クラッシュ検出に備える。
        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            let now = Date()
            crashRecoveryTimestamps.append(now)
            crashRecoveryTimestamps = InstagramWebView.recentCrashTimestamps(
                crashRecoveryTimestamps,
                now: now
            )

            parent.isLoading = false

            if InstagramWebView.shouldStopAutoRecovery(
                timestamps: crashRecoveryTimestamps,
                now: now
            ) {
                parent.loadError = InstagramWebView.crashRecoveryGiveUpMessage
                return
            }

            parent.loadError = nil
            let reloadURL = InstagramWebView.urlToReloadAfterContentProcessTermination(
                currentURL: webView.url
            )
            webView.load(URLRequest(url: reloadURL))
        }

        /// ユーザが `再試行` ボタンで手動復帰した際の後処理用。
        /// 連続クラッシュ計測をリセットし、次に短時間連続クラッシュが発生した場合に
        /// 改めて自動復帰のチャンスを与える。
        func resetCrashRecoveryState() {
            crashRecoveryTimestamps.removeAll()
        }
    }
}
