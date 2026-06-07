# InstaDirectOnly

Instagram のダイレクトメッセージ（DM）機能だけを使うためのシンプルな iOS アプリ。フィード・リール・発見タブ・ショッピング誘導など、DM 以外のすべての導線をブロックし、メッセージのやり取りに集中できる UI を提供します。

## 特徴

- **DM だけにアクセス**: 起動と同時に `https://www.instagram.com/direct/inbox/` を開く
- **フィード非表示**: 下部ナビゲーションバーやアプリ誘導バナーを CSS で隠す
- **遷移ガード**: 許可リスト以外の URL は読み込みをキャンセルし、DM 画面へ戻る
- **ログイン維持**: WebKit の標準データストアで Cookie を永続化（独自サーバは介在しない）
- **エラー時の再試行**: ネットワーク失敗時はメッセージと再試行ボタンを表示

## 技術スタック

- Swift / SwiftUI
- `WKWebView`（`WebKit`）
- iOS 17+

## ビルド

1. `Xcode 15` 以降で `InstaDirectOnly.xcodeproj` を開く
2. 実機または iOS 17 シミュレータをターゲットに選択
3. ⌘R で起動

## テストの実行

`InstaDirectOnlyTests/InstagramWebViewURLPolicyTests.swift` に、URL allowlist（`InstagramWebView.isAllowedURL`）の境界条件を網羅したユニットテストが含まれています。スキームの allowlist、ホスト/パスの完全一致・サブドメイン判定、偽装ホスト（userinfo・lookalike ドメイン）の拒否、大文字小文字やポート・クエリ・フラグメントの正規化などを検証します。

> **注意**: 現状このテストファイルは `InstaDirectOnly.xcodeproj` に **テストターゲットとして登録されていません**。そのため、チェックアウト直後に `⌘U` を押してもテストは実行されません。下記の手順で一度だけテストターゲットを追加してください。

### テストターゲットを追加して実行する

1. Xcode で `InstaDirectOnly.xcodeproj` を開く。
2. メニューの **File ▸ New ▸ Target…** から **Unit Testing Bundle** を選択して追加する（Product Name を `InstaDirectOnlyTests`、Target to be Tested を `InstaDirectOnly` に設定）。
3. 自動生成されたサンプルテストファイルは削除し、既存の `InstaDirectOnlyTests/InstagramWebViewURLPolicyTests.swift` をそのテストターゲットの Target Membership に含める（ファイルインスペクタの「Target Membership」で新規テストターゲットにチェック）。
4. テストはホストアプリのシンボルへ `@testable import InstaDirectOnly` でアクセスするため、テストターゲットの **Host Application** が `InstaDirectOnly` になっていることを確認する。
5. `⌘U`（Product ▸ Test）でテストを実行する。

> 補足: `isAllowedURL` は `static` メソッドなので、テストは UI を起動せずに URL 文字列を渡して判定結果のみを検証します（ネットワークや WebView の実体は不要）。新しい allowlist のルールを追加・変更した際は、このテストに対応するケースを追加してください。

## アーキテクチャ

| ファイル | 役割 |
|---------|------|
| `InstaDirectOnly/InstaDirectOnlyApp.swift` | アプリのエントリポイント |
| `InstaDirectOnly/ContentView.swift` | ローディング・エラーオーバーレイを含むルートビュー |
| `InstaDirectOnly/InstagramWebView.swift` | `WKWebView` を SwiftUI でラップ。URL フィルタと CSS 注入を担当 |

## URL ポリシー

許可されるスキーム（**`http` / `https` のみ**。`javascript:`, `data:`, `file:`, `ftp:`, `tel:`, `mailto:`, `blob:`, `ws:` / `wss:`, `instagram://`（ネイティブアプリ用）, `intent://`（Android スタイル）, `chrome://` などは明示的に拒否）：

- `http`
- `https`
- `about:`（`about:blank` 等。`decidePolicyFor` 側で別途許可）

スキーム allowlist が無いと、`javascript://www.instagram.com/direct/` のようにホスト位置に既知ドメイン文字列を埋め込んだ細工 URL で `url.host` が "www.instagram.com" を返し、ホスト/パスチェックを通過しうるためブロックしています。スキーム判定では大文字小文字を正規化（`HTTPS://` / `HtTpS://` も `https` と等価扱い）してから allowlist と照合しています。

