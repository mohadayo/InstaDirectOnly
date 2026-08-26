import XCTest
import UIKit
@testable import InstaDirectOnly

/// `InstagramWebView.configureScrollView(_:)` が DM チャット向け UX に沿った
/// `UIScrollView` 設定を適用することを検証するテスト。
///
/// `WKWebView` 全体を組み立てなくても、素の `UIScrollView` を渡すだけで
/// 設定内容を確認できる形に切り出しているため、ヘッドレス環境でも実行できる。
final class InstagramWebViewScrollViewConfigTests: XCTestCase {

    func testConfigureScrollViewSetsInteractiveKeyboardDismissMode() {
        let scrollView = UIScrollView()
        // 事前条件: `UIScrollView` の既定値は `.none`
        XCTAssertEqual(
            scrollView.keyboardDismissMode,
            .none,
            "UIScrollView.keyboardDismissMode の既定値は .none のはず"
        )

        InstagramWebView.configureScrollView(scrollView)

        // iOS Messages / LINE / WhatsApp と同じ .interactive に揃える。
        // 下方向スワイプでキーボードが段階的に閉じるチャット標準 UX。
        XCTAssertEqual(scrollView.keyboardDismissMode, .interactive)
    }

    func testConfigureScrollViewHidesHorizontalScrollIndicator() {
        let scrollView = UIScrollView()
        // 事前条件: 既定で横スクロールインジケータは表示
        XCTAssertTrue(
            scrollView.showsHorizontalScrollIndicator,
            "UIScrollView.showsHorizontalScrollIndicator の既定値は true のはず"
        )

        InstagramWebView.configureScrollView(scrollView)

        // DM は縦スクロールで完結し、瞬間的な横スクロールバー出現はチャット UI としてノイズ。
        XCTAssertFalse(scrollView.showsHorizontalScrollIndicator)
    }

    func testConfigureScrollViewDoesNotAffectVerticalScrollIndicator() {
        // 縦方向のインジケータはメッセージ位置把握のために残す（意図しない副作用が無いことの確認）。
        let scrollView = UIScrollView()
        XCTAssertTrue(scrollView.showsVerticalScrollIndicator)

        InstagramWebView.configureScrollView(scrollView)

        XCTAssertTrue(
            scrollView.showsVerticalScrollIndicator,
            "縦方向のスクロールインジケータは変更しない"
        )
    }
}
