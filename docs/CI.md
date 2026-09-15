# CI ワークフローリファレンス（`docs/CI.md`）

このドキュメントは、リポジトリの [`.github/workflows/`](../.github/workflows) 配下に配置されている GitHub Actions ワークフローの **目的・トリガー・権限・失敗時の対処** を一次リファレンスとしてまとめたものです。各ワークフローの YAML 冒頭コメントよりも粒度を粗く、「何のためにあるか / どんな時に走るか / 落ちたら何を見るか」を横断的に把握したい時の入口として利用してください。

- 前提: ワークフローの実装本体は [`.github/workflows/`](../.github/workflows) に集約されています。個別の詳細（引数・除外設定など）は各 YAML のコメントを参照してください。
- 関連: [`docs/DEV_COMMANDS.md`](./DEV_COMMANDS.md)（ローカル開発コマンド）、[`CONTRIBUTING.md`](../CONTRIBUTING.md)（PR ガイドライン）
- 変更履歴は本文最下部の「変更履歴」節に追記します。

## 目次

- [1. ワークフロー一覧](#1-ワークフロー一覧)
- [2. actionlint](#2-actionlint)
- [3. link-check](#3-link-check)
- [4. stale](#4-stale)
- [5. ワークフローを追加・変更する時のガイド](#5-ワークフローを追加変更する時のガイド)
- [6. トラブルシューティング](#6-トラブルシューティング)

## 1. ワークフロー一覧

| ワークフロー | ファイル | 主なトリガー | 権限 | 失敗時の影響 |
| :-- | :-- | :-- | :-- | :-- |
| [actionlint](#2-actionlint) | [`.github/workflows/actionlint.yml`](../.github/workflows/actionlint.yml) | `push` / `pull_request`（ワークフロー YAML の変更時）+ 手動 | `contents: read` | PR がマージ不可（ワークフロー YAML の構文・shellcheck エラー検知） |
| [link-check](#3-link-check) | [`.github/workflows/link-check.yml`](../.github/workflows/link-check.yml) | 週次（月曜 00:00 UTC）+ `main` への Markdown 変更 push + 手動 | `contents: read` | 通知のみ（`pull_request` トリガー無し）。リンク切れの早期検知 |
| [stale](#4-stale) | [`.github/workflows/stale.yml`](../.github/workflows/stale.yml) | 日次（01:30 UTC）+ 手動 | `issues: write` / `pull-requests: write` | 通知のみ。長期未更新の Issue / PR にラベル付け・自動クローズ |

> 注: 本リポジトリはコード自体（Swift / iOS）のビルド・テストを実行する CI は現時点で導入されていません。ローカルでのビルド・テスト手順は [`docs/DEV_COMMANDS.md`](./DEV_COMMANDS.md) と [`docs/TESTING.md`](./TESTING.md) を参照してください。Swift ビルドを含む CI 導入は将来的な改善候補です。

## 2. actionlint

- **目的**: `.github/workflows/` 配下のワークフロー YAML を [rhysd/actionlint](https://github.com/rhysd/actionlint) で静的解析し、構文エラー・非推奨のセマンティクス・`run:` 内シェルスクリプトの誤り（shellcheck 経由）を PR / push 時点で検知する。
- **トリガー**:
  - `push`（`main` ブランチかつ `.github/workflows/**` または `.github/actionlint.y*ml` の変更を含む場合）
  - `pull_request`（同上のパスフィルタ）
  - `workflow_dispatch`（手動実行）
- **権限**: `contents: read`（読み取り専用）
- **並行制御**: `concurrency: actionlint-${{ github.ref }}` / `cancel-in-progress: true`（同一 ref で古い実行をキャンセル）
- **タイムアウト**: 5 分
- **依存**: `rhysd/actionlint` の公式 `download-actionlint.bash` からバイナリを取得（サードパーティ Action への依存を避けている）
- **失敗時の対処**:
  1. `./actionlint -color` のログを PR のログから確認する（エラーは行番号付きで表示される）
  2. ローカルで再現するには `brew install actionlint && actionlint -color` を実行する
  3. shellcheck 由来のエラーは、該当の `run:` ブロックを見直す（クオート漏れ・未使用変数など）

## 3. link-check

- **目的**: リポジトリ配下の Markdown ファイル（`**/*.md`）に含まれる URL が生存しているかを [lycheeverse/lychee-action](https://github.com/lycheeverse/lychee-action) で検証し、リンク切れを早期に検知する。
- **トリガー**:
  - `schedule`: 毎週月曜 00:00 UTC（JST 09:00）
  - `workflow_dispatch`（手動実行）
  - `push`（`main` ブランチかつ `**/*.md` または本ワークフロー YAML の変更を含む場合）
- **権限**: `contents: read`
- **並行制御**: `concurrency: link-check-${{ github.ref }}` / `cancel-in-progress: true`
- **タイムアウト**: 10 分（`--timeout 20 --max-retries 2 --retry-wait-time 5`）
- **`pull_request` を持たない理由**: レビュー中の PR に対して外部ドメインの一時的な 5xx / 429 でチェックが落ちると、レビュアー体験を損ねるため。生存性の担保はマージ後の `main` 更新と週次スケジュールに委ねる。
- **許容ステータスコード**: `200, 203, 204, 206, 301, 302, 304, 307, 308, 403, 429`
  - Instagram / Apple / GitHub 等は bot に対して `403` / `429` を返しがちなため、これらは "生存" と見なす。
- **失敗時の対処**:
  1. ジョブログの `lychee` セクションで **どの URL がどのステータスで落ちたか** を確認する
  2. 恒久的なリンク切れ（`404` / `410` など）はリンク先を更新するか、Markdown 側で置き換える
  3. 一時的な失敗は再実行（`workflow_dispatch`）で解消することが多い
  4. bot がブロックされる新規ドメインは、必要に応じて `--exclude` の追加を検討する

## 4. stale

- **目的**: 長期間更新のない Issue / Pull Request に対して自動的にラベル付け・通知を行い、一定期間経過後に自動でクローズする。個人メンテナの棚卸し負担を減らし、生きた課題に集中する。
- **トリガー**:
  - `schedule`: 毎日 01:30 UTC（JST 10:30）
  - `workflow_dispatch`（手動実行）
- **権限**: `issues: write` / `pull-requests: write`（ラベル付与・コメント・クローズに必要）
- **並行制御**: `concurrency: stale` / `cancel-in-progress: false`（クローズ処理の途中キャンセルを避ける）
- **タイムアウト**: 10 分
- **主要パラメータ**（詳細は [`stale.yml`](../.github/workflows/stale.yml) を参照）:

  | 項目 | Issue | PR |
  | :-- | :-- | :-- |
  | `stale` 判定までの日数 | 60 日 | 30 日 |
  | 自動クローズまでの猶予 | 14 日 | 14 日 |
  | 付与ラベル | `stale` | `stale` |

- **除外**（`exempt-*-labels` および `exempt-all-milestones: true`）:
  - Issue: `pinned` / `security` / `in-progress` / `help-wanted` / `good-first-issue`
  - PR: `pinned` / `security` / `in-progress` / `work-in-progress`
  - マイルストーン紐付きの Issue / PR は常に除外（計画的作業を尊重）
- **レートリミット対策**: `operations-per-run: 60`（1 回の実行で処理する上限）、`ascending: true`（古い順に処理し取りこぼしを減らす）
- **意図せずクローズされてしまった場合**:
  1. 該当 Issue / PR を再オープンする
  2. 継続対応する予定であれば `pinned` / `in-progress` などの除外ラベルを付与する
  3. マイルストーンを付与するのも有効（自動除外対象になる）

## 5. ワークフローを追加・変更する時のガイド

- **静的解析を通す**: 変更後は `actionlint` ワークフローが自動で走ります。ローカルで先に検証したい場合は `brew install actionlint && actionlint -color .github/workflows/*.yml` を実行してください。
- **権限は最小に**: 各ジョブの `permissions:` は必要な範囲だけを列挙します（デフォルトの `contents: read` を維持し、書き込みが必要なジョブでのみ拡張する）。
- **`concurrency` を設定する**: 同一 ref での多重実行や、日次バッチの同時実行を抑止するため、必ず `concurrency:` を設定してください。キャンセル可否（`cancel-in-progress`）は、途中中断が安全かどうかで判断します（例: `stale` は書き込みを伴うので `false`）。
- **`timeout-minutes` を設定する**: ハング時のランナー資源消費を抑えるため、想定実行時間の 1.5〜2 倍を目安に設定します。
- **サードパーティ Action は SHA ピン留めを検討**: セキュリティ上重要なジョブでは、`@v4` のようなタグ参照ではなく SHA によるピン留めを検討してください（現状はメジャータグ参照で運用）。
- **ドキュメント同期**: 新規ワークフローを追加した場合は、本ファイルの「[1. ワークフロー一覧](#1-ワークフロー一覧)」テーブルと個別節を追加し、[`docs/README.md`](./README.md) 側のインデックスも合わせて更新してください。

## 6. トラブルシューティング

- **ジョブが起動しない**
  - `paths:` フィルタで対象パスが除外されている可能性があります。`.github/workflows/*.yml` の `on:` セクションを確認してください。
  - `workflow_dispatch` で手動実行することでトリガーの問題を切り分けられます。
- **`actionlint` が特定のルールで誤検知する**
  - `.github/actionlint.yml`（または `.yaml`）で除外設定を追加できます。設定を追加した場合は、根拠と再検討時期をコメントで残してください。
- **`link-check` が特定ドメインで落ち続ける**
  - `--exclude` や `--exclude-file` を追加して除外する方針を検討します。プロジェクトとして生存性を確認したいドメインは、除外前に許容ステータスコードの追加で救えないかを検討してください。
- **`stale` が意図せず大量に走ってしまった**
  - `operations-per-run` を一時的に小さくして影響範囲を絞り、`exempt-*-labels` の付与漏れを見直します。既にクローズされた Issue / PR は再オープンしてから対応します。

## 変更履歴

- 2026-09: 初版作成。既存の `actionlint` / `link-check` / `stale` ワークフローを一次リファレンスとしてまとめた。