**役割分担**: 純粋な静的判定 `isAllowedURL` は `http` / `https` のみを通すため `about:blank` も `false` を返します。一方 `WKNavigationDelegate.decidePolicyFor` では `about:blank` を初期化フローや iframe 用途として明示的に許可します。テストは前者の境界を回帰します。

許可されるホスト（**完全一致もしくはサブドメインのみ**。`host.contains(...)` のような部分一致は使わない）：

- `instagram.com` および `*.instagram.com`（パス制限あり）
- `cdninstagram.com`, `fbcdn.net`, `facebook.com`, `fbsbx.com` および各サブドメイン（CDN/認証）

これにより `evil-instagram.com.attacker.example` のような偽装ホストはブロックされます。

Instagram ドメイン内で許可されるパス（**完全一致もしくは `target/` で始まるもののみ**。`/directfake` のような prefix の取りこぼしを防ぐ）：

- `/direct`, `/direct/*`（DM）
- `/accounts/login`, `/accounts/onetap`, `/accounts/emailsignup`（ログイン）
- `/accounts/logout`, `/accounts/logout/*`（ログアウト導線・`/accounts/logout/ajax/` 等の POST も含む）
- `/challenge`, `/challenge/*`（本人確認）
- `/api/v1`, `/api/v1/*`, `/oauth`, `/oauth/*`（内部 API）
- `/`（リダイレクト中継）

上記以外への遷移は WebView のレベルで `decisionHandler(.cancel)` され、初期ロード完了後であれば自動的に DM 画面へ戻ります。

URL ポリシーの境界条件は `InstaDirectOnlyTests/InstagramWebViewURLPolicyTests.swift` にユニットテストとして文書化しています（Xcode のテストターゲット追加が必要）。

## 新規ウィンドウ（target="_blank" / window.open）の扱い

`WKWebView` は `WKUIDelegate` 未実装のままだと、`target="_blank"` や `window.open` で開かれるリンクをタップしても **何も起こらない（silent fail）**。
本アプリは `Coordinator` を `WKUIDelegate` に準拠させ、新規ウィンドウ要求が来た際に以下のように振る舞います：

- URL allowlist を満たす場合 → **同じ `WKWebView` 上でロード**（DM 内のリンクが消えず辿れる）
- 許可外 URL の場合 → **何もしない**（外部ブラウザを開かない＝ DM 外への離脱導線を作らない）

これにより無反応に見える挙動を解消しつつ、URL ポリシーは維持されます。

## エラーハンドリング

`WKNavigationDelegate` の失敗コールバックでエラーメッセージを SwiftUI 側にバインドし、半透明オーバーレイとして表示します。`NSURLErrorCancelled`（許可外 URL ブロックや戻る操作によるキャンセル）はエラーとして扱いません。

### 読み込み進捗の表示

画面最上部に、`WKWebView.estimatedProgress`（0.0〜1.0）を反映する **薄いリニアプログレスバー** を表示します。Safari の URL バー下に出るような細い進捗バーで、「いつ終わりそうか」がひと目で分かるようにするための UX 改善です。

- 進捗観測は `Coordinator` が `NSKeyValueObservation` で `webView.estimatedProgress` を監視し、メインスレッドで `@Binding var loadProgress` を更新します。観測トークンは `Coordinator.deinit` で必ず `invalidate()` されます。
- バーは `isLoading && loadProgress < 1.0` の間だけ表示し、ロード完了の瞬間に消えます。
- 中央の不確定スピナーは初回ロードの存在感を保つためそのまま併用しています。

### 再試行ボタンの挙動

エラーオーバーレイの「再試行」ボタンは、ユーザーが閲覧していた位置をできるだけ保つように動作します。

- 既に何らかのページがロード済みの場合 → `WKWebView.reload()` で **そのページを再試行** します。個別 DM スレッド (`/direct/t/...`) 閲覧中の一時的なネットワーク失敗から、同じスレッドへ戻れます。
- 初回ロードが URL コミット前に失敗した場合 (`webView.url == nil`) → フォールバックとして DM 受信箱 (`/direct/inbox/`) をロードします。

VoiceOver では `ProgressView` に「読み込み中」、エラーオーバーレイ全体に「読み込みに失敗しました」、再試行ボタンに「再試行」ラベルとヒントが設定されています。

## フィード・不要 UI の非表示（CSS 注入）

