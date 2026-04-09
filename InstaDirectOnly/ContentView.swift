import SwiftUI

struct ContentView: View {
    @State private var isLoading = true
    @State private var webView: WebViewRef?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            InstagramWebView(isLoading: $isLoading, webViewRef: $webView)
                .ignoresSafeArea()

            if isLoading {
                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.5)
            }
        }
        .preferredColorScheme(.dark)
    }
}
