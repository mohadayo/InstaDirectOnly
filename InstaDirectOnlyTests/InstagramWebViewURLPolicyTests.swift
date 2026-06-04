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

    // MARK: - 正規化（大文字小文字 / ポート）

    func test_allowsUppercaseHost() {
        // `url.host` は実装側で `lowercased()` されるため、大文字混じりでも許可されること。
        XCTAssertTrue(isAllowed("https://WWW.INSTAGRAM.COM/direct/inbox/"))
    }

    func test_allowsUppercasePath() {
        // `url.path` も実装側で `lowercased()` されるため、大文字混じりでも許可されること。
        XCTAssertTrue(isAllowed("https://www.instagram.com/DIRECT/inbox/"))
    }

    func test_allowsExplicitHttpsPort() {
        // ポートを明示しても `url.host` はホスト名のみを返すため、判定に影響しないこと。
        XCTAssertTrue(isAllowed("https://www.instagram.com:443/direct/inbox/"))
    }

    func test_allowsInstagramApiSubdomain() {
        // `i.instagram.com` 等のサブドメインも instagram.com のサブドメイン扱いで、
        // 許可パス (`/api/v1`) と組み合わせれば通過すること。
        XCTAssertTrue(isAllowed("https://i.instagram.com/api/v1/users/web_profile_info/"))
    }

    // MARK: - userinfo を使った偽装

    func test_rejectsUserinfoMaskingEvilHost() {
        // `https://www.instagram.com@evil.example/direct/` は RFC 上、
        // host = `evil.example`（`www.instagram.com` は userinfo）。
        // 部分一致や user フィールドを誤って参照していないか回帰する。
        XCTAssertFalse(isAllowed("https://www.instagram.com@evil.example/direct/inbox/"))
    }

    func test_rejectsUserinfoWithPasswordMaskingEvilHost() {
        // user:password 形式の userinfo でも結果は同じであること。
        XCTAssertFalse(
            isAllowedOrUnparseable("https://www.instagram.com:pw@evil.example/direct/inbox/")
        )
    }

    // MARK: - 追加スキームの拒否

    func test_rejectsBlobScheme() {
        // WebKit の `blob:` URL（`blob:https://.../uuid`）は scheme="blob" で、
        // allowlist (http/https のみ) を満たさないため拒否されること。
        XCTAssertFalse(
            isAllowedOrUnparseable("blob:https://www.instagram.com/00000000-0000-0000-0000-000000000000")
        )
    }

    func test_rejectsWsScheme() {
        XCTAssertFalse(isAllowedOrUnparseable("ws://www.instagram.com/direct/inbox/"))
    }

    func test_rejectsWssScheme() {
        XCTAssertFalse(isAllowedOrUnparseable("wss://www.instagram.com/direct/inbox/"))
    }

    // MARK: - 追加で許可されるべきホスト（CDN・認証系の網羅）

    func test_allowsFbcdnSubdomain() {
        // `fbcdn.net` のサブドメインも CDN として許可されること。
        XCTAssertTrue(isAllowed("https://static.fbcdn.net/rsrc.php/v3/app.js"))
    }

    func test_allowsFbsbxSubdomain() {
        // `fbsbx.com`（lookaside 等）のサブドメインも許可されること。
        XCTAssertTrue(isAllowed("https://lookaside.fbsbx.com/ig/media/asset.jpg"))
    }

    func test_allowsExactFacebookHost() {
        // サブドメイン無しの完全一致ホストも許可されること。
        XCTAssertTrue(isAllowed("https://facebook.com/oauth/dialog"))
    }

    func test_allowsBareInstagramRoot() {
        // `www` の無い裸の `instagram.com` ルートも、リダイレクト通過のため許可されること。
        XCTAssertTrue(isAllowed("https://instagram.com/"))
    }

    // MARK: - 追加で許可されるべきパス（allowedPaths の網羅）

    func test_allowsOauthPath() {
        XCTAssertTrue(isAllowed("https://www.instagram.com/oauth/authorize"))
    }

    func test_allowsAccountsOnetapPath() {
        XCTAssertTrue(isAllowed("https://www.instagram.com/accounts/onetap/"))
    }

    func test_allowsAccountsEmailSignupPath() {
        XCTAssertTrue(isAllowed("https://www.instagram.com/accounts/emailsignup/"))
    }

    func test_allowsApiV1OnWww() {
        // `/api/v1` は i.instagram.com 以外（www）でも許可パスとして通過すること。
        XCTAssertTrue(isAllowed("https://www.instagram.com/api/v1/users/web_profile_info/"))
    }

    func test_allowsDirectWithoutTrailingSlash() {
        // 末尾スラッシュ無しの完全一致 `/direct` も許可されること（path == target）。
        XCTAssertTrue(isAllowed("https://www.instagram.com/direct"))
    }

    // MARK: - パスの細粒度な拒否（allowlist 外の /accounts/* は通さない）

    func test_rejectsAccountsSettingsPath() {
        // `/accounts/login` 等は許可されるが、許可リストに無い `/accounts/settings` は拒否されること。
        XCTAssertFalse(isAllowed("https://www.instagram.com/accounts/settings/"))
    }

    func test_rejectsAccountsPrefixOnly() {
        // `/accounts` 単体は、いずれの許可パス（/accounts/login など）とも一致しないため拒否されること。
        XCTAssertFalse(isAllowed("https://www.instagram.com/accounts"))
    }

    // MARK: - クエリ・フラグメントが許可判定に影響しないこと

    func test_allowsDirectWithQueryString() {
        // `url.path` はクエリを含まないため、`?next=...` が付いても許可されること。
        XCTAssertTrue(isAllowed("https://www.instagram.com/direct/inbox/?next=foo"))
    }

    func test_allowsDirectWithFragment() {
        // フラグメントも `url.path` に含まれないため、許可判定に影響しないこと。
        XCTAssertTrue(isAllowed("https://www.instagram.com/direct/inbox/#thread-1"))
    }

    // MARK: - IP リテラル / IDN / 空ホストなどの追加エッジケース

    func test_rejectsIPv4LiteralHost() {
        // `127.0.0.1` のような IPv4 リテラルは allowlist のどのホストにも一致しないこと。
        // (`hasSuffix(".instagram.com")` でも `host == "instagram.com"` でもない)
        XCTAssertFalse(isAllowed("http://127.0.0.1/direct/inbox/"))
    }

    func test_rejectsIPv4LiteralWithHttpsAndAllowedPath() {
        // HTTPS + 許可パスの組み合わせでも、IPv4 リテラルは拒否されること。
        XCTAssertFalse(isAllowed("https://192.0.2.1/direct/"))
    }

    func test_rejectsIPv6LiteralHost() {
        // `[::1]` のような IPv6 リテラルは `URL.host` が `::1` を返す（角括弧無し）。
        // 既知ドメイン名と一致しないことを確認する。
        XCTAssertFalse(isAllowedOrUnparseable("http://[::1]/direct/inbox/"))
    }

    func test_rejectsIPv6LiteralLoopbackHttps() {
        XCTAssertFalse(isAllowedOrUnparseable("https://[::1]/direct/"))
    }

    func test_rejectsPunycodeLookalikeHost() {
        // `xn--nstagram-3yc.com` は `іnstagram.com` (i がキリル文字) の Punycode 形式。
        // `URL.host` は Punycode 文字列をそのまま返すため、`instagram.com` の
        // サブドメインとは判定されないこと。
        XCTAssertFalse(isAllowed("https://www.xn--nstagram-3yc.com/direct/inbox/"))
    }

    func test_rejectsPunycodeOnlyDomainSuffix() {
        // Punycode 形式の TLD lookalike も拒否されること。
        XCTAssertFalse(isAllowed("https://instagram.xn--com-ip6f/direct/inbox/"))
    }

    func test_rejectsEmptyPathOnNonAllowedHost() {
        // 許可外ホスト + 空パスは拒否されること（パスベース許可は instagram.com のみ）。
        XCTAssertFalse(isAllowed("https://example.com/"))
    }

    func test_rejectsApiParentPath() {
        // `/api` 単体は `/api/v1` の親パスなので、`pathMatches` の境界として拒否されるべき。
        XCTAssertFalse(isAllowed("https://www.instagram.com/api"))
    }

    func test_rejectsApiV1ParentWithoutSubpath() {
        // `/api/v2` は `/api/v1` の prefix 一致でも path 一致でも無いため拒否されること。
        XCTAssertFalse(isAllowed("https://www.instagram.com/api/v2/users/"))
    }

    func test_rejectsChallengesPluralLookalike() {
        // `/challenges` は `/challenge` の prefix での誤許可が発生しないこと。
        // `pathMatches` は `target + "/"` か完全一致のみ許可するため、これは拒否される。
        XCTAssertFalse(isAllowed("https://www.instagram.com/challenges/recovery"))
    }

    func test_rejectsOauthLookalike() {
        // `/oauthx` のような prefix 取りこぼしも防がれること。
        XCTAssertFalse(isAllowed("https://www.instagram.com/oauthx/authorize"))
    }

    func test_allowsDirectWithTrailingSlashExact() {
        // 末尾スラッシュ付き `/direct/` は `target + "/"` 始まりとして許可されること。
        XCTAssertTrue(isAllowed("https://www.instagram.com/direct/"))
    }

    func test_allowsOauthBareWithoutSlash() {
        // `/oauth` 完全一致は許可されるべき（path == target）。回帰確認。
        XCTAssertTrue(isAllowed("https://www.instagram.com/oauth"))
    }

    func test_rejectsCdnSubstringLookalikeHost() {
        // `cdninstagram.com` の部分文字列を含むだけのホストは拒否されること。
        XCTAssertFalse(isAllowed("https://evil-cdninstagram.com/asset.jpg"))
    }

    func test_rejectsFbcdnSubstringLookalikeHost() {
        // `fbcdn.net` の suffix lookalike も拒否されること。
        XCTAssertFalse(isAllowed("https://evilfbcdn.net/asset.jpg"))
    }

    // MARK: - Helper

    private func isAllowed(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString) else {
            XCTFail("Failed to parse URL: \(urlString)")
            return false
        }
        return InstagramWebView.isAllowedURL(url)
    }

    /// URL のパースに失敗する可能性のある入力（blob:, 異常な userinfo 等）の検査用。
    /// パース不能なら「許可されない」と同義として `false` を返す（実機の WKWebView でも
    /// `URLRequest(url: nil)` は構築できないため、外部に出ない点で同じ結果になる）。
    private func isAllowedOrUnparseable(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString) else { return false }
        return InstagramWebView.isAllowedURL(url)
    }
}
