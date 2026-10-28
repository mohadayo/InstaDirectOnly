# リポジトリ直下の設定ファイルリファレンス（`docs/CONFIG_FILES.md`）

このドキュメントは、リポジトリ直下にあるドットファイル形式の設定ファイル群について、**目的・効果の及ぶ範囲・編集時の注意点** を一次リファレンスとしてまとめたものです。各ファイル先頭のコメントは単体で意味を持つように書かれていますが、「どれがどのツール・ワークフローと連動しているのか」を横断的に俯瞰する入口として本ドキュメントを利用してください。

- 対象読者: 初めて貢献するコントリビュータ / 設定ファイルを編集する前に影響範囲を確認したい開発者
- 関連: [`CONTRIBUTING.md`](../CONTRIBUTING.md)（コーディング規約）、[`docs/DEV_COMMANDS.md`](./DEV_COMMANDS.md)（Makefile タスク）、[`docs/CI.md`](./CI.md)（GitHub Actions ワークフロー）

## 一覧

| ファイル                                | 役割                                                                | 効果が及ぶ範囲                                        | 連動するツール / ワークフロー                                   |
| --------------------------------------- | ------------------------------------------------------------------- | ----------------------------------------------------- | --------------------------------------------------------------- |
| [`.editorconfig`](../.editorconfig)     | 文字コード / 改行コード / インデントのエディタ側統一                | リポジトリ内の全テキストファイル                      | EditorConfig 対応エディタ（Xcode / VSCode / Cursor / AppCode 等）|
| [`.gitattributes`](../.gitattributes)   | 行末正規化 / バイナリ指定 / GitHub Linguist ヒント                  | `git add` 時の変換・GitHub 上の言語統計・diff 表示    | Git / GitHub（Linguist）                                        |
| [`.gitignore`](../.gitignore)           | 追跡対象外の生成物・ユーザローカルファイルを定義                    | `git status` / `git add` の挙動                       | Git                                                             |
| [`.gitmessage`](../.gitmessage)         | コミットメッセージテンプレート（件名プレフィックス一覧付き）        | `git commit` 時のエディタ初期表示                     | Git（`git config commit.template` で有効化）                    |
| [`.swift-format`](../.swift-format)     | swift-format のフォーマットルール / 行長 120 / 4 スペース           | `InstaDirectOnly/` / `InstaDirectOnlyTests/` の Swift | `make format` / swift-format CLI                                |
| [`.typos.toml`](../.typos.toml)         | typos (スペルチェッカ) の allowlist / 対象外ファイル                | リポジトリ内の全テキスト（除外設定でバイナリ等を抑止）| `make typos` / `.github/workflows/typos.yml`                    |

> `.github/` 配下のワークフロー・Issue/PR テンプレートなどは、ここではなく [`docs/CI.md`](./CI.md) と [`CONTRIBUTING.md`](../CONTRIBUTING.md) で扱います。

## ファイル別の概要と編集時の注意点

### `.editorconfig`

- Xcode 以外のエディタで開いた場合でも、Xcode デフォルト（4 スペース・LF・末尾改行付与）に揃うようにする最小構成。
- `[*.{yml,yaml,md,json,toml}]` は 2 スペース、`Makefile` はタブ必須（POSIX 準拠）と、ファイル種別ごとに適切な値を明示している。
- **編集時の注意**: Swift のインデント幅を変更すると `.swift-format` の `indentation.spaces` および既存コードの整形結果と不整合になります。両者を同時に更新してください。

### `.gitattributes`

- `* text=auto eol=lf` により、Windows / macOS / Linux の混在環境でもリポジトリ内の行末を LF に統一。
- `*.pbxproj` に `merge=union` を指定し、Xcode プロジェクトファイルの merge 競合を緩和。
- `InstaDirectOnly.xcodeproj/**` を `linguist-generated=true` で言語統計から除外（Swift の比率が実装に対して正しく見えるようにする意図）。
- **編集時の注意**: 新たなバイナリ拡張子（例: 新規フォント・新規メディア）を追加する場合は、`binary` 属性の明示を忘れないでください。差分ノイズの原因になります。

### `.gitignore`

- Xcode の `DerivedData/` / `*.xcuserstate` / ユーザ固有の `xcuserdata/` 等を除外。
- 追加する際は「生成物」か「ユーザローカル」であることを確認し、既にチェックインされているファイルを後から ignore しても追跡は外れない点に注意（`git rm --cached` が別途必要）。

