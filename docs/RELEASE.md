# リリース手順（`docs/RELEASE.md`）

このドキュメントは、InstaDirectOnly のリリースを切る際の一次情報をまとめたものです。
[`CHANGELOG.md`](../CHANGELOG.md) が Keep a Changelog v1.1.0 準拠、バージョン番号が [Semantic Versioning](https://semver.org/lang/ja/) 準拠であるという前提の上で、**次のバージョンをどう切るか** を人間・自動化エージェント双方が再現できる粒度で書き下しています。

## 1. バージョン番号の決め方（SemVer）

`vX.Y.Z` 形式で採番し、`[Unreleased]` に積まれている変更を以下の基準で判定します（判断に迷う変更は、より上位の bump を選びます）。

- **MAJOR (`X`)**: 互換性を壊す変更。例:
  - サポートする iOS Deployment Target を bump した（例: iOS 17+ → iOS 18+）
  - URL allowlist を **狭める** 方向のポリシー変更（従来通っていた URL が通らなくなる）
  - ユーザーの Cookie / セッションを消失させる変更（データストア差し替え等）
- **MINOR (`Y`)**: 後方互換のある機能追加。例:
  - 新しい URL パスを allowlist に追加
  - エラーメッセージのマッピングテーブル拡充
  - 進捗バー / スワイプでキーボードを閉じる等の UX 追加
- **PATCH (`Z`)**: バグ修正・ドキュメント / CI 変更のみ。例:
  - CSS セレクタが Instagram の DOM 変更に追従できずタブバーが隠れなくなっていたのを修正
  - `docs/*.md` の記述誤り修正、内部リファクタリング
  - `README.md` の追記だけで CHANGELOG に載せない微修正（この場合はリリース自体不要）

「まだユーザーが 1 人もいない `0.x.y` 系だから何をしても patch でよい」とはせず、**将来 `1.0.0` に達したときと同じ判断基準** で採番します。SemVer に沿っていれば、後で `1.0.0` に切り替えるときにバージョン履歴を書き換えずに済みます。

## 2. リリース前チェックリスト

`main` ブランチ上でリリースコミットを作る直前に、以下を確認します。

- [ ] `main` の CI が緑（`link-check` ワークフローが最新の schedule で成功している）
- [ ] `CHANGELOG.md` の `[Unreleased]` 節に、このリリースに含める変更が **すべて** 書かれている（PR マージ時に忘れていないか、`git log v<前バージョン>..HEAD --oneline` で確認）
- [ ] `README.md` / `docs/*.md` の記述が、リリースする挙動と一致している（例: 新しい URL パスを allowlist に追加したなら README の「URL ポリシー」節にも反映済み）
- [ ] `InstaDirectOnlyTests/` のユニットテストが、追加・変更した挙動をカバーしている（ローカルで Xcode の `⌘U`。テストターゲット追加手順は [`docs/TESTING.md`](./TESTING.md) を参照）

## 3. リリースコミットの作り方

以下は `v0.2.0` を切る例です。実際の版数に読み替えてください。

### 3.1 `CHANGELOG.md` を更新

1. `## [Unreleased]` 節を **そのまま残す**（空でよい）。
2. その下に `## [0.2.0] - YYYY-MM-DD`（リリース日は JST）を挿入し、`[Unreleased]` に積まれていた `### Added` / `### Changed` / ... を丸ごと移動します。空になったカテゴリ節は削除して構いません。
3. ファイル末尾のリンク定義を更新します。

   変更前:

   ```
   [Unreleased]: https://github.com/mohadayo/InstaDirectOnly/compare/v0.1.0...HEAD
   [0.1.0]: https://github.com/mohadayo/InstaDirectOnly/releases/tag/v0.1.0
   ```

   変更後:

   ```
   [Unreleased]: https://github.com/mohadayo/InstaDirectOnly/compare/v0.2.0...HEAD
   [0.2.0]: https://github.com/mohadayo/InstaDirectOnly/releases/tag/v0.2.0
   [0.1.0]: https://github.com/mohadayo/InstaDirectOnly/releases/tag/v0.1.0
   ```

   `[Unreleased]` の compare 元を **常に最新タグに書き換える** のがポイントです。ここを忘れると GitHub 上の `[Unreleased]` リンクが古いタグからの差分を指し続けてしまいます。

### 3.2 Xcode プロジェクトの版数

Xcode の Build Settings（または `InstaDirectOnly.xcodeproj/project.pbxproj` 内の `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION`）を、CHANGELOG のバージョンと揃えます。

- `MARKETING_VERSION` はユーザー可視のバージョン（例: `0.2.0`）。CHANGELOG の `## [X.Y.Z]` と完全一致させます。
- `CURRENT_PROJECT_VERSION` は Build Number。数値だけの単調増加（例: `2`）にします。App Store Connect にアップロードするたびに増やす必要があるため、リリースコミットのタイミングで最低 `+1` します。

App Store 提出を伴わないリリース（GitHub タグのみ）でも、後で TestFlight / App Store に載せる可能性を考慮して `CURRENT_PROJECT_VERSION` を進めておきます。

### 3.3 コミット・タグ・push

コミットメッセージのプレフィクスは `chore:`（CHANGELOG と `pbxproj` の版数更新のみのため）を推奨します。

```
git checkout main
git pull --ff-only origin main
# 3.1 / 3.2 の変更を CHANGELOG.md / project.pbxproj に反映
git add CHANGELOG.md InstaDirectOnly.xcodeproj/project.pbxproj
git commit                              # メッセージは .gitmessage テンプレに従う
git tag -a v0.2.0 -m "Release v0.2.0"   # 注釈付きタグ (推奨)
git push origin main
git push origin v0.2.0
```

タグは必ず **注釈付き（`-a`）** にし、軽量タグは使いません。`git describe` や GitHub Releases のタグ検索が扱いやすくなるためです。

## 4. GitHub Releases の作成

タグを push した後、GitHub の Releases 画面から新しいリリースを作成します。

- **Tag**: `v0.2.0`（3.3 で push 済みのものを選択）
- **Title**: `v0.2.0`（`v` を含む。CHANGELOG の `## [0.2.0] - YYYY-MM-DD` 見出しと対応）
- **Description**: `CHANGELOG.md` の `## [0.2.0]` 節本文をそのままコピーします。`### Added` / `### Fixed` などの小見出しも残します。末尾に compare 差分リンク（形式は `.../compare/<前バージョンタグ>...<今回タグ>`）を付けると閲覧しやすくなります。
- **Set as the latest release**: チェックする（プレリリースでない限り）。
- **Create a discussion for this release**: 現時点では OFF（Discussions を有効化していないため）。

`gh` CLI が使える環境なら次のワンライナーで代替可能です:

```
gh release create v0.2.0 \
    --title "v0.2.0" \
    --notes-file <(sed -n '/^## \[0.2.0\]/,/^## \[/p' CHANGELOG.md | sed '$d')
```

## 5. リリース後にやること

- [ ] `[Unreleased]` 節が「（次回リリースで追加する機能をここに記載）」のプレースホルダに戻っているか（3.1 でカテゴリ節ごと下に移した場合、テンプレの空節を復帰しておくと次回の起票がスムーズです）
- [ ] `CHANGELOG.md` 末尾の `[Unreleased]: ...compare/v0.2.0...HEAD` が今回のタグを指しているか
- [ ] GitHub Releases の該当リリースが `Latest` バッジ付きで表示されているか
- [ ] （App Store 提出を伴う場合）App Store Connect の Version / Build と GitHub タグが一致しているか

## 6. ホットフィックス（`v0.2.1` 系）

`v0.2.0` を切った直後に致命的な不具合が見つかった場合の手順です。

1. `main` から `hotfix/v0.2.1-<件名>` ブランチを作成し、修正コミットのみを載せます（`fix:` プレフィクス）。
2. 通常フローで PR → レビュー → squash マージ。マージコミットが `main` に載ります。
3. `main` 上で CHANGELOG に `## [0.2.1] - YYYY-MM-DD` 節を作り、`### Fixed` のみを持つ最小の節にします。
4. 3.2 / 3.3 と同様に `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` を bump し、`v0.2.1` タグを打って push。
5. GitHub Releases を作成。前バージョン (`v0.2.0`) は `Latest` バッジを失いますが、`Pre-release` へ格下げはしません。

## 7. ロールバック

タグを消す・上書きすることは行いません（一度公開したタグは配布物として不変扱い）。**壊れたリリースは 6 章のホットフィックスで上書き** します。

App Store 側では、TestFlight のリリースを一時停止する / App Store Connect 上で「App Store Version」を差し戻す等の対応を、コードのタグとは独立に行います。GitHub 側のタグ / Release はコードの歴史として残します。

## 参考

- [`CHANGELOG.md`](../CHANGELOG.md) — Keep a Changelog 準拠の変更履歴（一次情報）
- [`CONTRIBUTING.md`](../CONTRIBUTING.md) — ブランチ運用・コミット規則
- [`docs/TESTING.md`](./TESTING.md) — テストターゲット追加手順とローカル `⌘U` の流れ
- [Keep a Changelog v1.1.0（日本語）](https://keepachangelog.com/ja/1.1.0/)
- [Semantic Versioning 2.0.0（日本語）](https://semver.org/lang/ja/)
