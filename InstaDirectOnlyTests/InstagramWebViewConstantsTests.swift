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

    // MARK: - allowedAboutURLs / isAllowedAboutURL

    func test_allowedAboutURLs_isNotEmpty() {
        // allowlist が空だと `decidePolicyFor` で `about:blank` までも拒否され、
        // WKWebView の初期遷移や iframe 初期化が機能しなくなる。
        // 最低限の存在検査として残す。
        XCTAssertFalse(InstagramWebView.allowedAboutURLs.isEmpty)
    }

    func test_allowedAboutURLs_containsAboutBlank() {
        // `about:blank` は WKWebView 自身が iframe 初期化やフラグメント遷移の
        // 中継として発火させる正当な URL。脱落すると初期ロードが走らないため
        // 明示的にアサートする。
        XCTAssertTrue(InstagramWebView.allowedAboutURLs.contains("about:blank"))
    }

    func test_allowedAboutURLs_containsAboutSrcdoc() {
        // `about:srcdoc` は `<iframe srcdoc>` のソース URL として使われる。
        // 脱落すると srcdoc 経由の埋め込みが拒否される。
        XCTAssertTrue(InstagramWebView.allowedAboutURLs.contains("about:srcdoc"))
    }

    func test_allowedAboutURLs_doesNotContainUnsafeAboutURLs() {
        // `about:config` / `about:cache` / `about:newtab` 等、本アプリの用途で
        // 発生する余地が無い about URL は allowlist に含まれないこと。
        // 将来 WebKit が新しい about URL をサポートしてもデフォルト拒否を保つ。
        let unsafeURLs: [String] = [
            "about:config", "about:cache", "about:newtab", "about:about",
            "about:settings", "about:home", "about:debug"
        ]
        for url in unsafeURLs {
            XCTAssertFalse(
                InstagramWebView.allowedAboutURLs.contains(url),
                "allowedAboutURLs に想定外の URL \(url) が混入している"
            )
        }
    }

    func test_isAllowedAboutURL_returnsTrueForAboutBlank() {
        // 標準的な `about:blank` を渡すと true を返すこと。
        let url = URL(string: "about:blank")!
        XCTAssertTrue(InstagramWebView.isAllowedAboutURL(url))
    }

    func test_isAllowedAboutURL_returnsTrueForAboutSrcdoc() {
        // `about:srcdoc` を渡すと true を返すこと。
        let url = URL(string: "about:srcdoc")!
        XCTAssertTrue(InstagramWebView.isAllowedAboutURL(url))
    }

    func test_isAllowedAboutURL_normalizesSchemeAndPathCase() {
        // `ABOUT:Blank` のような大文字混じりも、`absoluteString.lowercased()` 経由で
        // `about:blank` と等価に扱われること。
        // Foundation の URL は scheme を正規化することがあるが、本ヘルパーは
        // それに依存せず自前で `lowercased()` するため、ケース不変が保証される。
        let url = URL(string: "ABOUT:Blank")!
        XCTAssertTrue(InstagramWebView.isAllowedAboutURL(url))
    }

    func test_isAllowedAboutURL_returnsFalseForAboutConfig() {
        // `about:config` のような想定外の about URL は false を返すこと。
        // これにより `decidePolicyFor` 側でナビゲーションがキャンセルされ、
        // 未知の about URL が無条件で通過する事故を防ぐ。
        let url = URL(string: "about:config")!
        XCTAssertFalse(InstagramWebView.isAllowedAboutURL(url))
    }

    func test_isAllowedAboutURL_returnsFalseForAboutNewtab() {
        // 他ブラウザの新規タブを示す about URL も拒否。
        let url = URL(string: "about:newtab")!
        XCTAssertFalse(InstagramWebView.isAllowedAboutURL(url))
    }

    func test_isAllowedAboutURL_returnsFalseForNonAboutScheme() {
        // 呼び出し側が誤って `about:` 以外のスキームを渡した場合は false を返すこと。
        // ガード句 (`guard url.scheme?.lowercased() == "about"`) の取り違え検出。
        let httpsURL = URL(string: "https://www.instagram.com/direct/inbox/")!
        XCTAssertFalse(InstagramWebView.isAllowedAboutURL(httpsURL))
        let javascriptURL = URL(string: "javascript:about:blank")!
        XCTAssertFalse(InstagramWebView.isAllowedAboutURL(javascriptURL))
    }

    func test_isAllowedAboutURL_returnsFalseForAboutBlankWithQueryOrFragment() {
        // `about:blank?foo=bar` のように、許可リストに無いバリアントは false を返すこと。
        // 完全一致比較を保証する回帰テスト。
        let queryURL = URL(string: "about:blank?foo=bar")!
        XCTAssertFalse(InstagramWebView.isAllowedAboutURL(queryURL))
        let fragmentURL = URL(string: "about:blank#section")!
        XCTAssertFalse(InstagramWebView.isAllowedAboutURL(fragmentURL))
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

    // MARK: - mobileSafariUserAgent
    //
    // Instagram モバイル Web 版は UA を見てモバイル UI / 機能セットに分岐する。
    // 「モバイル Safari」と誤解なく認識されるフォーマットを維持しないと、
    // アプリ誘導フルスクリーンページに寄せられたり、`window.open` の挙動が
    // 変わったりする。UA 文字列全体を完全一致で固定すると iOS バージョン
    // bump ごとに全テストが赤くなるため、要件を「必須トークンの存在」に
    // 分解して検証し、フォーマットの根幹だけを回帰させる。

    func test_mobileSafariUserAgent_isNotEmpty() {
        // 空文字列に誤変更された場合、WKWebView は UA を送らず既定値になり、
        // Instagram 側のモバイル UI 分岐が壊れる。存在検査として残す。
        XCTAssertFalse(InstagramWebView.mobileSafariUserAgent.isEmpty)
    }

    func test_mobileSafariUserAgent_containsSafariToken() {
        // `Safari/<build>` トークンは UA が「Safari 系ブラウザ」として認識される
        // 前提。抜けると WebView 判定・WKWebView 判定に落ちるサイトが増える。
        XCTAssertTrue(
            InstagramWebView.mobileSafariUserAgent.contains("Safari/"),
            "UA から `Safari/` トークンが脱落している"
        )
    }

    func test_mobileSafariUserAgent_containsMobileToken() {
        // `Mobile/<build>` トークンはモバイル UI 分岐を有効化する。抜けると
        // Instagram が PC 版レイアウトを返してくる可能性がある。
        XCTAssertTrue(
            InstagramWebView.mobileSafariUserAgent.contains("Mobile/"),
            "UA から `Mobile/` トークンが脱落している"
        )
    }

    func test_mobileSafariUserAgent_containsIPhonePlatform() {
        // プラットフォーム識別子 `iPhone` が抜けると、Instagram 側が
        // iPad / Android UI へ寄せる可能性がある。
        XCTAssertTrue(
            InstagramWebView.mobileSafariUserAgent.contains("iPhone"),
            "UA から `iPhone` プラットフォーム識別子が脱落している"
        )
    }

    func test_mobileSafariUserAgent_containsVersionToken() {
        // Safari の慣習として `Version/<safari-version>` を含む。抜けると
        // 「Safari 以外の WebKit」と判定するサーバに当たった際に UI が崩れる。
        XCTAssertTrue(
            InstagramWebView.mobileSafariUserAgent.contains("Version/"),
            "UA から `Version/` トークンが脱落している"
        )
    }

    func test_mobileSafariUserAgent_startsWithMozillaPrefix() {
        // 実 Safari の UA と同じく `Mozilla/5.0` プレフィックスで始まる。
        // 抜けると単純な `startsWith('Mozilla')` 型の UA スニッフィングで
        // 弾かれるサーバに遭遇し得るため、慣習的な先頭を固定しておく。
        XCTAssertTrue(
            InstagramWebView.mobileSafariUserAgent.hasPrefix("Mozilla/5.0"),
            "UA が `Mozilla/5.0` で始まっていない"
        )
    }

    // MARK: - hideUnwantedUICSS
    //
    // `hideUnwantedUICSS` は `injectStyleJS` の中で JS テンプレートリテラル
    // (バックティック文字列) の `${...}` として埋め込まれる。CSS 側にバック
    // ティック `` ` `` や `${` が現れると、生成される JS 全体が構文エラーで
    // 死に、CSS が挿入されず DM 以外の UI が露出する。プロダクトコードで
    // 直接エスケープする代わりに、混入をユニットテストで検知することで
    // 「気づいたら壊れていた」事故を防ぐ。

    func test_hideUnwantedUICSS_isNotEmpty() {
        // 空文字列に誤変更されると、`<style>` が空タグになり非表示 CSS が
        // 一切適用されない。DM 以外の UI が丸見えになる回帰の入口。
        XCTAssertFalse(InstagramWebView.hideUnwantedUICSS.isEmpty)
    }

    func test_hideUnwantedUICSS_doesNotContainBacktick() {
        // バックティックが混ざると `injectStyleJS` のテンプレートリテラルを
        // 途中で終端させ、以降の JS が壊れる。CSS 上バックティックを使う
        // 必要は無いので、混入即エラーとして固定する。
        XCTAssertFalse(
            InstagramWebView.hideUnwantedUICSS.contains("`"),
            "hideUnwantedUICSS にバックティックが混入している (injectStyleJS の JS テンプレートを破壊する)"
        )
    }

    func test_hideUnwantedUICSS_doesNotContainDollarBrace() {
        // `${` は JS テンプレート補間の開始トークン。CSS 側に紛れると
        // `injectStyleJS` の中で「未定義の識別子を補間」と解釈され構文エラー。
        // CSS 上必要性が無いので、混入禁止として固定する。
        XCTAssertFalse(
            InstagramWebView.hideUnwantedUICSS.contains("${"),
            "hideUnwantedUICSS に `${` が混入している (injectStyleJS の JS テンプレート補間を誤発火させる)"
        )
    }

    func test_hideUnwantedUICSS_targetsAppStoreLinks() {
        // 現行 `apps.apple.com` 経由のアプリ誘導バナー selector が生きていること。
        // Instagram モバイル Web 版が挿入する「App でも使えます」バナーの
        // 主要 selector を回帰的に固定しておくと、CSS リファクタで
        // うっかり削除するのを検知できる。
        XCTAssertTrue(
            InstagramWebView.hideUnwantedUICSS.contains("apps.apple.com"),
            "hideUnwantedUICSS から現行 App Store ドメインの selector が脱落している"
        )
    }

    // MARK: - injectStyleJS
    //
    // 「同一 ID の `<style>` が既に存在する場合は何もしない」冪等性を担保する
    // 前提として、STYLE_ID が変更されてはならない。また、IIFE で囲むことで
    // グローバルスコープの汚染を避ける契約も回帰対象。

    func test_injectStyleJS_isNotEmpty() {
        // 空文字列だと `evaluateJavaScript` が no-op になり、SPA 遷移後の
        // CSS 再注入が働かなくなる。存在検査として残す。
        XCTAssertFalse(InstagramWebView.injectStyleJS.isEmpty)
    }

    func test_injectStyleJS_referencesExpectedStyleId() {
        // 冪等な style 挿入は `document.getElementById('idoa-injected-style')`
        // が存在チェックで一致することに依存している。ID 文字列が誤って
        // 変更されると、SPA 遷移ごとに `<style>` が重複追加されていく。
        XCTAssertTrue(
            InstagramWebView.injectStyleJS.contains("'idoa-injected-style'"),
            "injectStyleJS が想定の STYLE_ID `idoa-injected-style` を参照していない"
        )
    }

    func test_injectStyleJS_isWrappedInIIFE() {
        // グローバルスコープを汚さないよう IIFE で包む契約。
        // `(function()` の脱落は `STYLE_ID` などのローカル変数を global に露出させ、
        // 他のスクリプトと衝突する余地を作る。
        XCTAssertTrue(
            InstagramWebView.injectStyleJS.contains("(function()"),
            "injectStyleJS が IIFE で包まれていない (グローバルスコープ汚染の危険)"
        )
    }

    func test_injectStyleJS_embedsHideUnwantedUICSS() {
        // `hideUnwantedUICSS` が JS に展開されて含まれていることを、代表的な
        // selector (`tablist`) の存在で確認する。CSS 定数の誤挿入経路を
        // 挙動テストなしで検知できる。
        XCTAssertTrue(
            InstagramWebView.injectStyleJS.contains("tablist"),
            "injectStyleJS に hideUnwantedUICSS の内容が展開されていない"
        )
    }
}
