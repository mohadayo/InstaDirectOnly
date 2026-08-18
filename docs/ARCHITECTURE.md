# アーキテクチャ

このドキュメントは InstaDirectOnly の内部構造をコントリビュータ向けにまとめた「バードビュー」です。ユーザー向けの操作説明・機能一覧は [`README.md`](../README.md) に、変更履歴は [`CHANGELOG.md`](../CHANGELOG.md) に、コントリビュート手順は [`CONTRIBUTING.md`](../CONTRIBUTING.md) に分離しています。ここでは「なぜこの構造なのか」「新しい機能を足すときにどこを触るのか」に焦点を当てます。

本ドキュメントは実装（`InstaDirectOnly/*.swift`）に対する概念モデルです。個別 API のシグネチャや細かな挙動はソースを一次情報とし、両者に差分が出た場合はコード側を正としてください。

## 1. モジュール構成

アプリは意図的に薄く、Apple 標準の WebKit の上に必要最小限のガード層を重ねただけの構造です。

```
┌────────────────────────────────────────────────────────────┐
│ InstaDirectOnlyApp        (@main / App シーンのエントリ)    │
│  └─ ContentView           (SwiftUI ルート)                  │
│      ├─ InstagramWebView  (UIViewRepresentable ラッパ)      │
│      │   └─ Coordinator   (WKNavigationDelegate,            │
│      │                     WKUIDelegate, KVO オブザーバ)    │
│      │       └─ WKWebView (WebKit フレームワーク実体)       │
│      ├─ ProgressView      (中央スピナー / 上部プログレスバー)│
│      └─ Error Overlay     (再試行ボタン付き半透明レイヤ)    │
└────────────────────────────────────────────────────────────┘
```

各レイヤの責務境界は次の通りです。

| レイヤ | 主なファイル | 責務 | 責務外 |
|---|---|---|---|
| App | `InstaDirectOnlyApp.swift` | シーン初期化・ルートビューの提示 | ネットワーク・URL 判定 |
| View | `ContentView.swift` | ロード状態と `errorMessage` のバインド、オーバーレイの出し分け | URL の許可判定・CSS 注入 |
| Bridge | `InstagramWebView.swift` (`UIViewRepresentable`) | `WKWebView` の生成・設定、静的な URL/UA/CSS 定数の集約、ユーザー向けエラーメッセージの生成 | UI レイアウト |
| Delegate | `InstagramWebView.Coordinator` | `WKNavigationDelegate` / `WKUIDelegate` / `estimatedProgress` の KVO 観測 | View の再描画（`@Binding` 経由でのみ通知） |
| Web | `WKWebView` | ネットワーク・レンダリング・Cookie 永続化 | アプリのポリシー適用 |

「独自バックエンドを持たない」「セッションを Apple の標準ストア (`WKWebsiteDataStore.default()`) に完全に委ねる」ことが本アプリの前提であり、この前提が壊れる変更（独自 API 呼び出し、独自 Cookie 管理など）はアーキテクチャレベルの意思決定を伴うため、別途 Issue で合意を取ってください。

## 2. 起動シーケンス

コールドスタートから DM 受信箱表示までのタイムラインは以下の通りです。

```
[起動]
  ↓
InstaDirectOnlyApp.body  … WindowGroup { ContentView() }
  ↓
ContentView.body         … @State isLoading = true, errorMessage = nil, loadProgress = 0
  ↓
InstagramWebView.makeUIView(context:)
  ├─ WKWebViewConfiguration を組み立てる
  │   ├─ websiteDataStore = .default()     … Cookie / LocalStorage を永続化
  │   └─ userContentController.addUserScript(WKUserScript(source: injectStyleJS, at: .atDocumentStart, forMainFrameOnly: false))
  ├─ WKWebView(frame: .zero, configuration: config)
  │   ├─ customUserAgent = mobileSafariUserAgent   … Instagram のモバイル UI 分岐に必須
  │   ├─ navigationDelegate = context.coordinator
  │   └─ uiDelegate         = context.coordinator
  ├─ Coordinator が estimatedProgress を KVO 観測開始
  └─ load(URLRequest(url: dmURL))            … https://www.instagram.com/direct/inbox/
  ↓
WKNavigationDelegate コールバック連鎖
  ├─ decidePolicyFor navigationAction → isAllowedURL で許可判定
  ├─ didStartProvisionalNavigation    → isLoading = true
  ├─ (loadProgress が 0→1 に上がる)   → 上部プログレスバーが伸びる
  ├─ didCommit                        → 実 URL が確定
  ├─ didFinish                        → CSS 注入 JS を再実行 / isLoading = false
  └─ 失敗系: didFail / didFailProvisionalNavigation
                                      → isIgnorableNavigationError で除外 or errorMessage をセット
```

