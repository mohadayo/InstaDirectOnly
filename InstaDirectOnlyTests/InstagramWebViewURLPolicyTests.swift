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

    func test_allowsAccountsLogoutPath() {
        // ログアウト導線（完全一致）が通過すること。
        // allowlist に `/accounts/logout` を追加した目的そのものを回帰する。
        XCTAssertTrue(isAllowed("https://www.instagram.com/accounts/logout"))
    }

    func test_allowsAccountsLogoutTrailingSlash() {
        // 末尾スラッシュ付き `/accounts/logout/` も許可されること。
        XCTAssertTrue(isAllowed("https://www.instagram.com/accounts/logout/"))
    }

    func test_allowsAccountsLogoutAjaxSubpath() {
        // ログアウトの実行は `/accounts/logout/ajax/` への POST で行われる。
        // `pathMatches(target + "/")` により、サブパスも一括で許可されること。
        XCTAssertTrue(isAllowed("https://www.instagram.com/accounts/logout/ajax/"))
    }

    func test_rejectsAccountsLogoutallLookalike() {
        // `/accounts/logoutall` のような prefix lookalike は
        // セグメント境界を意識した `pathMatches` により拒否されること（回帰）。
        XCTAssertFalse(isAllowed("https://www.instagram.com/accounts/logoutall"))
    }

    // MARK: - パスワード再設定フロー（/accounts/password/reset）

    func test_allowsAccountsPasswordResetExact() {
        // 完全一致 `/accounts/password/reset` が通過すること。
        // ログイン画面の「パスワードを忘れた」リンク先を許可するための回帰。
        XCTAssertTrue(isAllowed("https://www.instagram.com/accounts/password/reset"))
    }

    func test_allowsAccountsPasswordResetTrailingSlash() {
        // 末尾スラッシュ付き `/accounts/password/reset/` も許可されること。
        XCTAssertTrue(isAllowed("https://www.instagram.com/accounts/password/reset/"))
    }

    func test_allowsAccountsPasswordResetConfirmSubpath() {
        // `/accounts/password/reset/confirm/...` のようなサブパス（メール内のリンク先）も、
        // `pathMatches(target + "/")` により一括で許可されること。
        XCTAssertTrue(
            isAllowed("https://www.instagram.com/accounts/password/reset/confirm/abc/")
        )
    }

    func test_rejectsAccountsPasswordChangePath() {
        // 設定画面側のパスワード変更 `/accounts/password/change/` は DM 用途のスコープ外。
        // `pathMatches` のセグメント境界一致により、`/accounts/password/reset` の prefix とも
        // 異なるため拒否されること。
        XCTAssertFalse(isAllowed("https://www.instagram.com/accounts/password/change/"))
    }

    func test_rejectsAccountsPasswordParentPath() {
        // 親パス `/accounts/password` 単体は、`/accounts/password/reset` とは
        // 完全一致でもセグメント境界 prefix でもないため拒否されること。
        XCTAssertFalse(isAllowed("https://www.instagram.com/accounts/password"))
    }

    func test_rejectsAccountsPasswordResetLookalike() {
        // `/accounts/password/resetx` のような prefix lookalike も拒否されること。
        // 既存の `pathMatches` 境界判定（`target` か `target/`）の回帰。
        XCTAssertFalse(isAllowed("https://www.instagram.com/accounts/password/resetx"))
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

    // MARK: - スキームの大文字小文字正規化

    func test_allowsUppercaseScheme() {
        // 実装は `url.scheme?.lowercased()` で正規化してから allowlist と照合するため、
        // `HTTPS://` のような全大文字スキームも http/https と等価に扱われ許可される。
        XCTAssertTrue(isAllowed("HTTPS://www.instagram.com/direct/inbox/"))
    }

    func test_allowsMixedCaseScheme() {
        // 大文字小文字混在のスキームも正規化後に許可されること（回帰）。
        XCTAssertTrue(isAllowed("HtTpS://www.instagram.com/direct/inbox/"))
    }

    // MARK: - allowlist で拒否されるべき特殊スキーム

    func test_rejectsAboutBlankFromAllowlist() {
        // `about:blank` は WKNavigationDelegate 側 (`decidePolicyFor`) で別途許可されるが、
        // 純粋な静的判定の `isAllowedURL` は scheme allowlist (http/https のみ) を満たさず false を返す。
        // 役割分担（allowlist と delegate のガード）の境界をテストとして残す。
        XCTAssertFalse(isAllowedOrUnparseable("about:blank"))
    }

    func test_rejectsInstagramCustomScheme() {
        // Instagram ネイティブアプリ用カスタム URL スキーム (`instagram://`) は
        // Web から開かれても allowlist 外。アプリ外への離脱導線を作らない設計上の意図を回帰する。
        XCTAssertFalse(isAllowedOrUnparseable("instagram://user?username=evil"))
    }

    func test_rejectsIntentScheme() {
        // Android スタイルの intent:// は iOS でも JS 経由で生成されうる。
        // scheme allowlist で弾かれ、ホスト位置に `www.instagram.com` を埋め込んでも通らない。
        XCTAssertFalse(
            isAllowedOrUnparseable(
                "intent://www.instagram.com/direct/#Intent;scheme=https;package=com.instagram.android;end"
            )
        )
    }

    func test_rejectsChromeScheme() {
        // ブラウザ専用スキーム (`chrome://`) も scheme allowlist で弾かれる。
        XCTAssertFalse(isAllowedOrUnparseable("chrome://flags/"))
    }

    // MARK: - ホスト末尾ドット

    func test_rejectsTrailingDotHost() {
        // DNS 上 `instagram.com.` (末尾ドット) は有効な FQDN だが、
        // `URL.host` は文字列として "instagram.com." を返し、`hasSuffix(".instagram.com")` も
        // `host == "instagram.com"` も満たさないため allowlist を満たさない。
        // 正規化を一切行わない実装の意図を回帰する。
        XCTAssertFalse(isAllowed("https://instagram.com./direct/inbox/"))
    }

    // MARK: - 極端に長い path

    func test_allowsVeryLongDirectThreadPath() {
        // `/direct/t/<thread_id>` は実用上 24 文字程度の base32 ID が入るが、
        // 万一上流の URL 仕様が変わって極端に長い ID が来ても prefix 一致で通過すること。
        let longID = String(repeating: "a", count: 1024)
        XCTAssertTrue(isAllowed("https://www.instagram.com/direct/t/\(longID)"))
    }

    // MARK: - メインタブ・プロフィールページの明示的な拒否

    func test_rejectsPostDetailPath() {
        // 投稿 (Post) 詳細 `/p/<shortcode>/` は DM 用途外。
        // 許可リストに含まれないため `pathMatches` のいずれの target にも一致せず拒否される。
        XCTAssertFalse(isAllowed("https://www.instagram.com/p/C1abcdEF234/"))
    }

    func test_rejectsBarePathP() {
        // `/p` 単体（末尾スラッシュ無し）も `/p/<shortcode>` の親パスとして拒否されること。
        XCTAssertFalse(isAllowed("https://www.instagram.com/p"))
    }

    func test_rejectsReelDetailPath() {
        // 単発リール詳細 `/reel/<shortcode>/` は DM 用途外。
        XCTAssertFalse(isAllowed("https://www.instagram.com/reel/C1abcdEF234/"))
    }

    func test_rejectsReelsTabPath() {
        // リールタブ `/reels/` も拒否されること。
        XCTAssertFalse(isAllowed("https://www.instagram.com/reels/"))
    }

    func test_rejectsStoriesViewPath() {
        // ストーリービュー `/stories/<user>/` も DM 用途外。
        XCTAssertFalse(isAllowed("https://www.instagram.com/stories/some_user/"))
    }

    func test_rejectsShopPath() {
        // ショッピングタブ `/shop/` も DM 用途外。
        XCTAssertFalse(isAllowed("https://www.instagram.com/shop/"))
    }

    func test_rejectsBareExplorePath() {
        // `/explore` 単体（末尾スラッシュ無し）も `/explore/` の親パスとして拒否されること。
        // 既存の `/explore/` 拒否テストの末尾スラッシュ違いを補完する。
        XCTAssertFalse(isAllowed("https://www.instagram.com/explore"))
    }

    func test_rejectsUserProfilePath() {
        // 任意のユーザー名 `/<username>/` プロフィールページは DM 用途外。
        // 許可リストには無いため `pathMatches` 境界判定で確実に拒否される。
        XCTAssertFalse(isAllowed("https://www.instagram.com/some_user/"))
    }

    func test_rejectsUserProfilePathWithoutTrailingSlash() {
        // 末尾スラッシュ無しの `/<username>` も同様に拒否されること。
        XCTAssertFalse(isAllowed("https://www.instagram.com/some_user"))
    }

    func test_rejectsUserProfileSubpathTagged() {
        // `/<username>/tagged/` のようなサブパスも拒否されること。
        XCTAssertFalse(isAllowed("https://www.instagram.com/some_user/tagged/"))
    }

    // MARK: - パストラバーサル（`..` / `.` セグメント）の拒否

    func test_rejectsDirectParentTraversalToExplore() {
        // `/direct/../explore/` は prefix だけ見ると `/direct/` で始まるが、
        // ブラウザ側で解決されるとフィードに準ずる `/explore/` へ到達してしまう。
        // `hasPathTraversal` ガードで明示的に拒否する。
        XCTAssertFalse(isAllowed("https://www.instagram.com/direct/../explore/"))
    }

    func test_rejectsDirectDoubleParentTraversalToFeed() {
        // `/direct/inbox/../../` のような多段 `..` も拒否されること。
        XCTAssertFalse(isAllowed("https://www.instagram.com/direct/inbox/../../"))
    }

    func test_rejectsAccountsLoginTraversalToPost() {
        // ログイン経由 → 投稿詳細への traversal も拒否されること。
        XCTAssertFalse(isAllowed("https://www.instagram.com/accounts/login/../../p/abcdef/"))
    }

    func test_rejectsTraversalToUnknownHostPath() {
        // 末尾が allowlist 外でも、`..` を含む時点で拒否されること
        // （allowlist の前段で deny される確認）。
        XCTAssertFalse(isAllowed("https://www.instagram.com/direct/../../foo/"))
    }

    func test_rejectsCurrentDirSegmentInDirectPath() {
        // `.` セグメント単体も拒否されること。
        // `/direct/./inbox/` は実質 `/direct/inbox/` だが、トラバーサル系の
        // 入力を一律にブロックする deny-by-default の方針を取る。
        XCTAssertFalse(isAllowed("https://www.instagram.com/direct/./inbox/"))
    }

    func test_rejectsTraversalAtPathTail() {
        // 末尾の `..` も拒否されること。
        XCTAssertFalse(isAllowed("https://www.instagram.com/direct/inbox/.."))
    }

    func test_allowsDoubleDotInsideSegmentName() {
        // パスセグメントの内部に `..` が含まれるだけ（独立した `..` セグメントではない）の
        // 場合はトラバーサルではないため、通常の allowlist 判定にゆだねる。
        // ここでは `direct..foo` という単独セグメントになるので、`/direct` への
        // prefix 一致を満たさず最終的に拒否される。
        XCTAssertFalse(isAllowed("https://www.instagram.com/direct..foo/"))
    }

    func test_rejectsTraversalOnAllowedCDNHostStaysAllowed() {
        // 許可ホスト（CDN）はパス判定をスキップする設計のため、`..` を含んでも
        // ホスト一致だけで許可される。本テストは「ホスト allowlist が path に
        // 関係なく許可する」という現行仕様を明示的に文書化するためのもの。
        XCTAssertTrue(isAllowed("https://scontent.cdninstagram.com/v/asset/../other.jpg"))
    }

    // MARK: - ナビゲーションエラーの無視判定

    func test_ignoresNSURLErrorCancelled() {
        // 許可外 URL ブロックや戻る操作で発生する標準的なキャンセルエラーは無視されること。
        let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorCancelled)
        XCTAssertTrue(InstagramWebView.isIgnorableNavigationError(error))
    }

    func test_ignoresWebKitErrorFrameLoadInterruptedByPolicyChange() {
        // `decisionHandler(.cancel)` 経路で WKWebView が発火しうる
        // `WebKitErrorDomain` / 102 (FrameLoadInterruptedByPolicyChange) は無視されること。
        let error = NSError(domain: InstagramWebView.webKitErrorDomain, code: 102)
        XCTAssertTrue(InstagramWebView.isIgnorableNavigationError(error))
    }

    func test_ignoresWebKitErrorCannotShowURL() {
        // 許可外スキーム到達直後の再ロード時に発生しうる
        // `WebKitErrorDomain` / 101 (CannotShowURL) も無視されること。
        let error = NSError(domain: InstagramWebView.webKitErrorDomain, code: 101)
        XCTAssertTrue(InstagramWebView.isIgnorableNavigationError(error))
    }

    func test_doesNotIgnoreNetworkConnectionError() {
        // 通信失敗系は引き続きエラーオーバーレイで報告されること。
        let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet)
        XCTAssertFalse(InstagramWebView.isIgnorableNavigationError(error))
    }

    func test_doesNotIgnoreSSLError() {
        // TLS / 証明書エラーは利用者にとって有意な失敗なので報告されること。
        let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorSecureConnectionFailed)
        XCTAssertFalse(InstagramWebView.isIgnorableNavigationError(error))
    }

    func test_doesNotIgnoreUnknownWebKitErrorCode() {
        // `WebKitErrorDomain` でも未知のコードは無視しない（保守的に報告）。
        // 既知の中断系 (101 / 102) 以外のコードは新たな失敗種別として扱う。
        let error = NSError(domain: InstagramWebView.webKitErrorDomain, code: 300)
        XCTAssertFalse(InstagramWebView.isIgnorableNavigationError(error))
    }

    func test_doesNotIgnoreCancelledOnWrongDomain() {
        // コード値が `NSURLErrorCancelled` と同じでも、ドメインが違えば無視しない
        // （別ドメイン側で同じ数値が別の意味を持つ可能性があるため、組合せで判定）。
        let error = NSError(domain: "com.example.OtherDomain", code: NSURLErrorCancelled)
        XCTAssertFalse(InstagramWebView.isIgnorableNavigationError(error))
    }

    func test_doesNotIgnore102OnWrongDomain() {
        // コード 102 でもドメインが `WebKitErrorDomain` 以外なら無視しない。
        let error = NSError(domain: NSURLErrorDomain, code: 102)
        XCTAssertFalse(InstagramWebView.isIgnorableNavigationError(error))
    }

    // MARK: - Web Content Process クラッシュからの復帰

    func test_reloadAfterTermination_preservesAllowedDirectThread() {
        // 個別 DM スレッド閲覧中にクラッシュした場合、同じスレッド位置に戻れること。
        let current = URL(string: "https://www.instagram.com/direct/t/1234567890/")!
        let result = InstagramWebView.urlToReloadAfterContentProcessTermination(
            currentURL: current
        )
        XCTAssertEqual(result, current)
    }

    func test_reloadAfterTermination_preservesAllowedCDNHost() {
        // CDN ホスト表示中（例えば添付メディア）も allowlist を満たすので保持。
        let current = URL(string: "https://scontent.cdninstagram.com/v/asset.jpg")!
        let result = InstagramWebView.urlToReloadAfterContentProcessTermination(
            currentURL: current
        )
        XCTAssertEqual(result, current)
    }

    func test_reloadAfterTermination_fallsBackToDMURLWhenCurrentIsDisallowed() {
        // 何らかの理由で許可外 URL が currentURL になっている場合（直前にブロック中の
        // 遷移途中でクラッシュした等）は、安全側に倒して dmURL に戻すこと。
        let current = URL(string: "https://www.instagram.com/explore/")!
        let result = InstagramWebView.urlToReloadAfterContentProcessTermination(
            currentURL: current
        )
        XCTAssertEqual(result, InstagramWebView.dmURL)
    }

    func test_reloadAfterTermination_fallsBackToDMURLWhenCurrentIsNil() {
        // 初回ロードが URL コミット前にクラッシュした場合は currentURL が nil。
        // この場合も dmURL から再開する。
        let result = InstagramWebView.urlToReloadAfterContentProcessTermination(
            currentURL: nil
        )
        XCTAssertEqual(result, InstagramWebView.dmURL)
    }

    func test_reloadAfterTermination_fallsBackToDMURLWhenCurrentIsPhishingLookalike() {
        // 偽装ホスト（部分一致を狙う lookalike）が currentURL に紛れていた場合も
        // allowlist で弾かれ、dmURL に戻ること。
        let current = URL(string: "https://evil-instagram.com.attacker.example/direct/")!
        let result = InstagramWebView.urlToReloadAfterContentProcessTermination(
            currentURL: current
        )
        XCTAssertEqual(result, InstagramWebView.dmURL)
    }

    // MARK: - Web Content Process クラッシュ復帰のレート制限

    func test_recentCrashTimestamps_filtersOutOldEntries() {
        // ウィンドウ外（古い）タイムスタンプは除外される。
        let now = Date()
        let old = now.addingTimeInterval(-(InstagramWebView.crashRecoveryWindow + 1))
        let recent = now.addingTimeInterval(-1)
        let result = InstagramWebView.recentCrashTimestamps([old, recent], now: now)
        XCTAssertEqual(result, [recent])
    }

    func test_recentCrashTimestamps_keepsExactBoundaryEntries() {
        // ウィンドウ内（境界よりも新しい）のエントリは保持される。
        let now = Date()
        let onEdge = now.addingTimeInterval(-(InstagramWebView.crashRecoveryWindow - 0.1))
        let result = InstagramWebView.recentCrashTimestamps([onEdge], now: now)
        XCTAssertEqual(result.count, 1)
    }

    func test_shouldStopAutoRecovery_returnsFalseBelowThreshold() {
        // しきい値以内（=== maxAttempts）はまだ自動復帰を続ける。
        let now = Date()
        let timestamps = (0..<InstagramWebView.crashRecoveryMaxAttempts).map { _ in now }
        XCTAssertFalse(
            InstagramWebView.shouldStopAutoRecovery(
                timestamps: timestamps,
                now: now
            )
        )
    }

    func test_shouldStopAutoRecovery_returnsTrueAboveThreshold() {
        // しきい値超過（maxAttempts + 1 回目以降）で自動復帰を停止すべきと判定。
        let now = Date()
        let timestamps = (0..<(InstagramWebView.crashRecoveryMaxAttempts + 1)).map { _ in now }
        XCTAssertTrue(
            InstagramWebView.shouldStopAutoRecovery(
                timestamps: timestamps,
                now: now
            )
        )
    }

    func test_shouldStopAutoRecovery_ignoresOldEntriesOutsideWindow() {
        // 古いエントリばかりが大量にあっても、ウィンドウ内に入っていなければ復帰継続。
        let now = Date()
        let outside = now.addingTimeInterval(-(InstagramWebView.crashRecoveryWindow + 1))
        let timestamps = Array(repeating: outside, count: 100) + [now]
        XCTAssertFalse(
            InstagramWebView.shouldStopAutoRecovery(
                timestamps: timestamps,
                now: now
            )
        )
    }

    func test_shouldStopAutoRecovery_emptyTimestampsAlwaysFalse() {
        // タイムスタンプ無し（初回クラッシュ前）は当然継続。
        let now = Date()
        XCTAssertFalse(
            InstagramWebView.shouldStopAutoRecovery(
                timestamps: [],
                now: now
            )
        )
    }

    // MARK: - Coordinator.resetCrashRecoveryState

    /// `Coordinator` のインスタンスを生成するための最小限のテストヘルパ。
    /// `@Binding` は SwiftUI の View 階層外でも `.constant(...)` で生成できる。
    private func makeCoordinatorForReset() -> InstagramWebView.Coordinator {
        let view = InstagramWebView(
            isLoading: .constant(false),
            webViewRef: .constant(nil),
            loadError: .constant(nil),
            loadProgress: .constant(0.0)
        )
        return view.makeCoordinator()
    }

    func test_resetCrashRecoveryState_clearsAppendedTimestamps() {
        // crashRecoveryTimestamps に値が積まれている状態でリセットすると、空配列に戻る。
        // これは「再試行」ボタンから連続クラッシュ計測をクリアして、自動復帰の
        // ウィンドウを再度ユーザに与えるための公開 API。
        let coordinator = makeCoordinatorForReset()
        coordinator.crashRecoveryTimestamps = [Date(), Date(), Date()]
        XCTAssertEqual(coordinator.crashRecoveryTimestamps.count, 3)
        coordinator.resetCrashRecoveryState()
        XCTAssertTrue(coordinator.crashRecoveryTimestamps.isEmpty)
    }

    func test_resetCrashRecoveryState_isIdempotentOnEmpty() {
        // 元から空のリストに対してリセットを呼んでもクラッシュせず、引き続き空のまま。
        let coordinator = makeCoordinatorForReset()
        XCTAssertTrue(coordinator.crashRecoveryTimestamps.isEmpty)
        coordinator.resetCrashRecoveryState()
        coordinator.resetCrashRecoveryState()
        XCTAssertTrue(coordinator.crashRecoveryTimestamps.isEmpty)
    }

    func test_resetCrashRecoveryState_allowsImmediateRecoveryAfterReset() {
        // リセット直後は「停止すべき」と判定されない（= 自動復帰が再び有効）。
        // ウィンドウ閾値ぎりぎりまで埋めて、その後リセットして判定が False に変わることを確認する。
        let coordinator = makeCoordinatorForReset()
        let now = Date()
        coordinator.crashRecoveryTimestamps = (0..<(InstagramWebView.crashRecoveryMaxAttempts + 1))
            .map { _ in now }
        XCTAssertTrue(
            InstagramWebView.shouldStopAutoRecovery(
                timestamps: coordinator.crashRecoveryTimestamps,
                now: now
            )
        )
        coordinator.resetCrashRecoveryState()
        XCTAssertFalse(
            InstagramWebView.shouldStopAutoRecovery(
                timestamps: coordinator.crashRecoveryTimestamps,
                now: now
            )
        )
    }

    // MARK: - userFriendlyErrorMessage

    func test_userFriendlyErrorMessage_offline() {
        // NSURLErrorNotConnectedToInternet は固定の日本語メッセージへマップされる。
        let error = NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorNotConnectedToInternet,
            userInfo: nil
        )
        XCTAssertEqual(
            InstagramWebView.userFriendlyErrorMessage(for: error),
            "インターネット接続がありません。Wi-Fi またはモバイル通信を確認して再試行してください。"
        )
    }

    func test_userFriendlyErrorMessage_timeout() {
        let error = NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorTimedOut,
            userInfo: nil
        )
        XCTAssertEqual(
            InstagramWebView.userFriendlyErrorMessage(for: error),
            "通信がタイムアウトしました。電波状況を確認して再試行してください。"
        )
    }

    func test_userFriendlyErrorMessage_networkConnectionLost() {
        let error = NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorNetworkConnectionLost,
            userInfo: nil
        )
        XCTAssertEqual(
            InstagramWebView.userFriendlyErrorMessage(for: error),
            "通信が切断されました。再試行してください。"
        )
    }

    func test_userFriendlyErrorMessage_cannotFindHost_mapsToServerUnreachable() {
        let error = NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorCannotFindHost,
            userInfo: nil
        )
        XCTAssertEqual(
            InstagramWebView.userFriendlyErrorMessage(for: error),
            "サーバに接続できませんでした。電波状況を確認して再試行してください。"
        )
    }

    func test_userFriendlyErrorMessage_dnsLookupFailed_mapsToServerUnreachable() {
        let error = NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorDNSLookupFailed,
            userInfo: nil
        )
        XCTAssertEqual(
            InstagramWebView.userFriendlyErrorMessage(for: error),
            "サーバに接続できませんでした。電波状況を確認して再試行してください。"
        )
    }

    func test_userFriendlyErrorMessage_secureConnectionFailed_mapsToTLSMessage() {
        let error = NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorSecureConnectionFailed,
            userInfo: nil
        )
        XCTAssertEqual(
            InstagramWebView.userFriendlyErrorMessage(for: error),
            "安全な接続を確立できませんでした。時間をおいて再試行してください。"
        )
    }

    func test_userFriendlyErrorMessage_certificateInvalid_mapsToTLSMessage() {
        let error = NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorServerCertificateUntrusted,
            userInfo: nil
        )
        XCTAssertEqual(
            InstagramWebView.userFriendlyErrorMessage(for: error),
            "安全な接続を確立できませんでした。時間をおいて再試行してください。"
        )
    }

    func test_userFriendlyErrorMessage_appTransportSecurity_mapsToTLSMessage() {
        // App Transport Security により非セキュアな http 接続が拒否された場合も、
        // 既存の TLS/証明書系メッセージグループに合流させる（ユーザ視点では
        // 「安全な接続が確立できなかった」事象として同質のため）。
        let error = NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorAppTransportSecurityRequiresSecureConnection,
            userInfo: nil
        )
        XCTAssertEqual(
            InstagramWebView.userFriendlyErrorMessage(for: error),
            "安全な接続を確立できませんでした。時間をおいて再試行してください。"
        )
    }

    func test_userFriendlyErrorMessage_networkAuthenticationRequired_mapsToCaptivePortalMessage() {
        // 公衆 Wi-Fi (ホテル・空港・カフェ等) の Captive Portal 認証が未完了の場合に発火する。
        // ユーザが取るべき具体的なアクション（Wi-Fi のログイン画面を確認）を返す。
        let error = NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorNetworkAuthenticationRequired,
            userInfo: nil
        )
        XCTAssertEqual(
            InstagramWebView.userFriendlyErrorMessage(for: error),
            "ネットワーク認証が必要です。公衆 Wi-Fi のログイン画面をブラウザで開いて認証を完了してから再試行してください。"
        )
    }

    func test_userFriendlyErrorMessage_userAuthenticationRequired_mapsToReLoginMessage() {
        // サーバ／プロキシ側で認証が要求された場合。Instagram 側のセッション失効や
        // 二段階認証要求などで発火しうるため、再ログインを促す。
        let error = NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorUserAuthenticationRequired,
            userInfo: nil
        )
        XCTAssertEqual(
            InstagramWebView.userFriendlyErrorMessage(for: error),
            "認証が必要です。一度ログアウトして再ログインしてから再試行してください。"
        )
    }

    func test_userFriendlyErrorMessage_dataNotAllowed_mapsToCellularDisabledMessage() {
        // 設定でアプリのモバイル通信が無効化されているケース。
        let error = NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorDataNotAllowed,
            userInfo: nil
        )
        XCTAssertEqual(
            InstagramWebView.userFriendlyErrorMessage(for: error),
            "このアプリにモバイル通信の使用が許可されていません。設定 > モバイル通信からアプリを許可するか、Wi-Fi に接続してください。"
        )
    }

    func test_userFriendlyErrorMessage_internationalRoamingOff_mapsToRoamingMessage() {
        let error = NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorInternationalRoamingOff,
            userInfo: nil
        )
        XCTAssertEqual(
            InstagramWebView.userFriendlyErrorMessage(for: error),
            "海外ローミングが無効です。設定 > モバイル通信 > データローミングを確認するか、Wi-Fi に接続してください。"
        )
    }

    func test_userFriendlyErrorMessage_callIsActive_mapsToCallActiveMessage() {
        let error = NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorCallIsActive,
            userInfo: nil
        )
        XCTAssertEqual(
            InstagramWebView.userFriendlyErrorMessage(for: error),
            "通話中のためネットワークが利用できません。通話を終了してから再試行してください。"
        )
    }

    func test_userFriendlyErrorMessage_badServerResponse_mapsToServerErrorMessage() {
        let error = NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorBadServerResponse,
            userInfo: nil
        )
        XCTAssertEqual(
            InstagramWebView.userFriendlyErrorMessage(for: error),
            "サーバから不正な応答が返されました。時間をおいて再試行してください。"
        )
    }

    func test_userFriendlyErrorMessage_zeroByteResource_mapsToServerErrorMessage() {
        // レスポンスボディがゼロバイト（サーバ側が不正な空応答を返した）。
        // ユーザ向けの復旧操作は NSURLErrorBadServerResponse と同じ「時間をおいて再試行」。
        let error = NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorZeroByteResource,
            userInfo: nil
        )
        XCTAssertEqual(
            InstagramWebView.userFriendlyErrorMessage(for: error),
            "サーバから不正な応答が返されました。時間をおいて再試行してください。"
        )
    }

    func test_userFriendlyErrorMessage_cannotDecodeRawData_mapsToServerErrorMessage() {
        // Transfer-Encoding (chunked 等) のデコードに失敗。
        // ユーザ視点では「サーバが壊れたバイナリを返した」状態なので同バケットへ寄せる。
        let error = NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorCannotDecodeRawData,
            userInfo: nil
        )
        XCTAssertEqual(
            InstagramWebView.userFriendlyErrorMessage(for: error),
            "サーバから不正な応答が返されました。時間をおいて再試行してください。"
        )
    }

    func test_userFriendlyErrorMessage_cannotDecodeContentData_mapsToServerErrorMessage() {
        // Content-Encoding (gzip / br 等) のデコードに失敗。
        // 復旧操作は NSURLErrorBadServerResponse と同じ。
        let error = NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorCannotDecodeContentData,
            userInfo: nil
        )
        XCTAssertEqual(
            InstagramWebView.userFriendlyErrorMessage(for: error),
            "サーバから不正な応答が返されました。時間をおいて再試行してください。"
        )
    }

    func test_userFriendlyErrorMessage_cannotParseResponse_mapsToServerErrorMessage() {
        // HTTP レスポンスとしてパース不能（壊れたヘッダ行など）。
        // 復旧操作は NSURLErrorBadServerResponse と同じ。
        let error = NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorCannotParseResponse,
            userInfo: nil
        )
        XCTAssertEqual(
            InstagramWebView.userFriendlyErrorMessage(for: error),
            "サーバから不正な応答が返されました。時間をおいて再試行してください。"
        )
    }

    func test_userFriendlyErrorMessage_tooManyRedirects_mapsToRedirectMessage() {
        let error = NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorHTTPTooManyRedirects,
            userInfo: nil
        )
        XCTAssertEqual(
            InstagramWebView.userFriendlyErrorMessage(for: error),
            "リダイレクトが正しく解決できませんでした。時間をおいて再試行してください。"
        )
    }

    func test_userFriendlyErrorMessage_redirectToNonExistentLocation_mapsToRedirectMessage() {
        let error = NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorRedirectToNonExistentLocation,
            userInfo: nil
        )
        XCTAssertEqual(
            InstagramWebView.userFriendlyErrorMessage(for: error),
            "リダイレクトが正しく解決できませんでした。時間をおいて再試行してください。"
        )
    }

    func test_userFriendlyErrorMessage_unknownNSURLCode_fallsBackToLocalizedDescription() {
        // マッピング表に無い NSURLErrorDomain コードは、従来どおり
        // localizedDescription をそのまま返す。
        let fallback = "Some other URL load error"
        let error = NSError(
            domain: NSURLErrorDomain,
            code: -424242,
            userInfo: [NSLocalizedDescriptionKey: fallback]
        )
        XCTAssertEqual(
            InstagramWebView.userFriendlyErrorMessage(for: error),
            fallback
        )
    }

    func test_userFriendlyErrorMessage_nonNSURLDomain_fallsBackToLocalizedDescription() {
        // NSURLErrorDomain 以外のドメイン（例: NSPOSIXErrorDomain）はマップ対象外。
        let fallback = "Some POSIX failure"
        let error = NSError(
            domain: NSPOSIXErrorDomain,
            code: 5,
            userInfo: [NSLocalizedDescriptionKey: fallback]
        )
        XCTAssertEqual(
            InstagramWebView.userFriendlyErrorMessage(for: error),
            fallback
        )
    }

    // MARK: - userFriendlyErrorMessage（TLS multi-case 内の追加コード）

    func test_userFriendlyErrorMessage_cannotConnectToHost_mapsToServerUnreachableMessage() {
        // `NSURLErrorCannotConnectToHost` は `NSURLErrorCannotFindHost` / `NSURLErrorDNSLookupFailed`
        // と同じバケットへ寄せられている。コード側 multi-case 列挙からの脱落を検出するため、
        // 個別の回帰テストを残す。
        let error = NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorCannotConnectToHost,
            userInfo: nil
        )
        XCTAssertEqual(
            InstagramWebView.userFriendlyErrorMessage(for: error),
            "サーバに接続できませんでした。電波状況を確認して再試行してください。"
        )
    }

    func test_userFriendlyErrorMessage_certificateBadDate_mapsToTLSMessage() {
        // 端末時計が大幅にズレている、または証明書の `notAfter` を超過したケース。
        // TLS 系の multi-case に含まれており、共通の安全な接続メッセージへ寄せる。
        let error = NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorServerCertificateHasBadDate,
            userInfo: nil
        )
        XCTAssertEqual(
            InstagramWebView.userFriendlyErrorMessage(for: error),
            "安全な接続を確立できませんでした。時間をおいて再試行してください。"
        )
    }

    func test_userFriendlyErrorMessage_certificateUnknownRoot_mapsToTLSMessage() {
        // 信頼されていないルート CA（社内 MDM プロキシ等で証明書を差し替えている環境）。
        // ユーザに「安全な接続が確立できない」と認識させたいため、TLS バケットへ。
        let error = NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorServerCertificateHasUnknownRoot,
            userInfo: nil
        )
        XCTAssertEqual(
            InstagramWebView.userFriendlyErrorMessage(for: error),
            "安全な接続を確立できませんでした。時間をおいて再試行してください。"
        )
    }

    func test_userFriendlyErrorMessage_certificateNotYetValid_mapsToTLSMessage() {
        // 端末時計が証明書の `notBefore` よりも前を指しているケース。
        // 多くはユーザ側の端末日付ズレが原因だが、ユーザ向けには TLS 共通メッセージで十分。
        let error = NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorServerCertificateNotYetValid,
            userInfo: nil
        )
        XCTAssertEqual(
            InstagramWebView.userFriendlyErrorMessage(for: error),
            "安全な接続を確立できませんでした。時間をおいて再試行してください。"
        )
    }

    func test_userFriendlyErrorMessage_clientCertificateRejected_mapsToTLSMessage() {
        // MDM 等で配布されたクライアント証明書がサーバに拒否されたケース。
        // 本アプリは Instagram への通常通信が主だが、企業端末のプロキシ環境で発火しうる。
        let error = NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorClientCertificateRejected,
            userInfo: nil
        )
        XCTAssertEqual(
            InstagramWebView.userFriendlyErrorMessage(for: error),
            "安全な接続を確立できませんでした。時間をおいて再試行してください。"
        )
    }

    func test_userFriendlyErrorMessage_clientCertificateRequired_mapsToTLSMessage() {
        // クライアント証明書を要求されたが、端末側に該当証明書が無い／提示されなかったケース。
        let error = NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorClientCertificateRequired,
            userInfo: nil
        )
        XCTAssertEqual(
            InstagramWebView.userFriendlyErrorMessage(for: error),
            "安全な接続を確立できませんでした。時間をおいて再試行してください。"
        )
    }

    // MARK: - mobileSafariUserAgent

    func test_mobileSafariUserAgent_isNotEmpty() {
        // UA 文字列が空だと WKWebView 側でデフォルト UA に戻り、
        // Instagram モバイル Web 版がモバイル分岐に乗らない可能性があるため、
        // 空文字列ではないことを最低限保証する。
        XCTAssertFalse(InstagramWebView.mobileSafariUserAgent.isEmpty)
    }

    func test_mobileSafariUserAgent_identifiesAsIPhone() {
        // モバイル端末として認識されるために `iPhone` トークンを必ず含むこと。
        XCTAssertTrue(InstagramWebView.mobileSafariUserAgent.contains("iPhone"))
    }

    func test_mobileSafariUserAgent_identifiesAsMobile() {
        // Mobile Safari として認識されるために `Mobile/` ビルド指定を含むこと。
        // 一部のサーバは UA 中の `Mobile` トークン有無でモバイル分岐するため、
        // 抜け落ちないように回帰する。
        XCTAssertTrue(InstagramWebView.mobileSafariUserAgent.contains("Mobile/"))
    }

    func test_mobileSafariUserAgent_identifiesAsSafari() {
        // `Safari/` トークンが無いと UA は Mobile Safari ではなく
        // 別ブラウザ (in-app WebView 扱い) と判断され、UI が変わることがある。
        XCTAssertTrue(InstagramWebView.mobileSafariUserAgent.contains("Safari/"))
    }

    func test_mobileSafariUserAgent_includesWebKit() {
        // WebKit ベースであることを示す `AppleWebKit/` を含むこと。
        XCTAssertTrue(InstagramWebView.mobileSafariUserAgent.contains("AppleWebKit/"))
    }

    func test_mobileSafariUserAgent_includesMozillaPrefix() {
        // 慣習に従い `Mozilla/5.0` プレフィクスを持つこと。
        // これが無いと一部の従来型 UA 判定でデスクトップ扱いされる可能性がある。
        XCTAssertTrue(InstagramWebView.mobileSafariUserAgent.hasPrefix("Mozilla/5.0"))
    }

    func test_mobileSafariUserAgent_hasNoControlCharacters() {
        // UA 文字列は HTTP ヘッダに乗るため、改行 / NUL などの制御文字は含めない。
        // `customUserAgent` に流す段階で UIKit 側が rejection するわけではないので、
        // ここで早期に弾く。
        for scalar in InstagramWebView.mobileSafariUserAgent.unicodeScalars {
            XCTAssertFalse(
                CharacterSet.controlCharacters.contains(scalar),
                "UA に制御文字が含まれている: \(scalar.value)"
            )
        }
    }

    // MARK: - CSS 注入定数（hideUnwantedUICSS）

    func test_hideUnwantedUICSS_isNotEmpty() {
        // 空の CSS が WebView に注入されても害は無いが、ビルド時に
        // CSS リテラルが空文字列に置換される事故（マージミス等）に気付くため
        // ガードとして検査する。
        XCTAssertFalse(InstagramWebView.hideUnwantedUICSS.isEmpty)
    }

    func test_hideUnwantedUICSS_hidesBottomTablist() {
        // 下部ナビゲーションバー（role="tablist"）非表示 selector が含まれていること。
        // これが抜け落ちると DM 以外のタブ（フィード・リール・発見）が
        // ボトムバーから露出し、本アプリの主目的が崩れる。
        XCTAssertTrue(
            InstagramWebView.hideUnwantedUICSS.contains("role=\"tablist\""),
            "tablist selector が hideUnwantedUICSS から消えている"
        )
    }

    func test_hideUnwantedUICSS_hidesAppBanner() {
        // アプリ誘導バナー（"Open in app" 等）非表示 selector が含まれていること。
        // class 名が `banner` / `Banner` のどちらかにヒットする想定。
        XCTAssertTrue(
            InstagramWebView.hideUnwantedUICSS.contains("banner")
                || InstagramWebView.hideUnwantedUICSS.contains("Banner"),
            "アプリ誘導バナー非表示 selector が hideUnwantedUICSS から消えている"
        )
    }

    func test_hideUnwantedUICSS_usesImportantToOverrideInlineStyles() {
        // Instagram モバイル Web 側のインラインスタイルや高優先度ルールに勝つため、
        // 非表示 selector は `!important` を伴っている必要がある。
        // `!important` が抜けると一部要素が再表示されるレグレッションが発生しうる。
        XCTAssertTrue(
            InstagramWebView.hideUnwantedUICSS.contains("!important"),
            "!important が hideUnwantedUICSS から欠落している"
        )
    }

    func test_hideUnwantedUICSS_doesNotContainBacktick() {
        // injectStyleJS 内で template literal `...` として埋め込まれるため、
        // CSS 側に backtick が混入すると JavaScript の文字列リテラルが分割され
        // 構文エラーで silent fail する。
        XCTAssertFalse(
            InstagramWebView.hideUnwantedUICSS.contains("`"),
            "CSS 内に backtick が混入している（injectStyleJS の template literal を壊す）"
        )
    }

    func test_hideUnwantedUICSS_doesNotContainTemplateInterpolation() {
        // 同様に `${...}` は JavaScript の template literal で評価されてしまう。
        // CSS 値として `${` を使う必要があれば `\\${` 等のエスケープが必要。
        XCTAssertFalse(
            InstagramWebView.hideUnwantedUICSS.contains("${"),
            "CSS 内に ${ が混入している（JS template literal で評価されてしまう）"
        )
    }

    // MARK: - JS 注入定数（injectStyleJS）

    func test_injectStyleJS_isNotEmpty() {
        XCTAssertFalse(InstagramWebView.injectStyleJS.isEmpty)
    }

    func test_injectStyleJS_includesStyleId() {
        // 冪等な再注入のため、固定 ID 'idoa-injected-style' で既存 <style> を検出する。
        // この ID が変わると重複追加防止が外れ、SPA 遷移ごとに <style> が
        // 累積して DOM が肥大化する。
        XCTAssertTrue(
            InstagramWebView.injectStyleJS.contains("idoa-injected-style"),
            "固定 STYLE_ID が injectStyleJS から消えている"
        )
    }

    func test_injectStyleJS_createsStyleElement() {
        // <style> 要素を生成する DOM 操作を含むこと。
        // createElement('style') と appendChild の両方が必要。
        XCTAssertTrue(
            InstagramWebView.injectStyleJS.contains("createElement('style')")
                || InstagramWebView.injectStyleJS.contains("createElement(\"style\")"),
            "createElement('style') が injectStyleJS から消えている"
        )
        XCTAssertTrue(
            InstagramWebView.injectStyleJS.contains("appendChild"),
            "appendChild が injectStyleJS から消えている"
        )
    }

    func test_injectStyleJS_appendsToHeadOrDocumentElement() {
        // .atDocumentStart 実行時には document.head がまだ存在しない可能性があるため、
        // document.head と document.documentElement の両方を参照し、
        // フォールバックを持つ必要がある。
        XCTAssertTrue(
            InstagramWebView.injectStyleJS.contains("document.head"),
            "document.head 参照が injectStyleJS から消えている"
        )
        XCTAssertTrue(
            InstagramWebView.injectStyleJS.contains("document.documentElement"),
            "document.documentElement フォールバックが injectStyleJS から消えている"
        )
    }

    func test_injectStyleJS_isIdempotentByEarlyReturn() {
        // 同一 ID の <style> が既に存在する場合は早期 return すること。
        // getElementById の存在確認と return の両方を含むことを最低限検査する。
        // （SPA 遷移ごとの evaluateJavaScript 二重注入で <style> が累積するのを防ぐ）
        XCTAssertTrue(
            InstagramWebView.injectStyleJS.contains("getElementById"),
            "getElementById による存在確認が injectStyleJS から消えている"
        )
        XCTAssertTrue(
            InstagramWebView.injectStyleJS.contains("return"),
            "早期 return が injectStyleJS から消えている"
        )
    }

    func test_injectStyleJS_embedsHideUnwantedUICSS() {
        // ビルド時に template literal へ展開された CSS 本体が
        // 完全に含まれていること（split されたり escape で壊れたりしていないこと）。
        XCTAssertTrue(
            InstagramWebView.injectStyleJS.contains(InstagramWebView.hideUnwantedUICSS),
            "hideUnwantedUICSS が injectStyleJS の中に埋め込まれていない"
        )
    }

    func test_injectStyleJS_isWrappedInIIFE() {
        // グローバル汚染を避けるため、注入スクリプトは IIFE (function(){...})()
        // で囲われていることを期待する。IIFE が外れると `style` 等の一時変数が
        // window スコープに残り、ページの JS と衝突しうる。
        XCTAssertTrue(
            InstagramWebView.injectStyleJS.contains("(function()"),
            "IIFE の開きが injectStyleJS に見つからない"
        )
        XCTAssertTrue(
            InstagramWebView.injectStyleJS.contains("})();")
                || InstagramWebView.injectStyleJS.contains("})()"),
            "IIFE の閉じが injectStyleJS に見つからない"
        )
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
