# ドキュメント（`docs/`）インデックス

このディレクトリには、リポジトリルート [`README.md`](../README.md) では触れきれない実装・運用の詳細ドキュメントを配置しています。用途別の入口として、以下から関心のあるドキュメントを開いてください。

## 目的別インデックス

### 全体像を把握したい

- **[ARCHITECTURE.md](./ARCHITECTURE.md)** — アプリの構成要素（`InstaDirectOnlyApp` / `ContentView` / `InstagramWebView`）と、それぞれの責務・依存関係・イベントフローを図と共に整理したドキュメント。「どこを触るとどこに影響するか」を掴みたい時の起点。
- **[GLOSSARY.md](./GLOSSARY.md)** — このリポジトリで頻出する用語（URL allowlist・スキームチェック・SPA soft navigation・`WKUserScript(.atDocumentStart)` など）の定義集。README や他ドキュメントを読む際の副読本として。

### 動作の詳細を知りたい

- **[CRASH_RECOVERY.md](./CRASH_RECOVERY.md)** — `WKWebView` のコンテンツプロセスがクラッシュした際の自動復帰ロジック（試行回数・時間ウィンドウ・ユーザ手動再試行時のリセット挙動）を仕様レベルでまとめたもの。`Coordinator.resetCrashRecoveryState()` の意図を追う時に参照。
- **[TESTING.md](./TESTING.md)** — `InstaDirectOnlyTests/` 配下のユニットテストの構成、Xcode プロジェクトへのテストターゲット追加手順、テストが検証している境界条件の概要。

### 使い方・困った時

- **[FAQ.md](./FAQ.md)** — 「なぜ通知が届かないのか」「Cookie はどこに保存されるか」など、ユーザ・利用者側の視点でよく問い合わせられる質問への回答集。
- **[TROUBLESHOOTING.md](./TROUBLESHOOTING.md)** — 「ログインループになる」「一部の UI が隠れきらない」など、開発者・運用者側の視点で発生しがちな不具合と切り分け手順。

## その他のリファレンス

- リポジトリルート [`README.md`](../README.md) — 特徴・技術スタック・URL ポリシー・エラーハンドリング・CSS 注入戦略などの一次情報
- [`CHANGELOG.md`](../CHANGELOG.md) — 各バージョンで加えた変更のサマリ
- [`CONTRIBUTING.md`](../CONTRIBUTING.md) — コントリビュート時のブランチ運用・コミット規則
- [`SECURITY.md`](../SECURITY.md) — 脆弱性報告手順
- [`CODE_OF_CONDUCT.md`](../CODE_OF_CONDUCT.md) — コミュニティの行動規範

## ドキュメントを追加・更新する時のガイド

- 新しく `docs/` にドキュメントを追加した場合は、本ファイルの該当セクション（全体像 / 動作の詳細 / 使い方）に 1〜2 行の説明と共にエントリを追加してください。
- リンクは可能な限り **リポジトリ内相対パス** で書いてください。CI の `link-check` ワークフローが `**/*.md` を対象に URL 生存性を検査しており、外部リンクは 403/429 を返しがちなドメインを持つと運用コストが増えます。
- ドキュメント本文の記述スタイル（見出しレベル・箇条書き・注記の書式）は既存ドキュメントに合わせてください（README.md の書式が事実上のリファレンス）。
