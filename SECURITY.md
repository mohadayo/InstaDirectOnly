# Security Policy

## 対応バージョン

`main` ブランチのみサポート対象です。過去のタグ・ビルドに対するセキュリティ修正のバックポートは行いません。

## 脆弱性の報告

セキュリティに関わる問題は **公開 Issue に投稿しないでください**。
GitHub の [Security Advisories](https://github.com/mohadayo/InstaDirectOnly/security/advisories/new) 経由で
非公開で報告してください。

### 報告に含めてほしい内容

- 対象コミット SHA / タグ
- 再現手順（可能なら最小 URL / HTML 例）
- 想定される影響
- （任意）修正案・PoC

24〜72 時間以内に一次応答することを目標とします。

## 脅威モデル

本アプリは Instagram のモバイル Web 版を `WKWebView` でラップし、
**Direct Message 以外の導線を利用者から遮断すること** を目的としています。
以下のカテゴリを主要な脅威として扱います。

1. **DM 以外への意図しない遷移** — フィード・発見タブ・広告・アプリ誘導バナー等への遷移
2. **allowlist の回避** — 偽装ホスト・パストラバーサル・スキーム細工など
3. **認証情報の漏洩** — 許可外オリジンに Cookie / セッションが渡る動作
4. **DoS 相当のクラッシュループ** — Web Content Process の連続クラッシュによるバッテリー浪費

## 設計上の防御ライン

以下は `InstaDirectOnly/InstagramWebView.swift` を中心とする防御の要点です。
セキュリティレビューの際はこれらの `static` 定数・ヘルパーを回帰対象としてください。

### URL Allowlist

- `allowedSchemes = ["http", "https"]`
  - `javascript:` / `data:` / `file:` / `ftp:` を早期に排除
  - `javascript://www.instagram.com/direct/inbox/` のようにホスト位置に既知ドメインを埋め込んだ URL は
    `url.host` が `"www.instagram.com"` を返しうるため、**スキームチェックを最初に実行**
- `allowedHosts` — CDN・認証系ホストを完全一致 or サブドメインでのみ許可
  - `isHost(_:equalToOrSubdomainOf:)` で `host == domain || host.hasSuffix("." + domain)` を判定
  - `evil-instagram.com.attacker.example` のような偽装ホストを拒否
- `allowedPaths` — DM 利用に必要な Instagram 側パスのみ
  - `pathMatches(_:target:)` でセグメント境界一致（`/directfake` を誤許可しない）
  - `hasPathTraversal(_:)` で `.` / `..` セグメントを含むパスを拒否
    （`URL.path` が `/direct/../explore/` をそのまま返す挙動への対策）
- `allowedAboutURLs = {"about:blank", "about:srcdoc"}`
  - `about:config` 等の予期しない about URL を無条件で通さない
  - 将来 WebKit が追加する未知の `about:` URL が素通りする事故を防ぐ

### クラッシュ復帰のレート制限

`webViewWebContentProcessDidTerminate(_:)` はクラッシュ前 URL（許可済みのみ）を再ロードして自動復帰します。
無限ループとバッテリー浪費を防ぐため：

- `crashRecoveryWindow = 30` 秒
- `crashRecoveryMaxAttempts = 3` 回
- 超過時は自動復帰を停止し、`crashRecoveryGiveUpMessage` を表示
- ユーザが再試行ボタンを押すと `resetCrashRecoveryState()` でカウンタをクリア

### 新規ウィンドウ

`webView(_:createWebViewWith:for:windowFeatures:)` は `target="_blank"` / `window.open` を
「同 WebView でロード（URL allowlist 通過時のみ）」で受け止め、外部ブラウザには渡しません。
DM 外への離脱導線を作らないための設計です。

## セキュリティに影響する PR のレビュー観点

以下の変更を含む PR は最低 1 名のセキュリティレビューを必須とします：

- `InstagramWebView.swift` の `allowedSchemes` / `allowedHosts` / `allowedPaths` / `allowedAboutURLs` の追加・変更
- `isAllowedURL` / `isHost` / `pathMatches` / `hasPathTraversal` / `isAllowedAboutURL` の判定ロジック変更
- `decidePolicyFor` / `createWebViewWith` の分岐変更
- `webViewWebContentProcessDidTerminate` のリロード対象 URL 決定ロジック変更
- `WKWebViewConfiguration` の `websiteDataStore` / `userContentController` の設定変更

対応するテスト（`InstaDirectOnlyTests/InstagramWebViewURLPolicyTests.swift`
`InstaDirectOnlyTests/InstagramWebViewConstantsTests.swift`）の追加・更新を伴わない
allowlist の緩和は原則としてマージしません。
