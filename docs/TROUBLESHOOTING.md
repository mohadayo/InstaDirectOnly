# トラブルシューティングガイド

InstaDirectOnly の開発中・実行中に遭遇しがちな問題と、その対処法をまとめたガイドです。
Issue を立てる前に、まずはこのページで該当する症状がないかを確認してください。

- 対象読者: 本リポジトリをクローンしてビルドする開発者、および TestFlight などで動作を試している利用者
- 併せて参照: [`README.md`](../README.md) / [`docs/ARCHITECTURE.md`](./ARCHITECTURE.md) / [`CONTRIBUTING.md`](../CONTRIBUTING.md) / [`.github/SUPPORT.md`](../.github/SUPPORT.md)

---

## 目次

1. [環境確認チェックリスト](#1-環境確認チェックリスト)
2. [ビルドが失敗するとき](#2-ビルドが失敗するとき)
3. [コード署名・プロビジョニング関連](#3-コード署名プロビジョニング関連)
4. [実行時の問題](#4-実行時の問題)
5. [テストが落ちるとき](#5-テストが落ちるとき)
6. [CI / GitHub Actions の失敗パターン](#6-ci--github-actions-の失敗パターン)
7. [Makefile ターゲットが動かないとき](#7-makefile-ターゲットが動かないとき)
8. [それでも解決しないとき](#8-それでも解決しないとき)

---

## 1. 環境確認チェックリスト

まずは以下を確認してください。多くの問題は環境不整合が原因です。

| 項目 | 確認コマンド | 期待する状態 |
|------|-------------|--------------|
| macOS バージョン | `sw_vers` | Xcode 最新版がサポートするバージョン |
| Xcode バージョン | `xcodebuild -version` | プロジェクトが指定するバージョン以上 |
| Command Line Tools | `xcode-select -p` | `/Applications/Xcode.app/Contents/Developer` を指している |
| Git バージョン | `git --version` | 2.30 以上を推奨 |
| Ruby / Bundler | `ruby -v` / `bundle -v` | Fastlane などを使う場合のみ |

> **Tip**: 複数の Xcode を入れている場合は `sudo xcode-select -s /Applications/Xcode.app` で切り替えてください。

---

## 2. ビルドが失敗するとき

### 2.1 まずはクリーンビルド

Xcode の不可解なビルドエラーの大半は、キャッシュや DerivedData の不整合が原因です。

```sh
# プロジェクトの Makefile 経由
make clean

# Xcode の DerivedData を手動で削除
rm -rf ~/Library/Developer/Xcode/DerivedData/InstaDirectOnly-*
```

その後、Xcode を再起動してから `Product > Clean Build Folder` (`Shift + Cmd + K`) を実行してください。

### 2.2 Swift Package Manager のキャッシュを剥がす

Swift Package の解決に失敗する、あるいは古いバージョンが解決されてしまう場合。

- Xcode: `File > Packages > Reset Package Caches`
- CLI: `rm -rf ~/Library/Caches/org.swift.swiftpm`

### 2.3 「Module 'XXX' not found」

- ターゲットの Membership が正しいかを確認 (右ペインの File Inspector)
- 上記 2.1 / 2.2 のクリーン後に再ビルド
- ブランチを切り替えた直後の場合は Xcode を一度閉じて開き直す

### 2.4 「Sandbox: rsync deny(1) file-write-create」

macOS の User Script Sandboxing が有効なときに、Build Phase の Run Script が権限エラーを出すことがあります。

- Xcode のターゲット設定 > Build Settings で `ENABLE_USER_SCRIPT_SANDBOXING` を `NO` に設定するか、
- 該当スクリプトの Input/Output Files を正しく宣言する

---

## 3. コード署名・プロビジョニング関連

### 3.1 「No signing certificate "iOS Development" found」

- Xcode > Settings > Accounts に Apple ID を追加し、`Download Manual Profiles` を実行
- ターゲット > Signing & Capabilities で **Automatically manage signing** を有効化
- 自分の Apple ID を Team に選択

### 3.2 Bundle Identifier の衝突

サンプルの Bundle Identifier のままだと Apple 側で他人と衝突することがあります。ローカルで動作確認する場合は次のように書き換えてください。

- 例: `com.example.instadirectonly` → `com.<あなたのドメイン>.instadirectonly`

### 3.3 実機で「Untrusted Developer」

- iOS 端末側で `設定 > 一般 > VPN とデバイス管理 > (自分の Apple ID) > 信頼` を実行

---

## 4. 実行時の問題

### 4.1 Instagram が起動しない / DM 画面が開かない

InstaDirectOnly は Instagram 純正アプリの URL スキームを利用します。以下を確認してください。

- 実機に Instagram 純正アプリがインストールされているか
- Info.plist の `LSApplicationQueriesSchemes` に `instagram` が含まれているか
- iOS 側で Instagram にログイン済みか

### 4.2 深いリンク (Universal Links) が効かない

- Xcode > Signing & Capabilities に `Associated Domains` が含まれているか
- サーバー側の `apple-app-site-association` が正しく配信されているか (キャッシュが効くため、しばらく待つ必要がある場合あり)

### 4.3 キーボードやフォームが挙動不審

- シミュレーターの場合、`I/O > Keyboard > Toggle Software Keyboard` (`Cmd + K`) を確認
- ハードウェアキーボード接続時は `Connect Hardware Keyboard` をオフにする

### 4.4 ダークモードで文字が読めない

- Asset Catalog の Any / Dark アピアランスが定義されているかを確認
- `preferredColorScheme` を強制していないか確認

---

## 5. テストが落ちるとき

### 5.1 ローカルでのみ落ちる

- Xcode の Test Navigator (`Cmd + 6`) から個別テストを実行し、失敗テストを特定
- スキームの `Test` タブでランダム実行順序が有効な場合、順序依存のテストが原因の可能性あり
- シミュレーターの言語・地域を `ja_JP` にして再実行

### 5.2 CI でのみ落ちる (Flaky)

- タイマー・非同期処理を使うテストは `XCTestExpectation` で明示的に待つ
- 時刻依存のテストは固定日時を注入 (依存性注入 / モック時計) する

### 5.3 全部落ちる (Host Application not found 等)

- Test ターゲットの Host Application 設定を確認
- `make clean && make test` を再実行

---

## 6. CI / GitHub Actions の失敗パターン

現在のワークフロー: `.github/workflows/link-check.yml`, `.github/workflows/stale.yml`

### 6.1 link-check が失敗する

- Markdown 内の相対リンク切れが原因のケースが多い。ローカルで該当ファイルを開き、リンク先が存在するか確認する
- 一時的な外部サイト側の 5xx / タイムアウトの場合は Re-run で解決することがある

### 6.2 stale ワークフロー関連

- 動作条件はワークフロー内の `days-before-*` を確認
- 手動で `stale` ラベルを外す、またはコメントで活動を示すと自動的にラベルが外れる

---

## 7. Makefile ターゲットが動かないとき

`Makefile` で用意されている代表的なターゲット:

| ターゲット | 用途 |
|------------|------|
| `make build` | Xcode でビルド |
| `make test` | ユニットテスト実行 |
| `make lint` | Lint / フォーマットチェック |
| `make clean` | DerivedData / 生成物のクリーン |

うまく動かない場合は次を確認してください。

- `xcodebuild` に PATH が通っているか (`xcode-select -p`)
- スキーム名やデスティネーションが自分の環境と一致しているか
- `make -n <target>` で実行される実際のコマンドを確認する (ドライラン)

---

## 8. それでも解決しないとき

上記を試しても解決しない場合、以下の順で対応してください。

1. **既存の Issue / Discussion を検索** — 同じ症状の報告がないか [Issues](https://github.com/mohadayo/InstaDirectOnly/issues?q=is%3Aissue) を確認
2. **[SUPPORT.md](../.github/SUPPORT.md) を参照** — サポート窓口・連絡方法をまとめてあります
3. **Bug Report を作成** — [バグ報告テンプレート](../.github/ISSUE_TEMPLATE/bug_report.md) を使い、以下を必ず添えてください:
   - macOS / Xcode / iOS のバージョン (`xcodebuild -version`, `sw_vers`)
   - 実行したコマンド / 操作手順
   - 期待した結果と実際の結果
   - 可能なら再現最小手順とスクリーンショット・ログ

### セキュリティ関連の報告

セキュリティ脆弱性は公開の Issue ではなく [`SECURITY.md`](../SECURITY.md) の手順に従って報告してください。
