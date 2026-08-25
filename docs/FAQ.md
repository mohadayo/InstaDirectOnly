# FAQ (よくある質問)

InstaDirectOnly の利用や開発でよく寄せられる質問をまとめています。
問題が発生した場合はまず [TROUBLESHOOTING.md](./TROUBLESHOOTING.md) も併せてご確認ください。

## 利用について

### Q. InstaDirectOnly は Instagram の公式アプリですか？

いいえ。InstaDirectOnly は Instagram Direct Message (DM) 画面のみを開くことに特化した
非公式のサードパーティ製 iOS アプリです。Instagram の公式アプリではありません。
`WKWebView` で Instagram の Web 版 DM 画面を表示するシンプルなラッパーです。

### Q. なぜ DM 画面だけを表示するのですか？

Instagram のフィード・リール・ストーリー等の "無限スクロール" コンテンツを
避け、DM のやりとりだけに集中したいユーザ向けのアプリだからです。
アプリを開いてから DM 画面に到達するまでの導線を最短化することが目的です。

### Q. 新規投稿やフィード閲覧はできますか？

できません。DM 以外の Instagram 機能を利用したい場合は
[公式 Instagram アプリ](https://apps.apple.com/jp/app/instagram/id389801252) を
ご利用ください。

### Q. ログイン情報はどこに保存されますか？

`WKWebView` の Cookie / セッション情報は iOS 標準の
`WKWebsiteDataStore` (persistent) に保存されます。
これは iOS のサンドボックス内に格納され、他のアプリからは参照できません。
本アプリは Instagram のパスワードを直接取得・保存することはありません。

詳細は [SECURITY.md](../SECURITY.md) をご覧ください。

### Q. データを削除するにはどうすればよいですか？

iOS の設定 → 一般 → iPhone ストレージから InstaDirectOnly を選び、
「App を削除」を実行してください。`WKWebView` が保持する Cookie /
キャッシュを含めて完全に削除されます。

## 開発について

### Q. ビルドに必要な環境は？

- Xcode 15 以降
- iOS 17 以降のシミュレータまたは実機
- macOS 14 (Sonoma) 以降

セットアップの詳細は [README.md](../README.md) と
[CONTRIBUTING.md](../CONTRIBUTING.md) をご覧ください。

### Q. テストはどのように実行しますか？

`Makefile` にテスト用のターゲットが定義されています。

```sh
make test
```

または Xcode 上で ⌘U でユニットテストを実行できます。
`InstaDirectOnlyTests/` 配下に URL ポリシー・エラーメッセージ変換・
定数のテストが用意されています。

### Q. コードスタイルは？

`.swift-format` を用いた Apple 標準の `swift-format` に準拠しています。
プルリクエストの前に以下でフォーマットを整えてください。

```sh
make format
```

### Q. どのブランチに PR を出せばよいですか？

デフォルトブランチ (`main`) に対して PR を作成してください。
ブランチ名は `feat/xxx` `fix/xxx` `docs/xxx` `chore/xxx` `refactor/xxx`
のいずれかのプレフィックスで始めてください。

詳しくは [CONTRIBUTING.md](../CONTRIBUTING.md) をご覧ください。

## トラブルシューティング

### Q. アプリを開いてもログイン画面から進めません

Cookie が期限切れになっているか、Instagram 側の 2 段階認証が必要な状態です。
一度アプリを削除して再インストールし、改めて Instagram に
ログインし直してみてください。

### Q. 「読み込みに失敗しました」と表示されます

以下を順にご確認ください。

1. iPhone がインターネットに接続されているか
2. Instagram の Web 版 (https://www.instagram.com/) 自体に障害が発生していないか
3. アプリ内の「再試行」ボタンを押しても復旧しない場合は、アプリを再起動する

繰り返し発生する場合は
[TROUBLESHOOTING.md](./TROUBLESHOOTING.md) の「連続クラッシュ時の
自動復帰」節も併せてご確認ください。

### Q. WKWebView がクラッシュを繰り返します

短時間 (`crashRecoveryWindow`) に一定回数 (`crashRecoveryMaxAttempts`) 以上
クラッシュした場合、自動復帰を停止します。
これは無限クラッシュループから抜け出せるよう、ユーザに
「再試行」ボタンを明示的に押してもらう設計になっています。

詳細は `InstagramWebView.swift` の
`Coordinator.resetCrashRecoveryState()` の実装コメントをご覧ください。

## その他

### Q. 不具合を報告したい・機能要望を出したい

[ISSUE TEMPLATE](https://github.com/mohadayo/InstaDirectOnly/issues/new/choose)
からご報告ください。テンプレートに沿って再現手順・環境情報を
記入いただけると調査がスムーズです。

### Q. サポートを受けたい

[SUPPORT.md](../.github/SUPPORT.md) にサポート方針をまとめています。
