# `.github/` 配下のメタファイルリファレンス（`docs/GITHUB_META_FILES.md`）

このドキュメントは、リポジトリ `.github/` 配下に配置されている **ワークフロー以外のメタファイル群** について、**目的・効果の及ぶ範囲・連動するツール/ワークフロー・編集時の注意点** を一次リファレンスとしてまとめたものです。各ファイル先頭のコメントは単体で意味を持つように書かれていますが、「どれがどの機能と連動しているのか」を横断的に俯瞰する入口として本ドキュメントを利用してください。

- 対象読者: 初めて貢献するコントリビュータ / `.github/` 配下のファイルを編集する前に影響範囲を確認したい開発者
- 関連: [`CONTRIBUTING.md`](../CONTRIBUTING.md)（コントリビュート手順）、[`docs/CI.md`](./CI.md)（`.github/workflows/` のワークフロー）、[`docs/CONFIG_FILES.md`](./CONFIG_FILES.md)（リポジトリ直下のドットファイル）

> `.github/workflows/` 配下の個々のワークフロー（`actionlint` / `link-check` / `markdownlint` / `typos` / `stale` / `validate-cff`）は本ドキュメントでは扱わず、[`docs/CI.md`](./CI.md) を参照してください。内容の重複を避けるためです。

## 一覧

| ファイル                                                                                   | 役割                                                                           | 効果が及ぶ範囲                                       | 連動するツール / ワークフロー                                                     |
| ------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------ | ---------------------------------------------------- | --------------------------------------------------------------------------------- |
| [`.github/CODEOWNERS`](../.github/CODEOWNERS)                                              | PR レビューの自動リクエスト先（コード所有者）定義                              | 全ファイルの PR レビュワー自動指定                   | GitHub（Protected branch の required reviewers 連携）                             |
| [`.github/PULL_REQUEST_TEMPLATE.md`](../.github/PULL_REQUEST_TEMPLATE.md)                   | PR 本文の初期テンプレート（変更概要 / 関連 Issue / 動作確認手順 など）         | PR 作成時に自動挿入される本文                        | GitHub（PR 作成画面）／[`CONTRIBUTING.md`](../CONTRIBUTING.md) の PR ガイドライン |
| [`.github/ISSUE_TEMPLATE/`](../.github/ISSUE_TEMPLATE)                                      | Issue 種別ごとのテンプレートと起票画面の設定                                   | Issue 起票画面の選択肢・初期本文                     | GitHub（Issue 作成画面）／`.github/SUPPORT.md` からのリンク                       |
| [`.github/SUPPORT.md`](../.github/SUPPORT.md)                                              | サポート窓口の案内（バグ報告・機能リクエスト・質問・脆弱性報告の導線）         | GitHub の「Support」コミュニティ導線リンク           | GitHub のコミュニティプロファイル                                                 |
| [`.github/dependabot.yml`](../.github/dependabot.yml)                                      | Dependabot による依存追跡設定（現在は `github-actions` エコシステムのみ）      | `.github/workflows/` で参照する Actions のバージョン | Dependabot ／ [`docs/CI.md`](./CI.md) の各ワークフロー                             |
| [`.github/release.yml`](../.github/release.yml)                                            | GitHub Releases 自動生成リリースノートのカテゴリ分け設定                       | 「Generate release notes」で作成される下書き         | GitHub Releases ／ [`docs/RELEASE.md`](./RELEASE.md) のリリース手順                |

## ファイル別の概要と編集時の注意点

### `.github/CODEOWNERS`

- 全ファイルのデフォルトオーナーとして `@mohadayo` を指定しており、PR 作成時にレビュワーが自動でリクエストされる。
- 後方一致でマッチした最後のルールが有効になるため、サブディレクトリに別オーナーを割り当てる場合は末尾に追加する。
- **編集時の注意**: ユーザ名の綴りミスがあっても GitHub はエラーを出さずに黙ってスキップする。追加時は GitHub のプロフィール URL で実在を確認すること。Protected branch の required reviewers と組み合わせる場合、全オーナーがレビュー可能な権限を持っている必要がある。

### `.github/PULL_REQUEST_TEMPLATE.md`

- 「変更概要 / 関連 Issue / 変更種別 / 動作確認手順 / 確認環境 / スクリーンショット / セキュリティ影響 / チェックリスト / 補足」の節構成で、PR 作成画面に自動挿入される。
- セキュリティ影響節では URL allowlist / JavaScript 実行ポリシー / Cookie の扱いなど、本プロジェクト特有の観点をチェック項目として明示している。
- **連携**: 変更種別のプレフィックス一覧は [`CONTRIBUTING.md`](../CONTRIBUTING.md) の「コミットメッセージ」節および [`.gitmessage`](../.gitmessage) と揃えている。更新する場合は 3 箇所を同時に修正すること。

### `.github/ISSUE_TEMPLATE/`

配下のファイル構成と役割:

- `bug_report.md` — バグ報告用テンプレート。再現手順・期待挙動・実際の挙動・環境情報の入力枠を提供。
- `feature_request.md` — 機能リクエスト用テンプレート。背景・提案・代替案の入力枠を提供。
- `documentation.md` — ドキュメント修正・追加の提案用テンプレート。
- `question.md` — 使い方に関する質問用テンプレート。Discussions が有効でない場合の受け口。
- `config.yml` — Issue 起票画面全体の設定。`blank_issues_enabled: false` で空 Issue を禁止し、`contact_links` でセキュリティ脆弱性報告を Security Advisory 経由に誘導する。

**編集時の注意**: テンプレートの front matter の `name` / `about` / `labels` を変更すると起票画面の表示と自動ラベル付与に影響する。既存 Issue に付与済みのラベルとの整合を確認すること。`config.yml` の `contact_links` から Security Advisory を外す運用は想定していない。

