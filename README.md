# InstaDirectOnly

Instagram のダイレクトメッセージ（DM）機能だけを使うためのシンプルな iOS アプリ。フィード・リール・発見タブ・ショッピング誘導など、DM 以外のすべての導線をブロックし、メッセージのやり取りに集中できる UI を提供します。

## 特徴

- **DM だけにアクセス**: 起動と同時に `https://www.instagram.com/direct/inbox/` を開く
- **フィード非表示**: 下部ナビゲーションバーやアプリ誘導バナーを CSS で隠す
- **遷移ガード**: 許可リスト以外の URL は読み込みをキャンセルし、DM 画面へ戻る
- **ログイン維持**: WebKit の標準データストアで Cookie を永続化（独自サーバは介在しない）
- **エラー時の再試行**: ネットワーク失敗時はメッセージと再試行ボタンを表示

## 技術スタック

- Swift / SwiftUI
- `WKWebView`（`WebKit`）
- iOS 17+

## ビルド

1. `Xcode 15` 以降で `InstaDirectOnly.xcodeproj` を開く
2. 実機または iOS 17 シミュレータをターゲットに選択
3. ⌘R で起動

## アーキテクチャ

| ファイル | 役割 |
|---------|------|
| `InstaDirectOnly/InstaDirectOnlyApp.swift` | アプリのエントリポイント |
| `InstaDirectOnly/ContentView.swift` | ローディング・エラーオーバーレイを含むルートビュー |
| `InstaDirectOnly/InstagramWebView.swift` | `WKWebView` を SwiftUI でラップ。URL フィルタと CSS 注入を担当 |

## URL ポリシー

許可されるホスト（**完全一致もしくはサブドメインのみ**。`host.contains(...)` のような部分一致は使わない）：

- `instagram.com` および `*.instagram.com`（パス制限あり）
- `cdninstagram.com`, `fbcdn.net`, `facebook.com`, `fbsbx.com` および各サブドメイン（CDN/認証）

これにより `evil-instagram.com.attacker.example` のような偽装ホストはブロックされます。

Instagram ドメイン内で許可されるパス（**完全一致もしくは `target/` で始まるもののみ**。`/directfake` のような prefix の取りこぼしを防ぐ）：

- `/direct`, `/direct/*`（DM）
- `/accounts/login`, `/accounts/onetap`, `/accounts/emailsignup`（ログイン）
- `/challenge`, `/challenge/*`（本人確認）
- `/api/v1`, `/api/v1/*`, `/oauth`, `/oauth/*`（内部 API）
- `/`（リダイレクト中継）

上記以外への遷移は WebView のレベルで `decisionHandler(.cancel)` され、初期ロード完了後であれば自動的に DM 画面へ戻ります。

## エラーハンドリング

`WKNavigationDelegate` の失敗コールバックでエラーメッセージを SwiftUI 側にバインドし、半透明オーバーレイとして表示します。`NSURLErrorCancelled`（許可外 URL ブロックや戻る操作によるキャンセル）はエラーとして扱いません。

## プライバシー

- 独自バックエンドや解析サービスを一切経由しません
- セッション情報は Apple が提供する標準の Cookie 永続化のみで保持されます
- アプリは Instagram のモバイル Web 版を `WKWebView` で表示しているだけです

## ライセンス

このリポジトリのコードについてはリポジトリオーナーの設定に従います。Instagram の利用規約・コンテンツポリシーには各自で従ってください。