DM への遷移を URL ポリシーでガードする一方、DM 画面そのものに表示される「DM 以外への導線」は CSS で視覚的に隠します。実装上のポイントは次の通りです。

- **実行タイミング**: `WKUserScript(.atDocumentStart)` で `WKUserContentController` に登録した JS が、ドキュメント生成直後（初回レイアウト前）に `<style>` 要素を `document.head`（無ければ `document.documentElement`）へ追加します。これにより、フィードナビゲーションバー・アプリ誘導バナーは最初から非表示の状態で描画されます。
- **SPA 遷移のフォールバック**: Instagram は History API による soft navigation を多用するため、document が再生成されず `.atDocumentStart` が再発火しない場合があります。`WKNavigationDelegate.didFinish` でも同じ JS を `evaluateJavaScript` で再実行し、SPA 遷移後にも反映されるようにします。注入する JS は固定 ID (`idoa-injected-style`) で重複追加を防ぐため、同一 document への二重注入は安全に no-op になります。
- **隠す対象**: 以下を `display: none !important` で非表示にします。
  - 下部のナビゲーション（タブ）バー: `div[role="tablist"]`、および「ホーム（`href="/"`）へのリンクを持ち DM リンクを含まない」`nav` 要素
  - アプリ誘導バナー: クラス名に `banner` / `Banner` を含む要素、App Store（`app-store` / `itunes.apple.com`）へのリンクを含む要素
- **制約**: あくまで Instagram モバイル Web 版の現行 DOM 構造・クラス名に依存したセレクタです。Instagram 側のマークアップ変更により、隠しきれない要素が現れたり、逆に意図しない要素が隠れたりする可能性があります。これは URL ポリシーのような「ブロック」ではなく、視覚的な整理であることに注意してください（遷移自体は URL ポリシーで別途防いでいます）。

CSS 本体は `InstagramWebView.swift` の `hideUnwantedUICSS` 定数、注入用 JS は `injectStyleJS` 定数にまとまっています。

## トラブルシューティング（FAQ）

- **DM 以外の UI（タブバーやバナー）が一瞬／一部表示される**
  CSS は `WKUserScript(.atDocumentStart)` でドキュメント生成直後に注入されるため、初回レイアウト前にルールが適用されます。とはいえ Instagram 側のレンダリング戦略（クライアントサイドで動的生成されるツリー等）によっては、ごく短時間だけ要素が見える場合があります。また上記「制約」の通り、Instagram の DOM 変更でセレクタが追従できていない場合は隠れないことがあります。いずれも遷移そのものは URL ポリシーでブロックされるため、DM 以外の画面へ実際に移動することはありません。

- **タップしても何も起こらない／DM 画面に戻される**
  許可リスト外の URL（フィード・発見タブ・ショッピング等）は仕様としてブロックしています。初期ロード完了後であれば自動的に DM 画面へ戻ります。詳細は「URL ポリシー」を参照してください。

- **リンク（`target="_blank"` で開くもの）が無反応**
  許可リストを満たすリンクは同じ画面内で開きます。許可外 URL は外部ブラウザを開かず何もしません（DM 外への離脱導線を作らないため）。詳細は「新規ウィンドウの扱い」を参照してください。

- **ログインできない／セッションがすぐ切れる**
  本アプリは Apple 標準の WebKit データストア（`.default()`）で Cookie を永続化するだけで、独自のセッション管理は行いません。本人確認（`/challenge`）やログイン（`/accounts/login` 等）は許可リストに含まれています。それでも繰り返しログインを求められる場合は、端末側のコンテンツブロッカーや、Instagram 側の追加認証フローが原因のことがあります。

- **「読み込みに失敗しました」と表示される**
  ネットワークエラー時に表示されるオーバーレイです。接続を確認して「再試行」をタップすると DM 画面を再読み込みします。許可外 URL のブロックや戻る操作によるキャンセルはエラー扱いしないため、この画面は表示されません。

## プライバシー

- 独自バックエンドや解析サービスを一切経由しません
- セッション情報は Apple が提供する標準の Cookie 永続化のみで保持されます
- アプリは Instagram のモバイル Web 版を `WKWebView` で表示しているだけです

## ライセンス

このリポジトリのコードについてはリポジトリオーナーの設定に従います。Instagram の利用規約・コンテンツポリシーには各自で従ってください。
