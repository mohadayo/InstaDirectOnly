import XCTest
@testable import InstaDirectOnly

/// `InstagramWebView` の静的定数（`dmURL` / `allowedSchemes` / `crashRecovery*` 関連）
/// の値そのものに対する回帰テスト。
///
/// 既存の `InstagramWebViewURLPolicyTests` は挙動経由でこれらの定数を間接的に
/// 検証しているが、定数の中身（スキーム・ホスト・パス・正値性・空文字列でないこと等）
/// が誤って書き換えられた場合に検知できる「値そのものへのアサート」が抜けていた。
/// 例えば `dmURL` を `https://www.instagram.com/explore/` に変更しても、
/// `xxx_fallsBackToDMURLWhenCurrentIsNil` は `dmURL == dmURL` の比較なので検出できない。
/// 本テストはそのような事故を別ファイルに切り出して明示的に回帰する。
final class InstagramWebViewConstantsTests: XCTestCase {

    // MARK: - dmURL

    func test_dmURL_usesHTTPSScheme() {
        // クラッシュ復帰時のフォールバック先 `dmURL` は HTTPS でなければならない。
        // ATS 経由でも http→https の昇格は行われないため、誤って http へ書き換えられた
        // 場合に検知する。
        XCTAssertEqual(InstagramWebView.dmURL.scheme, "https")
    }

    func test_dmURL_hostIsWWWInstagramCom() {
        // `dmURL` のホストが `www.instagram.com` であること（典型的タイポ
        // `wwww.instagram.com` や、`instagram.com` 単独などへの誤変更を検知）。
        XCTAssertEqual(InstagramWebView.dmURL.host, "www.instagram.com")
    }

    func test_dmURL_absoluteStringIsDirectInbox() {
        // `dmURL` の完全な文字列表現が DM 受信箱を指していること。
        // 末尾スラッシュ込みで完全一致を要求することで、`/direct/`（受信箱より親）
        // や `/direct/inbox`（末尾スラッシュ無し）への誤変更も検知する。
        XCTAssertEqual(
            InstagramWebView.dmURL.absoluteString,
            "https://www.instagram.com/direct/inbox/"
        )
    }

    func test_dmURL_isSelfConsistentWithIsAllowedURL() {
        // 自分自身のフォールバック先が allowlist を満たす自己整合性。
        // 例えば `dmURL` が誤って `/explore/` へ変更されると、クラッシュ復帰直後に
        // 再度ブロック→ループという最悪挙動になりかねない。
        XCTAssertTrue(InstagramWebView.isAllowedURL(InstagramWebView.dmURL))
    }

    // MARK: - allowedSchemes

    func test_allowedSchemes_isNotEmpty() {
        // allowlist が空だと全 URL が拒否される。`InstagramWebView.makeUIView` の
        // 初期ロード自体が走らなくなるため、最低限の存在検査として残す。
        XCTAssertFalse(InstagramWebView.allowedSchemes.isEmpty)
    }

    func test_allowedSchemes_containsHttpAndHttps() {
        // 通常運用に必要な http / https の双方を含むこと。
        // どちらかが脱落すると初期ロードや CDN アセットの取得が失敗する。
        XCTAssertTrue(InstagramWebView.allowedSchemes.contains("http"))
        XCTAssertTrue(InstagramWebView.allowedSchemes.contains("https"))
    }

    func test_allowedSchemes_doesNotContainDangerousSchemes() {
        // `javascript:` `data:` `file:` `blob:` `ftp:` `ws:` `wss:` 等の
        // 危険・想定外スキームが allowlist に混入していないこと（誤マージ検知）。
        // 個別の `test_rejects*Scheme` は `isAllowedURL` の挙動経由で間接的に
        // 検証しているが、allowlist 定数そのものへの直接アサートを残しておくと
        // 「allowedSchemes だけ修正したつもりが想定外要素を入れた」事故を早期検出できる。
        let dangerous: [String] = [
            "javascript", "data", "file", "blob", "ftp", "ws", "wss",
            "intent", "chrome", "tel", "mailto", "about", "instagram"
        ]
        for scheme in dangerous {
            XCTAssertFalse(
                InstagramWebView.allowedSchemes.contains(scheme),
                "allowedSchemes に危険スキーム \(scheme) が混入している"
            )
        }
    }

    // MARK: - crashRecovery thresholds

    func test_crashRecoveryWindow_isPositive() {
        // ウィンドウ幅が 0 や負値だと `recentCrashTimestamps` で全エントリが除外され、
        // `shouldStopAutoRecovery` が常に false を返し続けてしまう。
        // 結果として「永久に自動復帰する＝クラッシュループになっても止まらない」
        // 危険な状態を作るため、必ず正値であることを保証する。
        XCTAssertGreaterThan(InstagramWebView.crashRecoveryWindow, 0)
    }

    func test_crashRecoveryMaxAttempts_isPositive() {
        // しきい値が 0 以下だと、初回クラッシュ即座に自動復帰停止になり、
        // ユーザは常にエラーオーバーレイから手動再試行を要求される。
        // 1 回以上の自動復帰チャンスを残すため、必ず正値であることを保証する。
        XCTAssertGreaterThan(InstagramWebView.crashRecoveryMaxAttempts, 0)
    }

    // MARK: - crashRecoveryGiveUpMessage

    func test_crashRecoveryGiveUpMessage_isNotEmpty() {
        // 自動復帰停止時にオーバーレイへ表示するメッセージが空だと、
        // ユーザは「何が起きたのか」「どうすれば良いか」を判断できない。
        // 空文字列への誤変更を検知する。
        XCTAssertFalse(InstagramWebView.crashRecoveryGiveUpMessage.isEmpty)
    }

    func test_crashRecoveryGiveUpMessage_mentionsRetry() {
        // 停止メッセージは「再試行ボタンで再読み込みしてください」というアクションを
        // 含む必要がある。「再試行」キーワードの脱落により、ユーザが取るべき
        // 次の行動を見失う事故を防ぐ。
        XCTAssertTrue(
            InstagramWebView.crashRecoveryGiveUpMessage.contains("再試行"),
            "停止メッセージに『再試行』への案内が含まれていない"
        )
    }
}
