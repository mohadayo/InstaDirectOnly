import SwiftUI

struct ContentView: View {
    @State private var isLoading = true
    @State private var webView: WebViewRef?
    @State private var loadError: String?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            InstagramWebView(
                isLoading: $isLoading,
                webViewRef: $webView,
                loadError: $loadError
            )
            .ignoresSafeArea()

            if isLoading {
                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.5)
            }

            if let message = loadError {
                ErrorOverlay(message: message, onRetry: reload)
            }
        }
        .preferredColorScheme(.dark)
    }

    private func reload() {
        loadError = nil
        let request = URLRequest(url: InstagramWebView.dmURL)
        if let wv = webView?.webView {
            wv.load(request)
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
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.85))
    }
}
