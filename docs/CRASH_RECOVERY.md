# Web Content Process クラッシュ復帰

このドキュメントは `InstagramWebView.Coordinator.webViewWebContentProcessDidTerminate(_:)` を中心とする「Web Content Process クラッシュ自動復帰」機構の設計と運用ノートです。ユーザー向けの操作説明は [`README.md`](../README.md) に、全体の構造は [`ARCHITECTURE.md`](./ARCHITECTURE.md) に、`isAllowedURL` の詳細は README の「URL ポリシー」節にそれぞれ集約しています。ここでは「なぜクラッシュ復帰が必要なのか」「復帰先はどう決まるのか」「なぜレート制限が要るのか」に焦点を当てます。

本ドキュメントは実装（`InstaDirectOnly/InstagramWebView.swift`）に対する概念モデルです。個別 API のシグネチャや細かな挙動はソースを一次情報とし、両者に差分が出た場合はコード側を正としてください。

## 1. 背景 — WKWebView とマルチプロセスアーキテクチャ

`WKWebView` は UI プロセスとは別の **Web Content Process** でウェブページのレンダリングと JavaScript 実行を行います。この分離により、ページの暴走やクラッシュがアプリ本体を巻き込むことは防がれますが、副作用として **Web Content Process だけが単独で終了する** ケースがあり得ます。

Web Content Process が終了する典型的な要因：

- OS からのメモリプレッシャー（バックグラウンド滞留中の jetsam 等）
- 特定ページの JavaScript / WebAssembly が起こす致命エラー
- WebKit 側のバグ

何もしないと、`WKWebView` は **空の白ビュー** としてユーザに残ります（操作は受け付けるが表示は空）。Apple 公式ドキュメントもこの状況を「デリゲートで検知して再ロードすべき」と案内しており、本アプリでは `WKNavigationDelegate.webViewWebContentProcessDidTerminate(_:)` にフックして自動復帰を行います。

## 2. 復帰先 URL の決定

自動復帰のロジックはテスト容易性のために純関数として切り出され、`InstagramWebView.urlToReloadAfterContentProcessTermination(currentURL:)` に集約されています。

判定手順：

1. クラッシュ直前の `WKWebView.url` を取得する。
2. その URL が `isAllowedURL(_:)` の allowlist を満たす場合 → **その URL をリロード**（例: 個別 DM スレッド `/direct/t/<id>/` を閲覧中のクラッシュから、同じスレッド位置に復帰）。
3. URL が nil、または allowlist を満たさない場合 → **DM 受信箱 (`dmURL`) にフォールバック**。

`isAllowedURL` を経由することで、クラッシュ直前に何らかの理由で許可外 URL が `webView.url` に残っていたとしても、復帰後に許可外ページを表示することはありません（deny-by-default の一貫性）。

```
[Web Content Process 終了]
        │
        ▼
webViewWebContentProcessDidTerminate(_:)
        │
        ▼
urlToReloadAfterContentProcessTermination(currentURL: webView.url)
        │
   ┌────┴────┐
   ▼         ▼
[allowed]  [nil / disallowed]
   │         │
   ▼         ▼
その URL   dmURL
```

## 3. レート制限 — 無限ループの回避

自動復帰は「1 回で成功する」前提のロジックではありません。ロードしたページが **再びクラッシュを誘発する** 状況（例: 特定の DM スレッドが常時 OOM を起こす、特定のメディアが WebKit を落とす）では、素朴に復帰を試みると `ロード → クラッシュ → ロード → クラッシュ` の無限ループになり、CPU / ネットワーク / バッテリーを消耗します。

これを防ぐために、`Coordinator` は直近のクラッシュタイムスタンプを `crashRecoveryTimestamps` として保持し、時間ウィンドウ内の件数がしきい値を超えた場合は自動復帰を停止します。停止時はエラーオーバーレイに `crashRecoveryGiveUpMessage` を表示し、ユーザに手動での再試行を委ねます。

判定は次の 2 つの `static` ヘルパーで行われ、時刻を引数として渡す設計なのでテストから時計を注入して検証できます。

- `recentCrashTimestamps(_:now:window:)` — `timestamps` のうち `now` から `window` 秒以内のものだけを残す。
- `shouldStopAutoRecovery(timestamps:now:window:maxAttempts:)` — 直近ウィンドウ内の件数が `maxAttempts` を超えていれば `true`。

現状の既定値：

| 定数 | 既定値 | 意味 |
|---|---|---|
| `crashRecoveryWindow` | 30 秒 | この期間内のクラッシュ回数で自動復帰の停止可否を判定 |
| `crashRecoveryMaxAttempts` | 3 回 | ウィンドウ内で自動復帰する上限（超過で停止） |
| `crashRecoveryGiveUpMessage` | 「Web Content Process が短時間で繰り返し終了しました。再試行ボタンで再読み込みしてください。」 | 停止時にエラーオーバーレイへ表示する日本語文言 |

しきい値を「時間ウィンドウ内の件数」で定義しているのは、単純な累積回数だと「長時間の稼働で偶発的なクラッシュが 4 回起きただけで自動復帰が止まる」ような誤検知を招くためです。連続してクラッシュしている状況だけを狙って停止させる意図でこの設計を採用しています。

## 4. 手動再試行との相互作用

エラーオーバーレイの「再試行」ボタンは `ContentView.reload()` から `Coordinator.resetCrashRecoveryState()` を呼び、`crashRecoveryTimestamps` をクリアしてから再ロードを行います。

