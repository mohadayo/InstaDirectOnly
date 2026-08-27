# テスト方針

`InstaDirectOnly` (iOS Swift アプリ) におけるテストの種別・命名規約・モック方針・非同期テストのパターン・カバレッジ運用をまとめる。

- 全体設計は `ARCHITECTURE.md`
- 障害調査は `TROUBLESHOOTING.md`
- 開発の入り口・繰り返し質問は `FAQ.md`
- 開発フロー全体は ルート `../CONTRIBUTING.md`

本書は "テストをどう書き、どう保守するか" の合意を短く残す場所とする。個別のテスト例は同名のソースの隣に置いたテストコード自身に語らせる。

## 目次

- [1. テストの種別](#1-テストの種別)
- [2. 命名と配置](#2-命名と配置)
- [3. モック / フェイク / スパイの使い分け](#3-モック--フェイク--スパイの使い分け)
- [4. 非同期処理のテストパターン](#4-非同期処理のテストパターン)
- [5. UI テストの粒度](#5-ui-テストの粒度)
- [6. カバレッジ運用](#6-カバレッジ運用)
- [7. CI 連動](#7-ci-連動)

## 1. テストの種別

| 種別 | 対象 | ツール |
| :-- | :-- | :-- |
| 単体テスト (Unit) | 純粋なロジック、Model、状態遷移、変換関数 | XCTest |
| ビューモデルテスト | View 状態を導く View Model 層 | XCTest (Combine / async の検証) |
| UI テスト | 画面遷移・主要ユーザーフロー | XCTest UI Testing |
| スナップショット (任意) | 見た目のリグレッション検知 | 導入時に別途方針を追記 |

軽量な単体テストで拾えるものは単体側で拾う。UI テストは重く不安定になりやすいので "主要フローの回帰確認" に絞る。

## 2. 命名と配置

- 実装が `Xxx.swift` のとき、テストは `XxxTests.swift`
- テストコードは実装と同じ階層構造で `InstaDirectOnlyTests/` 配下に配置する
- テストクラスは `final class XxxTests: XCTestCase` として `final` を付ける
- テストメソッド名は `test_初期状態_期待する結果_条件` の形で日本語 or 英語で意図を明示する

例:

```swift
final class MessageListViewModelTests: XCTestCase {
  func test_受信メッセージ表示_未読数が0になる() { /* ... */ }
  func test_送信中_送信ボタンが無効化される() { /* ... */ }
}
```

## 3. モック / フェイク / スパイの使い分け

- **プロトコル境界を切る**: ネットワーク・永続化・時刻・乱数など "外側" は必ずプロトコル経由で注入する。テストで差し替えられる状態を保つ。
- **フェイク (Fake)**: 挙動を持つ簡易実装。単体テストの標準。
- **モック (Mock)**: 呼び出し検証を含む。使いすぎると壊れやすいテストになるので、"検証が本質" のときに限定する。
- **スパイ (Spy)**: 引数の記録に留める。副作用のあるコマンドが正しい引数で呼ばれたかを確認する用途。

原則: **状態を検証** > **相互作用を検証**。返り値・保持している状態で判定できるならそれで済ませる。

## 4. 非同期処理のテストパターン

### async / await

```swift
func test_フェッチ成功_モデルが更新される() async throws {
  let sut = makeSUT(...)
  try await sut.fetch()
  XCTAssertEqual(sut.state, .loaded(...))
}
```

`XCTestCase` の `async` テストメソッドを使う。`Task { }` を跨ぐ完了は `await` で自然に待てるため、Expectation は不要な場面が多い。

### Combine

Publisher の完了を待つ場合は Expectation を使う。

```swift
let exp = expectation(description: "受信")
let cancellable = viewModel.$state.dropFirst().sink { _ in exp.fulfill() }
viewModel.reload()
wait(for: [exp], timeout: 1.0)
_ = cancellable
```

`dropFirst()` で初期値を弾く癖を付ける。`timeout` は 1 秒以下を目安にし、超えるようなら実装の見直しを検討する。

### タイマー・時刻依存

`Date()` や `Timer` を直接扱わず、`Clock` プロトコル (または `NowProviding` のような自作抽象) を注入する。テストではフェイクの時刻を進めるだけで検証できる。

## 5. UI テストの粒度

- 対象は "落ちたら業務影響が大きいユーザーフロー" に絞る (例: サインイン → メッセージ一覧 → 個別スレッド → 送信)
- スクリーンショット差分の検知は別途スナップショットテストで担う
- アクセシビリティ ID (`accessibilityIdentifier`) を要素に付与し、テキストや位置に依存しない要素選択を徹底する
- 実機の状態依存を排除するため、UI テスト時はダミーデータで起動できるモードを用意する

## 6. カバレッジ運用

- 数値そのものは目標にせず、"重要ロジックが未カバー" を検出する尺度として用いる
- 目安: View Model / ドメインロジックは 80% 以上、UI 層は数値を追わない
- カバレッジ計測は `xcodebuild test -enableCodeCoverage YES` で得る
- 一時的にカバレッジ対象から除外したいケースは、根拠と再検討時期をコメントで残す

## 7. CI 連動

`../Makefile` に集約された下記ターゲットを CI と手元で同じコマンドで叩けるようにする。

```
make build      # ビルドのみ
make test       # 単体・UI テスト実行
make lint       # SwiftLint (導入後)
make format     # swift-format による整形
```

CI が落ちたらまず手元で `make test` を再現する。差が出るときは Xcode のバージョン差 / Derived Data / 実行スキームの差 / 実機とシミュレータの差を順に切り分ける。詳細は `TROUBLESHOOTING.md` を参照する。

## 変更履歴

- 2026-08: 初版作成。
