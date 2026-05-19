import XCTest
@testable import InstaDirectOnly

/// `InstagramWebView.isAllowedURL` の URL allowlist 挙動を網羅する。
/// 本テストは Xcode のテストターゲットを別途追加した上で実行することを想定。
final class InstagramWebViewURLPolicyTests: XCTestCase {

    // MARK: - 許可されるべき URL

    func test_allowsDirectInbox() {
        XCTAssertTrue(isAllowed("https://www.instagram.com/direct/inbox/"))
    }

    func test_allowsDirectSubpath() {
        XCTAssertTrue(isAllowed("https://www.instagram.com/direct/t/1234567890"))
    }

    func test_allowsAccountsLogin() {
        XCTAssertTrue(isAllowed("https://www.instagram.com/accounts/login/"))
    }

    func test_allowsChallenge() {
        XCTAssertTrue(isAllowed("https://www.instagram.com/challenge/foo/bar"))
    }

    func test_allowsRootForRedirect() {
        XCTAssertTrue(isAllowed("https://www.instagram.com/"))
    }

    func test_allowsCDNHost() {
        XCTAssertTrue(isAllowed("https://scontent.cdninstagram.com/v/asset.jpg"))
    }

    func test_allowsFacebookSubdomain() {
        XCTAssertTrue(isAllowed("https://m.facebook.com/oauth/dialog"))
    }

    func test_allowsHttpScheme() {
        // 開発・テスト用に http も許可される。本番では HTTPS でアクセスされる想定だが、
        // フィルタとしては scheme allowlist の境界を確認しておく。
        XCTAssertTrue(isAllowed("http://www.instagram.com/direct/inbox/"))
    }

    // MARK: - スキームによる拒否（新規追加: スキーム allowlist）

    func test_rejectsJavascriptSchemeWithInstagramHost() {
        // `javascript://www.instagram.com/direct/` は URL.host が
        // "www.instagram.com" を返しうるため、スキームでブロックする必要がある。
        XCTAssertFalse(isAllowed("javascript://www.instagram.com/direct/inbox/"))
    }

    func test_rejectsDataScheme() {
        XCTAssertFalse(isAllowed("data:text/html,<script>alert(1)</script>"))
    }

    func test_rejectsFileScheme() {
        XCTAssertFalse(isAllowed("file:///etc/passwd"))
    }

    func test_rejectsFtpScheme() {
        XCTAssertFalse(isAllowed("ftp://www.instagram.com/direct/inbox/"))
    }

    func test_rejectsTelScheme() {
        XCTAssertFalse(isAllowed("tel:+1234567890"))
    }

    func test_rejectsMailtoScheme() {
        XCTAssertFalse(isAllowed("mailto:foo@example.com"))
    }

    // MARK: - ホスト/パスによる拒否（既存挙動の回帰テスト）

    func test_rejectsPhishingLookalikeHost() {
        // 部分一致での host チェックを撃退する代表例。
        XCTAssertFalse(isAllowed("https://evil-instagram.com.attacker.example/direct/"))
    }

    func test_rejectsAttackerControlledSubdomainSuffix() {
        // `instagram.com.evil.example` も拒否されるべき。
        XCTAssertFalse(isAllowed("https://instagram.com.evil.example/direct/"))
    }

    func test_rejectsFeedPath() {
        XCTAssertFalse(isAllowed("https://www.instagram.com/explore/"))
    }

    func test_rejectsDirectFakePath() {
        // `/directfake` は `/direct` の prefix 一致で誤許可されないこと。
        XCTAssertFalse(isAllowed("https://www.instagram.com/directfake/inbox"))
    }

    func test_rejectsUnknownHost() {
        XCTAssertFalse(isAllowed("https://example.com/direct/inbox"))
    }

    // MARK: - Helper

    private func isAllowed(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString) else {
            XCTFail("Failed to parse URL: \(urlString)")
            return false
        }
        return InstagramWebView.isAllowedURL(url)
    }
}