### `.github/SUPPORT.md`

- バグ報告 / 機能リクエスト / 質問 / 脆弱性報告の 4 導線を 1 ページにまとめ、GitHub のコミュニティプロファイル上の「Support」リンクとして公開される。
- バグ報告・機能リクエストは `issues/new?template=...` 形式のリンクで対応するテンプレートを直接開く。
- **連携**: 質問導線は [Discussions](../../../discussions) を優先し、無効時は `question` ラベル付き Issue にフォールバックする運用。脆弱性報告は [`SECURITY.md`](../SECURITY.md) 側に実手順があるため、本ファイルからはリンクのみ提供する。

### `.github/dependabot.yml`

- 現状の対象エコシステムは `github-actions` のみ。Swift Package Manager の依存は空のため `swift` は未登録。SPM 依存を追加した際は別途登録する運用。
- 実行間隔は `weekly`（月曜 09:00 Asia/Tokyo）。コミットプレフィックスは `chore`、ラベルは `dependencies` / `ci` を付与する。
- オープン PR 上限は 5。レビュー滞留を避けるための設定。
- **連携**: 付与される `dependencies` / `ci` ラベルは `.github/release.yml` の `Dependencies` / `CI` カテゴリに吸収され、リリースノート本体のノイズを減らす設計。片方だけ変更するとリリースノート上の分類が崩れる。

### `.github/release.yml`

- GitHub Releases 画面の「Generate release notes」で作成される下書きを、[`CHANGELOG.md`](../CHANGELOG.md) (Keep a Changelog 準拠) の見出し構造に揃えるための設定。
- カテゴリ順序は `Breaking Changes` → `Security` → `Added` → `Changed` → `Deprecated` → `Removed` → `Fixed` → `Documentation` → `Tests` → `Dependencies` → `CI` → `Other Changes`。
- `exclude.labels` に `skip-changelog` / `no-changelog` / `duplicate` / `invalid` / `wontfix` / `question` を列挙し、リリースノートに載せたくない PR を除外する。
- **連携**: 本ファイルのラベル定義は、PR に付与するラベルの運用（Conventional Commits 由来の `feat` / `fix` / `docs` / `refactor` / `test` / `chore` / `perf` 等）と揃っている。ラベル体系を変更する場合は本ファイルと Dependabot 設定を同時に見直すこと。詳細なリリース手順は [`docs/RELEASE.md`](./RELEASE.md) を参照。

## よくある質問

### Q. `.github/CODEOWNERS` に自分のユーザ名を追加したいが、どこに書けばよい？

サブディレクトリ単位でオーナーを分けたい場合は、デフォルトルール `* @mohadayo` の **後ろ** に `docs/ @alice` のように追記します。CODEOWNERS は後方一致でマッチした最後のルールが有効になるため、より限定的なルールを下に書く必要があります。全体のレビュワーを変更したい場合はデフォルトルール自体を書き換えてください。

### Q. PR テンプレートを一部スキップしたい

該当節を本文ごと削除して問題ありません。テンプレートは「初期挿入される雛形」であり、残す義務はありません。ただし「動作確認手順」「セキュリティ影響」節はレビュー観点として重視しているため、該当する変更がある PR では残すことを推奨します。

### Q. Issue テンプレートを使わずに空の Issue を作りたい

`.github/ISSUE_TEMPLATE/config.yml` で `blank_issues_enabled: false` を明示しているため、現状は空 Issue を作成できません。該当するテンプレートが無い場合は `question.md` を使用するか、テンプレート自体の追加を Issue または PR で提案してください。

### Q. Dependabot の PR をまとめたい（グループ化）

現状の `.github/dependabot.yml` ではグループ化 (`groups`) を設定していません。マイナー / パッチアップデートの PR 数が増えて負担になる場合は、`groups` キーで同一エコシステム内の更新をまとめる運用を検討してください（例: `actions-minor` のように update-types で分類）。変更時は本ドキュメントも更新してください。

## 関連ドキュメント

- [`CONTRIBUTING.md`](../CONTRIBUTING.md) — PR ガイドライン / コミットメッセージ規約（PR テンプレートと同期）
- [`docs/CI.md`](./CI.md) — `.github/workflows/` の各ワークフロー解説
- [`docs/CONFIG_FILES.md`](./CONFIG_FILES.md) — リポジトリ直下のドットファイルリファレンス
- [`docs/RELEASE.md`](./RELEASE.md) — リリース手順（`release.yml` の活用場面）
- [`SECURITY.md`](../SECURITY.md) — 脆弱性報告手順（`SUPPORT.md` / `ISSUE_TEMPLATE/config.yml` の脆弱性導線）
- [`CHANGELOG.md`](../CHANGELOG.md) — `release.yml` のカテゴリ構成の参照元

## このドキュメントを更新するガイド

- `.github/` 配下に新たな非ワークフロー系メタファイルを追加した場合は、まず本ファイルの「一覧」表に 1 行追加し、続けて「ファイル別の概要と編集時の注意点」節に 1 サブセクションを追加してください。
- `.github/workflows/` の追加・変更は本ドキュメントではなく [`docs/CI.md`](./CI.md) で扱います（責務の分離を保つため）。
- `release.yml` のカテゴリやラベル体系を変更した場合は、関連する `.github/dependabot.yml`・`.github/ISSUE_TEMPLATE/`・[`CHANGELOG.md`](../CHANGELOG.md) との整合を確認してください。
- リンクは可能な限りリポジトリ内相対パスで記述してください。CI の `link-check` ワークフローが `**/*.md` を検査しており、外部リンクが増えると運用コストが上がります。
