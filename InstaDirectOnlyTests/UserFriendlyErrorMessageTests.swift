import XCTest
@testable import InstaDirectOnly

/// `InstagramWebView.userFriendlyErrorMessage(for:)` のマッピング回帰テスト。
///
/// このヘルパーは `NSURLErrorDomain` の代表的な失敗コードを、
/// エンドユーザ向けの読みやすい日本語メッセージへ変換する。既存の
/// `InstagramWebViewConstantsTests` / `InstagramWebViewURLPolicyTests` は
/// 静的定数や URL 判定ロジックを検証しているが、エラーメッセージの
/// マッピング自体は網羅されていなかった。
///
/// switch case の誤削除・条件反転・未知コードのフォールバック壊れなどを
/// 検知するために、主要ケースを個別のテストとして固定する。
final class UserFriendlyErrorMessageTests: XCTestCase {

    // MARK: - ヘルパー

    /// 指定 domain / code の `NSError` を生成する共通ヘルパー。
    /// `userInfo` は既定で空。`localizedDescription` のフォールバック検証時のみ
    /// `NSLocalizedDescriptionKey` を差し込む。
    private func makeError(
        domain: String,
        code: Int,
        localizedDescription: String? = nil
    ) -> NSError {
        var userInfo: [String: Any] = [:]
        if let description = localizedDescription {
            userInfo[NSLocalizedDescriptionKey] = description
        }
        return NSError(domain: domain, code: code, userInfo: userInfo)
    }

    // MARK: - 返り値が空文字列にならないこと

