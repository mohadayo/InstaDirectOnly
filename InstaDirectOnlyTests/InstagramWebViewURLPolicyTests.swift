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
