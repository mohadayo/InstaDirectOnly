# 用語集 (Glossary)

このドキュメントは InstaDirectOnly のコード・PR・Issue で使われる用語を統一的に定義するための参照です。表記ゆれを減らし、新規コントリビュータのオンボーディングを速やかにすることを目的としています。

各エントリは「**用語** — 定義 — 関連ドキュメント / コードパス」形式で記載しています。

---

## 1. ドメイン用語 (Instagram DM の概念)

- **DM (Direct Message)** — Instagram のダイレクトメッセージ機能そのもの。本アプリはこの DM 画面のみを利用可能にすることを目的としている。表記は "DM" に統一する（"ダイレクトメッセージ" / "ダイレクト" 等は使わない）。
- **スレッド (Thread)** — 特定の相手または特定のグループとの 1 対 1 / N の会話単位。DM 一覧の各行に対応する。
- **受信箱 (Inbox)** — DM のスレッド一覧画面。
- **リクエスト (Message Request)** — フォロー関係にないユーザからの DM を承認前に格納しておく領域。受信箱とは別に扱われる。
- **既読 (Seen)** — 相手が自分の送信メッセージを閲覧したことを示す状態。
- **タイピング表示 (Typing Indicator)** — 相手が入力中であることを示すインジケータ。
- **反応 (Reaction)** — メッセージへの絵文字リアクション。
- **メンション (Mention)** — メッセージ内で `@username` によって他ユーザを言及する行為。

## 2. アプリ固有の用語 (InstaDirectOnly が導入した概念)

- **Direct Only モード** — Instagram の他機能（フィード・ストーリーズ・リール等）を隠し、DM 機能のみに操作を絞るこのアプリの中核モード。アプリ名 "InstaDirectOnly" の由来。
- **キーボード下方スワイプ** — DM 画面のメッセージ入力キーボードを下方向のドラッグ操作で閉じられるジェスチャ（PR #122 参照）。iOS の "interactive dismiss" 挙動を DM 画面向けにチューニングしたもの。
- **タブレット向けレイアウト** — iPad で 2 ペイン（受信箱 + スレッド）を横並びに表示するレイアウト。iPhone では単一ペインとなる。
- **ユーザフレンドリーエラーメッセージ** — WebKit の低レベルエラーコードを利用者向けに翻訳した文字列。`userFriendlyErrorMessage` 関数で生成する（PR #112 参照）。

## 3. iOS / WebKit 実装用語

- **WKWebView** — Apple 提供の WebKit ベースの Web ビュー。本アプリは Instagram の Web 版 DM を WKWebView で読み込んで動作する。
- **Web Content Process** — WKWebView が Web コンテンツを描画・スクリプト実行するために使うサブプロセス。メインアプリプロセスとはメモリ空間が分離されており、単独でクラッシュし得る。
- **クラッシュ復帰 (Crash Recovery)** — Web Content Process がクラッシュした際にアプリを終了させず、状態を保存してから WKWebView を再ロードして復帰させる仕組み。詳細は [`docs/CRASH_RECOVERY.md`](./CRASH_RECOVERY.md) を参照。
- **Content Rules / Content Blocker** — WKWebView に対して特定 URL / リソースの読み込みをブロックするルール。Direct Only モードで DM 以外の Instagram 機能への遷移を遮断するために利用する。
- **User Script** — WKWebView にページロード時に自動注入する JavaScript。UI カスタマイズや不要要素の非表示に利用する。
- **Navigation Delegate** — WKWebView のナビゲーション（URL 遷移）を横取り・許可判定するためのデリゲート。DM 外遷移の抑止に利用する。
- **Cookie / WKHTTPCookieStore** — Instagram のログインセッションを保持するための Cookie ストア。ログイン状態を維持したまま WKWebView を再生成する際に参照する。

## 4. 開発プロセス用語

- **Web Content Process クラッシュ復帰の設計** — 上記 "クラッシュ復帰" の実装方針を文書化したもの。[`docs/CRASH_RECOVERY.md`](./CRASH_RECOVERY.md) を参照 (PR #126)。
- **テスト方針 (Testing Policy)** — 本リポジトリで採用しているユニットテスト / UI テストの方針。[`docs/TESTING.md`](./TESTING.md) を参照 (PR #124)。
- **アーキテクチャ (Architecture)** — アプリ全体の構造と主要コンポーネントの関係。[`docs/ARCHITECTURE.md`](./ARCHITECTURE.md) を参照 (PR #114)。
- **stale ワークフロー** — 長期未更新の Issue / PR を自動的にラベル付け・クローズする GitHub Actions ワークフロー (PR #110)。

---

## 表記ルール

- 英語の技術用語は初出時に「日本語訳 (英語)」の形で併記する（例: "既読 (Seen)"）。以降は日本語表記に統一する。
- アプリ固有の造語（Direct Only モード等）は日本語文中でも英語表記のまま用いる。
- iOS SDK の API 名（`WKWebView` 等）はコードフォント（バッククォート）で囲む。

## 更新方針

- 新しい概念を導入する PR は、その PR 内で本ファイルへの追記を推奨する。
- 用語の重複・矛盾を発見した場合は Issue を立てて統合を提案する。
