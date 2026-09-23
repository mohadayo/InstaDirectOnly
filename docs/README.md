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

### リリース・運用

- **[RELEASE.md](./RELEASE.md)** — 次のバージョンを切る際の手順（SemVer に基づくバージョン採番、`CHANGELOG.md` の `[Unreleased]` → 新バージョン節への書き換え、Xcode `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` の bump、注釈付き Git タグ、GitHub Releases 作成、ホットフィックス / ロールバック時の考え方）を一次情報として集約。
- **[DEV_COMMANDS.md](./DEV_COMMANDS.md)** — リポジトリ直下 [`Makefile`](../Makefile) が提供する `build` / `test` / `lint` / `format` / `setup` などの開発タスクと上書き可能な変数（`DESTINATION` / `CONFIG` など）を表形式でまとめた開発コマンドリファレンス。初回セットアップ〜 PR 前チェックまでの典型ワークフローも掲載。
- **[CI.md](./CI.md)** — [`.github/workflows/`](../.github/workflows) 配下の GitHub Actions ワークフロー（`actionlint` / `link-check` / `stale`）について、目的・トリガー・権限・失敗時の対処を横断的にまとめた一次リファレンス。新規ワークフローを追加する際のガイドも掲載。

### 方針・ロードマップ

- **[ROADMAP.md](./ROADMAP.md)** — 「独自バックエンドを持たない」「DM だけに集中する」「URL allowlist は deny-by-default」といった **設計原則** と、それに基づく短期 (Now) / 中期 (Next) / 長期 (Later) の取り組み、そして **明示的にスコープ外とする項目**（独自バックエンド導入・非 DM 機能の追加・ネイティブ再実装など）を一次リファレンスとして集約。Issue / PR で散在しがちなスコープ判断の根拠を後から辿れる形にまとめている。

## その他のリファレンス

- リポジトリルート [`README.md`](../README.md) — 特徴・技術スタック・URL ポリシー・エラーハンドリング・CSS 注入戦略などの一次情報
- [`CHANGELOG.md`](../CHANGELOG.md) — 各バージョンで加えた変更のサマリ
- [`CONTRIBUTING.md`](../CONTRIBUTING.md) — コントリビュート時のブランチ運用・コミット規則
- [`SECURITY.md`](../SECURITY.md) — 脆弱性報告手順
- [`CODE_OF_CONDUCT.md`](../CODE_OF_CONDUCT.md) — コミュニティの行動規範

## ドキュメントを追加・更新する時のガイド

- 新しく `docs/` にドキュメントを追加した場合は、本ファイルの該当セクション（全体像 / 動作の詳細 / 使い方 / リリース・運用 / 方針・ロードマップ）に 1〜2 行の説明と共にエントリを追加してください。
- リンクは可能な限り **リポジトリ内相対パス** で書いてください。CI の `link-check` ワークフローが `**/*.md` を対象に URL 生存性を検査しており、外部リンクは 403/429 を返しがちなドメインを持つと運用コストが増えます。
- ドキュメント本文の記述スタイル（見出しレベル・箇条書き・注記の書式）は既存ドキュメントに合わせてください（README.md の書式が事実上のリファレンス）。