初期化に関する重要な設計判断：

- **`dmURL` の固定**: 起動 URL は `https://www.instagram.com/direct/inbox/` に固定しています。ディープリンクや直近の閲覧位置の復元は行いません（Instagram 側の SPA が自律的に前回状態へ復帰するため）。
- **UA の 1 箇所集約**: `mobileSafariUserAgent` を `static let` にしているため、iOS メジャーバージョンを引き上げる際に触る箇所は `InstagramWebView.swift` の 1 定数だけです。UA 変更時は `InstagramWebViewURLPolicyTests` の UA フォーマット検査を必ず流してください。
- **CSS 注入スクリプトのタイミング**: `.atDocumentStart` を選ぶことで、フィード用ナビゲーションバーやアプリ誘導バナーが「初回レイアウトの前」に非表示化されます。`.atDocumentEnd` を選ぶと一瞬 UI がちらつくため採用していません。

## 3. URL ポリシー層

URL ポリシーは **静的判定**（`InstagramWebView.isAllowedURL`）と **動的判定**（`Coordinator.webView(_:decidePolicyFor:decisionHandler:)`）の二段構えで、それぞれ役割が異なります。

| 判定 | 呼び出し元 | 入力 | 目的 |
|---|---|---|---|
| 静的判定 `isAllowedURL(_:)` | ユニットテスト / 動的判定内部 | 生の `URL` | スキーム・ホスト・パス・トラバーサルの完全ロジックを純粋関数として検査 |
| 動的判定 `decidePolicyFor` | `WKNavigationDelegate` | `WKNavigationAction` | 実際のナビゲーションを許可／キャンセルし、`about:blank` などの特殊ケースを追加ハンドリング |

### 3.1 静的判定の性質

`isAllowedURL` は次の順で deny-by-default に絞り込みます。

1. **スキーム allowlist** — `http` / `https` のみ通過（大文字小文字を正規化）。`javascript://www.instagram.com/direct/` のようにホスト部に既知ドメインを埋め込む攻撃を早期に落とすため。
2. **ホスト allowlist** — `instagram.com` / `cdninstagram.com` / `fbcdn.net` / `facebook.com` / `fbsbx.com` に対する **完全一致またはサブドメイン一致のみ**。`host.contains(...)` のような部分一致は使いません（`evil-instagram.com.attacker.example` の防御）。
3. **パス allowlist（Instagram ドメインのみ）** — `/direct`, `/accounts/login`, `/challenge`, `/api/v1`, `/oauth`, `/` などの **完全一致または `target/` prefix**。`/directfake` のような prefix 取りこぼしを防ぎます。
4. **パストラバーサル拒否（Instagram ドメインのみ）** — `..` / `.` を **セグメントとして** 含む場合は即拒否。`URL.path` は traversal を解決しないため、そのままだと `/direct/../explore/` が prefix 一致で通過してしまうのを防ぎます。CDN/認証系ホストはパス検査そのものをスキップします（パス責務は CDN 側）。

`isAllowedURL` は副作用を持たない `static` メソッドなので、ユニットテストは WebView を起動せず文字列 → 判定結果のみで境界を回帰できます。

### 3.2 動的判定の性質

`decidePolicyFor` は `isAllowedURL` を呼び出しつつ、次の「静的判定では判定不能なケース」を追加でハンドリングします。

