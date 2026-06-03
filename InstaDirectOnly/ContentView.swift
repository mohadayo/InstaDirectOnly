import SwiftUI

struct ContentView: View {
    @State private var isLoading = true
    @State private var webView: WebViewRef?
    @State private var loadError: String?
    /// WKWebView.estimatedProgress を 0.0〜1.0 で受け取る。
    /// 上部の薄いプログレスバー描画に使用。
    @State private var loadProgress: Double = 0.0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            InstagramWebView(
                isLoading: $isLoading,
                webViewRef: $webView,
                loadError: $loadError,
                loadProgress: $loadProgress
            )
            .ignoresSafeArea()

            // 画面最上部に薄いラインで読み込み進捗を表示する。
            // isLoading（ナビゲーションが始まってから完了するまで）かつ、
            // 完了直前 (>= 1.0) では表示しないことで、完了タイミングで瞬間的に消える。
            VStack(spacing: 0) {
                if isLoading && loadProgress < 1.0 {
                    ProgressView(value: loadProgress)
                        .progressViewStyle(.linear)
                        .tint(.white)
                        .frame(height: 2)
                        .accessibilityHidden(true)
                }
                Spacer()
            }
            .ignoresSafeArea(.container, edges: .horizontal)

            if isLoading {
                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.5)
                    .accessibilityLabel("読み込み中")
            }

            if let message = loadError {
                ErrorOverlay(message: message, onRetry: reload)
            }
        }
        .preferredColorScheme(.dark)
    }

    /// 再試行処理。
    /// 既に何らかの URL がロード済みなら `webView.reload()` で現在のページを再試行する
    /// （個別 DM スレッド閲覧中のネットワーク失敗から、同じスレッドに戻れるようにするため）。
    /// 初回ロードが URL コミット前に失敗した場合（`webView.url == nil`）に限り、
    /// フォールバックとして DM 受信箱 (`dmURL`) をロードする。
    private func reload() {
        loadError = nil
        guard let wv = webView?.webView else { return }
        if wv.url != nil {
            wv.reload()
        } else {
            wv.load(URLRequest(url: InstagramWebView.dmURL))
        }
    }
}

private struct ErrorOverlay: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 48))
                .foregroundStyle(.white)
                .accessibilityHidden(true)
            Text("読み込みに失敗しました")
                .font(.headline)
                .foregroundStyle(.white)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Button(action: onRetry) {
                Text("再試行")
                    .fontWeight(.semibold)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 10)
                    .background(Color.white)
                    .foregroundStyle(Color.black)
                    .clipShape(Capsule())
            }
            .accessibilityLabel("再試行")
            .accessibilityHint("読み込みに失敗したページを再度読み込みます")
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.85))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("読み込みに失敗しました")
    }
}