### `.gitmessage`

- `feat: / fix: / refactor: / test: / docs: / chore: ...` のプレフィックス一覧と、件名 50 文字・本文 72 文字折り返しのガイドをテンプレート化。
- リポジトリローカルで有効化するコマンド:
  ```bash
  git config --local commit.template .gitmessage
  ```
- **連携**: 推奨プレフィックスの一覧は [`CONTRIBUTING.md`](../CONTRIBUTING.md) の「コミットメッセージ」節とも整合させています。更新する場合は両者を同時に修正してください。

### `.swift-format`

- 公式 `swift-format` のルール集。`lineLength: 120` / `indentation.spaces: 4` / `fileScopedDeclarationPrivacy.accessLevel: "private"` などを明示。
- CLI は `make format`（`swift-format --in-place --recursive InstaDirectOnly InstaDirectOnlyTests`）で実行されます。詳細は [`docs/DEV_COMMANDS.md`](./DEV_COMMANDS.md) を参照。
- **編集時の注意**: ルールを厳格化した場合、既存コードへの影響範囲を把握するためにローカルで `make format` を実行し、差分の範囲を PR 本文に明示してください。

### `.typos.toml`

- `crate-ci/typos` の allowlist と除外設定。本プロジェクトでは `Unparseable` 綴りをテストヘルパー名に採用しているため、`extend-identifiers` / `extend-words` の両方で許容。
- バイナリや Xcode 生成物は `files.extend-exclude` でチェック対象外にしてあります。
- CLI は `make typos`（CI の `.github/workflows/typos.yml` と同じ設定）で実行可能。
- **編集時の注意**: allowlist を増やす場合は「なぜ辞書に無いのか」（商標名 / 別綴りが標準 / 独自造語など）を 1 行コメントで残してください。既存の記述がそのスタイルの参考になります。

## よくある質問

### Q. Xcode でファイルを編集すると `.editorconfig` の設定は効くのか？

Xcode 15 時点では EditorConfig をネイティブ対応していません。本リポジトリでは「Xcode のデフォルト（4 スペース・LF・末尾改行）と `.editorconfig` の既定を揃える」運用で、Xcode 以外のエディタでも揃うようにしています。Xcode を使う分には従来通り何も設定不要です。

### Q. `swift-format` と SwiftLint は役割がどう違うのか？

- `swift-format`（本リポジトリでは `.swift-format` で設定）: フォーマット整形専用。`make format` で自動整形。
- SwiftLint: スタイル違反・潜在的バグの静的解析。`.swiftlint.yml` は未配置のためデフォルト構成で動作（将来追加予定）。`make lint` で実行。

両者は目的が異なり、同時に導入する運用です。CI での利用有無・設定の詳細は [`docs/CI.md`](./CI.md) を参照してください。

### Q. `.gitignore` に書いたのに追跡されているファイルがある

`.gitignore` は未追跡ファイルに対してのみ効きます。既に `git add` 済みのファイルを ignore 対象にしたい場合は、別途 `git rm --cached <path>` を実行してください（コミットは別途必要）。

## 関連ドキュメント

- [`CONTRIBUTING.md`](../CONTRIBUTING.md) — コーディング規約 / コミットメッセージ / PR ガイドライン
- [`docs/DEV_COMMANDS.md`](./DEV_COMMANDS.md) — `make format` / `make lint` / `make typos` の一次リファレンス
- [`docs/CI.md`](./CI.md) — `.github/workflows/` の各ワークフロー解説
- [`docs/TESTING.md`](./TESTING.md) — テストターゲットの登録手順と検証観点
- [`README.md`](../README.md) — アプリの機能・URL ポリシー・エラーハンドリング

## このドキュメントを更新するガイド

- リポジトリ直下に新たな設定ファイルを追加した場合は、まず本ファイルの「一覧」表に 1 行追加し、続けて「ファイル別の概要と編集時の注意点」節に 1 サブセクションを追加してください。
- ワークフロー・Makefile タスクと連動する設定ファイルについては、連動先のドキュメント（`docs/CI.md` / `docs/DEV_COMMANDS.md`）側にも必要なら追記してください（相互参照が片方向にならないように）。
- リンクは可能な限りリポジトリ内相対パスで記述してください。CI の `link-check` ワークフローが `**/*.md` を検査しており、外部リンクが増えると運用コストが上がります。
