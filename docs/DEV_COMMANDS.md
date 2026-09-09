# 開発コマンドリファレンス（`docs/DEV_COMMANDS.md`）

このドキュメントは、リポジトリ直下の [`Makefile`](../Makefile) が提供する日常的な開発タスクの一次リファレンスです。`make help` の出力を読むだけでは把握しづらい、**各タスクの前提条件・上書き可能な変数・典型的なワークフロー**を 1 箇所にまとめています。

- 前提: macOS + Xcode 15 以降 / Swift 5.9 以降（詳細は [`CONTRIBUTING.md`](../CONTRIBUTING.md) を参照）
- 対象: 初回セットアップから CI 前のローカルチェックまでを行う開発者
- 関連: [`docs/TESTING.md`](./TESTING.md)（テストターゲット登録手順）、[`docs/RELEASE.md`](./RELEASE.md)（リリース時の追加手順）

## タスク早見表

| タスク            | 目的                                                                 | 前提                                                        |
| ----------------- | -------------------------------------------------------------------- | ----------------------------------------------------------- |
| `make help`       | 利用可能なタスクを一覧表示（デフォルトターゲット）                   | なし                                                        |
| `make setup`      | SwiftLint / swift-format を Homebrew で導入                          | Homebrew                                                    |
| `make build`      | Debug 構成で iOS Simulator 向けビルド                                | Xcode                                                       |
| `make build-release` | Release 構成でビルド                                              | Xcode                                                       |
| `make test`       | ユニットテストを実行                                                 | Xcode プロジェクトにテストターゲット登録済み（後述）        |
| `make lint`       | SwiftLint による静的解析                                             | `swiftlint`（`make setup` で導入可能）                      |
| `make lint-fix`   | SwiftLint の自動修正                                                 | 同上                                                        |
| `make format`     | `InstaDirectOnly` / `InstaDirectOnlyTests` 配下を swift-format で整形 | `swift-format`（`make setup` で導入可能）                   |
| `make clean`      | `xcodebuild clean` と `build` / `DerivedData` ディレクトリの削除     | Xcode                                                       |
| `make open`       | `InstaDirectOnly.xcodeproj` を Xcode で開く                          | Xcode                                                       |
| `make print-config` | 現在の変数値（`PROJECT` / `SCHEME` など）を表示                   | なし                                                        |

> 一覧は `make help` でも取得できます（ターミナル上では色付きで表示されます）。

## 上書き可能な変数

Makefile 冒頭で定義されている以下の変数は、コマンドライン引数で上書きできます。

| 変数           | 既定値                                                        | 用途                                                       |
| -------------- | ------------------------------------------------------------- | ---------------------------------------------------------- |
| `PROJECT`      | `InstaDirectOnly.xcodeproj`                                   | ビルド対象の Xcode プロジェクト                            |
| `SCHEME`       | `InstaDirectOnly`                                             | ビルドスキーム                                             |
| `CONFIG`       | `Debug`                                                       | 構成（`Debug` / `Release`）                                |
| `DESTINATION`  | `platform=iOS Simulator,name=iPhone 15,OS=latest`             | `xcodebuild` の `-destination` に渡す文字列                |
| `DERIVED_DATA` | `build`                                                       | 派生データ（`-derivedDataPath`）の出力先ディレクトリ       |

### 使用例

```bash
# iPhone 16 シミュレータでビルド
make build DESTINATION='platform=iOS Simulator,name=iPhone 16,OS=latest'

# Release 構成で明示的にビルド（build-release と等価）
make build CONFIG=Release

# 別の派生データ出力先を使用
make build DERIVED_DATA=.build/xcode

# 現在有効な変数を確認
make print-config
```

## 典型的なワークフロー

### 1. 初回セットアップ

```bash
# 開発ツールの導入（SwiftLint / swift-format）
make setup

# プロジェクトを Xcode で開く
make open
```

### 2. 日次の開発ループ

```bash
# 変更 → format → lint → build → test の順に実行するのが基本
make format
make lint
make build
make test          # 事前にテストターゲット登録が必要（下記参照）
```

自動修正できる SwiftLint 違反はまとめて直せます:

```bash
make lint-fix
```

### 3. PR を出す前のチェック

```bash
make clean         # 生成物をクリアしてからやり直す
make lint
make build
make test
```

CI と同じ条件で確認したい場合は `DESTINATION` を CI ワークフロー（`.github/workflows/`）と揃えてください。

## `make test` の前提: テストターゲットの登録

`InstaDirectOnlyTests/` 配下にはユニットテスト（`InstagramWebViewConstantsTests.swift` など）がありますが、テストターゲットが Xcode プロジェクトに登録されていない状態では以下のエラーで失敗します。

```
Scheme InstaDirectOnly is not currently configured for the test action.
```

手順の詳細は [`docs/TESTING.md`](./TESTING.md) を参照してください。要点は次のとおりです。

1. Xcode で `InstaDirectOnly.xcodeproj` を開く
2. `File > New > Target...` から **iOS Unit Testing Bundle** を追加
3. 既存の `InstaDirectOnlyTests/*.swift` を新規テストターゲットのメンバーに追加
4. `Product > Scheme > Edit Scheme...` で `Test` アクションに新規ターゲットを追加

登録後、`make test` あるいは Xcode の `Cmd + U` でユニットテストを実行できます。

## `make` を使わない場合の等価コマンド

`make` が使えない環境（Windows など）や、CI での個別呼び出しでは、以下の `xcodebuild` 直呼びが等価です。

```bash
# make build と等価
xcodebuild \
  -project InstaDirectOnly.xcodeproj \
  -scheme InstaDirectOnly \
  -destination 'platform=iOS Simulator,name=iPhone 15,OS=latest' \
  -derivedDataPath build \
  -configuration Debug build

# make test と等価
xcodebuild \
  -project InstaDirectOnly.xcodeproj \
  -scheme InstaDirectOnly \
  -destination 'platform=iOS Simulator,name=iPhone 15,OS=latest' \
  -derivedDataPath build \
  test

# make format と等価
swift-format --in-place --recursive InstaDirectOnly InstaDirectOnlyTests

# make lint と等価
swiftlint lint --quiet
```

## 関連ドキュメント

- [`CONTRIBUTING.md`](../CONTRIBUTING.md) — コーディング規約・PR ガイドライン
- [`docs/TESTING.md`](./TESTING.md) — テストターゲット追加と検証観点
- [`docs/RELEASE.md`](./RELEASE.md) — バージョン bump / タグ / GitHub Releases
- [`docs/ARCHITECTURE.md`](./ARCHITECTURE.md) — 変更影響範囲を掴むための構成解説
- [`README.md`](../README.md) — アプリの機能・URL ポリシー・エラーハンドリング

## ドキュメントを更新する時のガイド

- `Makefile` のタスクを追加・変更した場合は「タスク早見表」と「典型的なワークフロー」を合わせて更新してください。
- 変数を追加した場合は「上書き可能な変数」節も表形式のまま更新します。
- 例に登場する `DESTINATION` などの値を変えるときは、CI ワークフロー（`.github/workflows/*.yml`）の値との整合性も確認してください。