    func test_returnsNonEmptyString_forKnownNSURLError() {
        // 既知の `NSURLErrorDomain` コードに対して空文字列を返してはならない。
        // 空文字列がオーバーレイに載ると、ユーザは「なぜ失敗したか」「次に何を
        // すべきか」を判断できない。存在検査として代表コードを回帰する。
        let error = makeError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet)
        let message = InstagramWebView.userFriendlyErrorMessage(for: error)
        XCTAssertFalse(message.isEmpty)
    }

    func test_returnsNonEmptyString_forUnknownDomain() {
        // 未知ドメインは `localizedDescription` にフォールバックする。
        // `NSError` の既定 `localizedDescription` は空文字列を返さないため、
        // 未知ドメイン経路でも空文字列にならないことを回帰する。
        let error = makeError(domain: "com.example.custom", code: 42)
        let message = InstagramWebView.userFriendlyErrorMessage(for: error)
        XCTAssertFalse(message.isEmpty)
    }

    // MARK: - オフライン系

    func test_notConnectedToInternet_mentionsInternet() {
        // 「インターネット接続がありません」文言に「インターネット」キーワードが
        // 含まれること。ユーザに原因を伝える主要キーワードなので、削除・差し替えを検知する。
        let error = makeError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet)
        let message = InstagramWebView.userFriendlyErrorMessage(for: error)
        XCTAssertTrue(
            message.contains("インターネット"),
            "オフラインメッセージから『インターネット』キーワードが脱落している"
        )
    }

    func test_notConnectedToInternet_mentionsRetry() {
        // 「再試行してください」相当の行動誘発が含まれること。
        // ユーザの次のアクションを促す文言が抜けると UX が劣化する。
        let error = makeError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet)
        let message = InstagramWebView.userFriendlyErrorMessage(for: error)
        XCTAssertTrue(
            message.contains("再試行"),
            "オフラインメッセージから『再試行』への案内が脱落している"
        )
    }

    func test_networkConnectionLost_mentionsDisconnection() {
        // `NSURLErrorNetworkConnectionLost` は通信中の切断。
        // 「切断」相当のキーワードで原因を明示していること。
        let error = makeError(domain: NSURLErrorDomain, code: NSURLErrorNetworkConnectionLost)
        let message = InstagramWebView.userFriendlyErrorMessage(for: error)
        XCTAssertTrue(
            message.contains("切断"),
            "通信切断メッセージから『切断』キーワードが脱落している"
        )
    }

    // MARK: - タイムアウト

    func test_timedOut_mentionsTimeout() {
        // タイムアウトメッセージに「タイムアウト」キーワードが含まれること。
        let error = makeError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut)
        let message = InstagramWebView.userFriendlyErrorMessage(for: error)
        XCTAssertTrue(
            message.contains("タイムアウト"),
            "タイムアウトメッセージから『タイムアウト』キーワードが脱落している"
        )
    }

    // MARK: - ホスト・DNS 解決失敗

    func test_cannotFindHost_mentionsServer() {
        // `NSURLErrorCannotFindHost` はホスト解決に失敗するケース。
        // 「サーバに接続できませんでした」相当の説明が含まれること。
        let error = makeError(domain: NSURLErrorDomain, code: NSURLErrorCannotFindHost)
        let message = InstagramWebView.userFriendlyErrorMessage(for: error)
        XCTAssertTrue(
            message.contains("サーバ"),
            "ホスト解決失敗メッセージから『サーバ』キーワードが脱落している"
        )
    }

    func test_cannotConnectToHost_mentionsServer() {
        // `NSURLErrorCannotConnectToHost` はホストへの接続確立失敗。
        // `NSURLErrorCannotFindHost` と同じ日本語文言に集約する契約を回帰する。
        let error = makeError(domain: NSURLErrorDomain, code: NSURLErrorCannotConnectToHost)
        let message = InstagramWebView.userFriendlyErrorMessage(for: error)
        XCTAssertTrue(message.contains("サーバ"))
    }

    func test_dnsLookupFailed_mentionsServer() {
        // `NSURLErrorDNSLookupFailed` も DNS 経路の失敗として同じ日本語文言に
        // 集約される契約。三者が同一文言に寄っていることを回帰する。
        let error = makeError(domain: NSURLErrorDomain, code: NSURLErrorDNSLookupFailed)
        let message = InstagramWebView.userFriendlyErrorMessage(for: error)
        XCTAssertTrue(message.contains("サーバ"))
    }

    // MARK: - TLS / 証明書

    func test_secureConnectionFailed_mentionsSecureConnection() {
        // TLS ハンドシェイク失敗系のメッセージが「安全な接続」文言に集約されること。
        // 個別コードをそれぞれ独立した文言にすると翻訳漏れの温床になるため、
        // 「TLS 系はまとめて 1 メッセージ」の契約を回帰する。
        let error = makeError(domain: NSURLErrorDomain, code: NSURLErrorSecureConnectionFailed)
        let message = InstagramWebView.userFriendlyErrorMessage(for: error)
        XCTAssertTrue(
            message.contains("安全な接続"),
            "TLS 失敗メッセージから『安全な接続』キーワードが脱落している"
        )
    }

    func test_serverCertificateUntrusted_mentionsSecureConnection() {
        // 「証明書が信頼できない」も同じ「安全な接続」メッセージへ集約する契約。
        let error = makeError(domain: NSURLErrorDomain, code: NSURLErrorServerCertificateUntrusted)
        let message = InstagramWebView.userFriendlyErrorMessage(for: error)
        XCTAssertTrue(message.contains("安全な接続"))
    }

    // MARK: - 認証系

    func test_networkAuthenticationRequired_mentionsAuthentication() {
        // 公衆 Wi-Fi のキャプティブポータル等のケース。
        // ユーザが「ブラウザで認証を完了する」ことを促す文言が含まれること。
        let error = makeError(domain: NSURLErrorDomain, code: NSURLErrorNetworkAuthenticationRequired)
        let message = InstagramWebView.userFriendlyErrorMessage(for: error)
        XCTAssertTrue(
            message.contains("認証"),
            "ネットワーク認証必須メッセージから『認証』キーワードが脱落している"
        )
    }

    func test_userAuthenticationRequired_mentionsAuthentication() {
        // Instagram 側のセッション切れ等。「認証」文言と再ログイン誘導が含まれること。
        let error = makeError(domain: NSURLErrorDomain, code: NSURLErrorUserAuthenticationRequired)
        let message = InstagramWebView.userFriendlyErrorMessage(for: error)
        XCTAssertTrue(message.contains("認証"))
    }

    // MARK: - モバイル通信 / ローミング

    func test_dataNotAllowed_mentionsCellular() {
        // アプリにモバイル通信の使用が許可されていないケース。
        // 「モバイル通信」文言で設定変更を案内できていること。
        let error = makeError(domain: NSURLErrorDomain, code: NSURLErrorDataNotAllowed)
        let message = InstagramWebView.userFriendlyErrorMessage(for: error)
        XCTAssertTrue(
            message.contains("モバイル通信"),
            "モバイル通信非許可メッセージから『モバイル通信』キーワードが脱落している"
        )
    }

    func test_internationalRoamingOff_mentionsRoaming() {
        // 海外ローミング無効時のケース。「ローミング」文言で設定箇所を案内できていること。
        let error = makeError(domain: NSURLErrorDomain, code: NSURLErrorInternationalRoamingOff)
        let message = InstagramWebView.userFriendlyErrorMessage(for: error)
        XCTAssertTrue(
            message.contains("ローミング"),
            "海外ローミング無効メッセージから『ローミング』キーワードが脱落している"
        )
    }

    // MARK: - サーバ応答不正

    func test_badServerResponse_mentionsServer() {
        // 「サーバから不正な応答」文言に集約される契約を回帰する。
        // `NSURLErrorZeroByteResource` / `NSURLErrorCannotDecodeRawData` 等と
        // 同一文言に寄っていることの回帰は下の 2 テストで担保する。
        let error = makeError(domain: NSURLErrorDomain, code: NSURLErrorBadServerResponse)
        let message = InstagramWebView.userFriendlyErrorMessage(for: error)
        XCTAssertTrue(
            message.contains("サーバから不正な応答"),
            "サーバ応答不正メッセージが期待文言に一致しない"
        )
    }

    func test_cannotDecodeRawData_sharesBadServerResponseMessage() {
        // デコード失敗系は「サーバから不正な応答」文言に集約する契約。
        let error = makeError(domain: NSURLErrorDomain, code: NSURLErrorCannotDecodeRawData)
        let message = InstagramWebView.userFriendlyErrorMessage(for: error)
        XCTAssertTrue(message.contains("サーバから不正な応答"))
    }

    func test_zeroByteResource_sharesBadServerResponseMessage() {
        // 0 バイト応答も「サーバから不正な応答」文言に集約する契約。
        let error = makeError(domain: NSURLErrorDomain, code: NSURLErrorZeroByteResource)
        let message = InstagramWebView.userFriendlyErrorMessage(for: error)
        XCTAssertTrue(message.contains("サーバから不正な応答"))
    }

    // MARK: - リダイレクト

    func test_httpTooManyRedirects_mentionsRedirect() {
        // 「リダイレクトが正しく解決できませんでした」メッセージへ寄せる契約。
        let error = makeError(domain: NSURLErrorDomain, code: NSURLErrorHTTPTooManyRedirects)
        let message = InstagramWebView.userFriendlyErrorMessage(for: error)
        XCTAssertTrue(
            message.contains("リダイレクト"),
            "多重リダイレクトメッセージから『リダイレクト』キーワードが脱落している"
        )
    }

    // MARK: - 通話中

    func test_callIsActive_mentionsCall() {
        // 通話中でネットワーク不可のケース。「通話」文言で原因を明示できていること。
        let error = makeError(domain: NSURLErrorDomain, code: NSURLErrorCallIsActive)
        let message = InstagramWebView.userFriendlyErrorMessage(for: error)
        XCTAssertTrue(
            message.contains("通話"),
            "通話中メッセージから『通話』キーワードが脱落している"
        )
    }

    // MARK: - フォールバック

    func test_unknownNSURLErrorCode_fallsBackToLocalizedDescription() {
        // switch にヒットしない `NSURLErrorDomain` の未知コードは
        // `error.localizedDescription` をそのまま返す契約。
        // 未知コードを 0 とし、明示的な `NSLocalizedDescriptionKey` を注入する
        // ことでフォールバック経路を検証する。
        let expected = "テスト用の未知エラー説明"
        let error = makeError(
            domain: NSURLErrorDomain,
            code: 999_999,
            localizedDescription: expected
        )
        let message = InstagramWebView.userFriendlyErrorMessage(for: error)
        XCTAssertEqual(
            message,
            expected,
            "未知の NSURLErrorDomain コードで localizedDescription へフォールバックしていない"
        )
    }

    func test_nonURLDomain_fallsBackToLocalizedDescription() {
        // `NSURLErrorDomain` 以外のドメイン（`WebKitErrorDomain` 等）は
        // switch を経由せず `localizedDescription` にフォールバックする契約。
        let expected = "カスタムドメインのエラーメッセージ"
        let error = makeError(
            domain: "com.example.custom",
            code: 42,
            localizedDescription: expected
        )
        let message = InstagramWebView.userFriendlyErrorMessage(for: error)
        XCTAssertEqual(
            message,
            expected,
            "NSURLErrorDomain 以外のドメインで localizedDescription へフォールバックしていない"
        )
    }

    func test_webKitErrorDomain_fallsBackToLocalizedDescription() {
        // `WebKitErrorDomain` のエラーは `isIgnorableNavigationError` で
        // 早期 return される想定だが、`userFriendlyErrorMessage` に到達した
        // 場合は `localizedDescription` にフォールバックする契約。
        // `handleNavigationError` の呼び出し順序が変わっても壊れないよう
        // 独立に回帰しておく。
        let expected = "WebKit 側の任意メッセージ"
        let error = makeError(
            domain: InstagramWebView.webKitErrorDomain,
            code: 200,
            localizedDescription: expected
        )
        let message = InstagramWebView.userFriendlyErrorMessage(for: error)
        XCTAssertEqual(message, expected)
    }
}