- `about:blank` などの初期化フロー・iframe 用の URL を明示的に許可（静的判定では拒否される）。
- 許可外 URL を検知したときは `decisionHandler(.cancel)` を返し、初期ロード完了後であれば DM URL へ戻す。
- キャンセル起因で `WKNavigationDelegate` の失敗コールバックが `WebKitErrorDomain / 102` として発火するため、`isIgnorableNavigationError` で除外する（詳細は §5）。

### 3.3 新規ウィンドウ（`WKUIDelegate`）

`target="_blank"` や `window.open` は `WKNavigationDelegate` ではなく `WKUIDelegate.webView(_:createWebViewWith:for:windowFeatures:)` に配送されます。未実装だと **silent fail**（タップしても何も起きない）になるため、`Coordinator` を `WKUIDelegate` に準拠させて次のように振る舞います。

- 許可 URL → **同じ `WKWebView` で `load(_:)`**。新しいウィンドウは生成しません（DM 内リンクが途切れない）。
- 許可外 URL → **何もしない**。外部ブラウザや SFSafariViewController を開かず、DM 外への離脱導線を作らないという方針を優先します。

## 4. UI 注入層

DM 画面に残る「DM 以外への導線」は CSS で視覚的に隠します。CSS は「アプリの URL ポリシーによるブロック」を代替するものではなく、あくまで **見た目の整理** です。

### 4.1 二段構えの注入

1. **`.atDocumentStart` によるユーザースクリプト** — `WKUserContentController.addUserScript` で登録し、ドキュメント生成直後・初回レイアウト前に `<style>` を `document.head`（無ければ `documentElement`）へ追加。
2. **`didFinish` からの `evaluateJavaScript` フォールバック** — Instagram は History API による soft navigation（SPA 遷移）が多いため、document が再生成されず `.atDocumentStart` が再発火しないケースがあります。`didFinish` で同じ JS を再実行することで、SPA 遷移後にもルールが確実に適用されます。

注入 JS は固定 ID (`idoa-injected-style`) の `<style>` を追加する前に既存要素の有無を確認するため、同一 document への二重注入は安全に no-op になります。

### 4.2 セレクタの責務

`hideUnwantedUICSS` は `display: none !important` で以下を隠します。

- 下部ナビゲーション（タブ）バー — `div[role="tablist"]`、および「ホーム (`href="/"`) へのリンクを持ち DM リンクを含まない」`nav` 要素
- アプリ誘導バナー — クラス名に `banner` / `Banner` を含む要素、App Store（`app-store` / `itunes.apple.com` / `apps.apple.com`）へのリンクを含む要素

Instagram モバイル Web 版のマークアップ変更に追従できていないケースはあり得ますが、遷移そのものは §3 の URL ポリシーで別途ブロックされるため、DM 以外のページに **実際に移動する** ことはありません。

## 5. エラーハンドリング層

`WKNavigationDelegate` の失敗コールバックは、URL ポリシー起因のキャンセルとネットワーク起因の失敗が同じ経路に流れてきます。両者を区別しないと、許可外 URL をタップしただけで「読み込みに失敗しました」オーバーレイが一瞬表示されてしまうリグレッションが起きます。

### 5.1 正常系除外 (`isIgnorableNavigationError`)

`InstagramWebView.isIgnorableNavigationError(_:)` は次のいずれかに該当するエラーを **UI に出さない** ものとして集約判定します。

- `NSURLErrorDomain / -999 (NSURLErrorCancelled)` — 戻る操作や許可外 URL のブロック
- `WebKitErrorDomain / 101 (WebKitErrorCannotShowURL)` — 直後に `dmURL` へ再ロードされるため UI 上は無害
- `WebKitErrorDomain / 102 (WebKitErrorFrameLoadInterruptedByPolicyChange)` — `decidePolicyFor(.cancel)` で `WKWebView` 自身が発火する中断コード

上記に該当しない通信失敗・TLS エラー等は、引き続きオーバーレイで報告します。

### 5.2 ユーザー向け日本語化 (`userFriendlyErrorMessage(for:)`)

