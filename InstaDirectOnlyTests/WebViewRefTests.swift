import XCTest
import WebKit
@testable import InstaDirectOnly

/// `WebViewRef` の単体テスト。
///
/// `WebViewRef` は `WKWebView` と `Coordinator` を `weak` で保持するだけの
/// 軽量な参照キャリアだが、以下の 2 点が挙動として重要なので回帰テストで固定する:
///
/// 1. 初期化直後は両プロパティが `nil`（呼び出し側が「まだ用意されていない」状態を
///    安全に扱える）
/// 2. `webView` プロパティが `weak` 参照であること（`WKWebView` の解放後に自動で
///    `nil` に戻る）。強参照になってしまうと `UIViewRepresentable` の解体後も
///    `WKWebView` が生存し続け、リソースリーク（Web Content Process の常駐、
///    メモリ・CPU の解放遅延）につながる。
final class WebViewRefTests: XCTestCase {

    func test_defaultInit_hasNilWebView() {
        let ref = WebViewRef()
        XCTAssertNil(ref.webView, "初期化直後の webView は nil であるべき")
    }

    func test_defaultInit_hasNilCoordinator() {
        let ref = WebViewRef()
        XCTAssertNil(ref.coordinator, "初期化直後の coordinator は nil であるべき")
    }

    func test_canAssignAndReadWebView() {
        let ref = WebViewRef()
        // `autoreleasepool` の外で保持することで、代入→即読み出しの生存性を担保する。
        let webView = WKWebView()
        ref.webView = webView
        XCTAssertNotNil(ref.webView)
        XCTAssertTrue(ref.webView === webView, "同一インスタンスが読み出せるはず")
    }

    /// `webView` が `weak` 参照であることを確認する。
    /// `autoreleasepool` で `WKWebView` の強参照を局所化し、pool を抜けた
    /// タイミングで解放されたときに `ref.webView` が自動で `nil` に戻ることを検証する。
    func test_webView_isWeakReference() {
        let ref = WebViewRef()

        autoreleasepool {
            let webView = WKWebView()
            ref.webView = webView
            XCTAssertNotNil(ref.webView, "代入直後は生存しているはず")
        }

        XCTAssertNil(
            ref.webView,
            "autoreleasepool を抜けた後は weak 参照により nil に戻るはず"
        )
    }
}