これがない場合、以下のシーケンスで **ユーザ操作直後に即座に「自動復帰停止」に戻ってしまう** リグレッションが起きます。

```
1. ウィンドウ内で 4 回連続クラッシュ → 自動復帰停止 (crashRecoveryGiveUpMessage 表示)
2. ユーザ「再試行」タップ → reload()
3. その直後にまたクラッシュ (5 回目)
4. 過去 4 件のタイムスタンプがまだ残っているため、shouldStopAutoRecovery = true
5. 一切の自動復帰を試みずに再度エラー表示（ユーザ視点では「再試行しても何も起きない」）
```

`resetCrashRecoveryState()` はこの状況を解消し、手動再試行の後に **改めて `crashRecoveryWindow` 内で `crashRecoveryMaxAttempts` 回まで自動復帰するチャンス** を確保します。

## 5. エラーオーバーレイの状態遷移

`isLoading` と `loadError` の 2 つの `@Binding` を通じて、`ContentView` は次の状態を表示します。

| 状況 | `isLoading` | `loadError` | 表示 |
|---|---|---|---|
| クラッシュ検知直後（自動復帰試行） | false → true | nil | 中央スピナー・上部プログレスバー |
| 自動復帰成功 | false | nil | 通常の DM 画面 |
| 自動復帰停止（レート制限） | false | `crashRecoveryGiveUpMessage` | エラーオーバーレイ（`再試行` ボタン付き） |
| 手動再試行後、再ロード中 | true | nil | 中央スピナー |

`webViewWebContentProcessDidTerminate(_:)` の実装は自動復帰前に `parent.loadError = nil` を明示的に代入し、以前のエラーオーバーレイの残骸が新しい復帰試行の裏に残らないようにしています。停止時のみ `parent.loadError = crashRecoveryGiveUpMessage` を代入してオーバーレイを再表示します。

## 6. `isIgnorableNavigationError` との棲み分け

クラッシュ復帰は `WKNavigationDelegate` の失敗コールバック（`didFail` / `didFailProvisionalNavigation`）とは **別経路** で起きるイベントです。両者は次のように棲み分けています。

- `WKNavigationDelegate` の失敗コールバック → ネットワーク・TLS・ポリシーキャンセル起因のエラー。`isIgnorableNavigationError(_:)` で正常系（`NSURLErrorCancelled` / `WebKitErrorDomain 101, 102`）を除外し、残りを `userFriendlyErrorMessage(for:)` で日本語化してオーバーレイに出す。
- `webViewWebContentProcessDidTerminate(_:)` → プロセス自体が終了したケース。上記の失敗コールバックは呼ばれないため、専用の自動復帰＋レート制限ロジックで処理する。

このため、クラッシュ復帰の実装が変わっても `isIgnorableNavigationError` 側は影響を受けません（詳細は [`ARCHITECTURE.md` §5.1](./ARCHITECTURE.md#51-正常系除外-isignorablenavigationerror) を参照）。

## 7. テスト戦略

クラッシュ復帰関連の純関数はすべて `static` メソッドとして切り出しているため、`WKWebView` を実体化せずにユニットテストできます。テストで検証すべき境界の代表：

- `urlToReloadAfterContentProcessTermination(currentURL:)`
  - `nil` を渡すと `dmURL` を返す
  - `isAllowedURL` を満たす URL（例: `/direct/inbox/`, `/direct/t/<id>/`, `/accounts/login`）を渡すとその URL を返す
  - 許可外 URL（例: `/explore/`）を渡すと `dmURL` を返す
- `recentCrashTimestamps(_:now:window:)`
  - ウィンドウ境界（`window` 秒ちょうどは除外）
  - 空配列は空配列
- `shouldStopAutoRecovery(timestamps:now:window:maxAttempts:)`
  - `maxAttempts` 回ジャストでは停止しない
  - `maxAttempts + 1` 回で停止する
  - ウィンドウ外の古いタイムスタンプはカウントされない

`Coordinator.crashRecoveryTimestamps` を `internal` に公開しているのは、`@testable import` からリセット後の状態を観測してリグレッションを検知するためです（`resetCrashRecoveryState()` の呼び出し後に配列が空になることを保証）。

## 8. 拡張ポイント（変更箇所チェックリスト）

クラッシュ復帰の挙動を変更するときは以下を同時に更新してください。片方だけを触ると挙動・テスト・ドキュメントが乖離します。

### 8.1 しきい値・時間ウィンドウの調整

- `InstagramWebView.crashRecoveryWindow` / `crashRecoveryMaxAttempts` を更新
- 対応するユニットテストの境界ケースを更新（`shouldStopAutoRecovery` の +1 / -1 境界）
- 本ドキュメントの §3 の表の既定値を更新

### 8.2 復帰先 URL のロジック変更

- `InstagramWebView.urlToReloadAfterContentProcessTermination(currentURL:)` を更新
- `isAllowedURL` の変更が絡む場合は [`ARCHITECTURE.md` §3](./ARCHITECTURE.md#3-url-ポリシー層) と README の「URL ポリシー」節も同期
- テストに新しい入力パターン（例: `/challenge/*` からの復帰）を追加

### 8.3 停止時ユーザメッセージの変更

- `InstagramWebView.crashRecoveryGiveUpMessage` を更新
- 本ドキュメント §3 の表と §5 の状態遷移表を更新
- 端末ロケール英語の場合の扱い（`userFriendlyErrorMessage` とは独立してハードコード）に注意