`Error.localizedDescription` は端末ロケールやコードによっては英語で返るため、代表的な `NSURLErrorDomain` コードを日本語メッセージへ寄せています。マッピング一覧は README の「ユーザー向けエラーメッセージのマッピング」節を一次情報とし、境界は `InstaDirectOnlyTests/InstagramWebViewURLPolicyTests.swift` の `test_userFriendlyErrorMessage_*` 群で回帰しています。

### 5.3 プログレスバーの KVO ライフサイクル

上部プログレスバーは `WKWebView.estimatedProgress` を `NSKeyValueObservation` で観測し、メインスレッドで `@Binding var loadProgress` を更新します。オブザーバは `Coordinator.deinit` で必ず `invalidate()` されるため、View が破棄されても購読リークは発生しません。

### 5.4 再試行ボタン

エラーオーバーレイの「再試行」は、閲覧位置を可能な限り保ちます。

- `webView.url != nil` → `WKWebView.reload()` で **そのページを再試行**（個別 DM スレッドから離脱しない）。
- `webView.url == nil` → 初回ロードが URL コミット前に失敗したケース。フォールバックとして `dmURL` (`/direct/inbox/`) をロード。

## 6. テスト戦略

現状のユニットテストは `InstaDirectOnlyTests/InstagramWebViewURLPolicyTests.swift` に集約されており、次を回帰します。

- `isAllowedURL` の境界（スキーム / ホスト / パス / トラバーサル / 大文字小文字 / userinfo / ポート / クエリ / フラグメント / lookalike ドメイン）
- `mobileSafariUserAgent` のフォーマット（`iPhone` / `Mobile/` / `Safari/` / `AppleWebKit/` / `Mozilla/5.0` プレフィクス、制御文字なし）
- `userFriendlyErrorMessage(for:)` のドメイン × コード全ケース

`isAllowedURL` を `static` にしていることで、テストは WebView を起動せずに文字列だけで完結します。ネットワークや実 `WKWebView` を用意する必要はありません。

> **重要**: 現時点でこのファイルは `InstaDirectOnly.xcodeproj` に **テストターゲットとして登録されていません**。チェックアウト直後に `⌘U` を押しても実行されないため、README の「テストターゲットを追加して実行する」節の手順で一度だけ設定してください。CI 化する場合もこの前提を踏まえて構成する必要があります。

## 7. 拡張ポイント（変更箇所チェックリスト）

新しい機能・修正を入れる際は、対象のレイヤに応じて以下の場所をまとめて更新してください。片方だけを更新すると挙動とテスト、あるいは実装とドキュメントが乖離します。

### 7.1 新しい URL を allowlist に追加する

- `InstagramWebView.isAllowedURL` のホスト／パス allowlist を更新
- `InstagramWebViewURLPolicyTests` に該当 URL の許可／不許可ケースを追加
- README の「URL ポリシー」節と本ドキュメント §3 のセレクタ表現を必要に応じて更新
- パストラバーサル（`..` / `.`）が絡む場合は §3.1 の 4. のロジックが有効なままかを再確認

### 7.2 新しいエラーコードのユーザー向け日本語化

- `InstagramWebView.userFriendlyErrorMessage(for:)` にケースを追加
- `InstagramWebViewURLPolicyTests` の `test_userFriendlyErrorMessage_*` に境界を追加
- README のマッピング表を更新
- そのエラーを「正常系」として扱いたい場合は `isIgnorableNavigationError` にも追加

### 7.3 新しい CSS 非表示ルール

- `InstagramWebView.hideUnwantedUICSS` にセレクタを追加
- `injectStyleJS` の固定 ID (`idoa-injected-style`) 重複ガードを壊さないか確認
- README の「フィード・不要 UI の非表示」節を必要に応じて更新
- Instagram 側のマークアップ依存であることをコメント／PR 本文に明記

### 7.4 iOS ターゲット・UA の引き上げ

- `InstagramWebView.mobileSafariUserAgent` を更新（`static let` なのでこの 1 箇所のみ）
- `InstagramWebViewURLPolicyTests` の UA フォーマット検査が通ることを確認
- README「技術スタック」「User-Agent」節を更新
- 最小 iOS を上げる場合は `CONTRIBUTING.md` と `README.md`（ビルド節）を同時に更新
