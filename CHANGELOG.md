# Changelog

このプロジェクトの主な変更点を記録するファイルです。

フォーマットは [Keep a Changelog v1.1.0](https://keepachangelog.com/ja/1.1.0/) に、
バージョン番号は [Semantic Versioning](https://semver.org/lang/ja/) に準拠します。

## [Unreleased]

### Added

- （次回リリースで追加する機能をここに記載）

### Changed

- （挙動の変更をここに記載）

### Deprecated

- （非推奨になった機能をここに記載）

### Removed

- （削除された機能をここに記載）

### Fixed

- （バグ修正をここに記載）

### Security

- （セキュリティ関連の修正をここに記載）

## [0.1.0] - 2026-04-09

初回リリース。Instagram のダイレクトメッセージ（DM）機能に特化した iOS アプリの
Baseline 実装を記録します。

### Added

- 起動時に `https://www.instagram.com/direct/inbox/` を自動で開く DM 専用ビュー
  （`InstaDirectOnly/ContentView.swift` / `InstaDirectOnly/InstagramWebView.swift`）。
- `WKNavigationDelegate` による URL allowlist ガード
  （`InstagramWebView.isAllowedURL`）:
  - スキームは `http` / `https` のみ許可（`javascript:` / `data:` / `file:` などは拒否）。
  - ホストは `instagram.com` および `*.instagram.com`、`cdninstagram.com`、
    `fbcdn.net`、`facebook.com`、`fbsbx.com` とそのサブドメインを許可。
  - Instagram ドメイン内で許可されるパスは `/direct` / `/accounts/login` /
    `/accounts/onetap` / `/accounts/logout` / `/accounts/password/reset` /
    `/challenge` / `/api/v1` / `/oauth` および `/` のみ。
  - パストラバーサル（`..` / `.` セグメント）を deny-by-default で拒否。
- `WKUIDelegate` による `target="_blank"` / `window.open` のハンドリング:
  許可 URL は同じ WebView で開き、許可外 URL は何もしない（外部ブラウザは開かない）。
- `WKUserScript(.atDocumentStart)` と `didFinish` での CSS 再注入による
  フィード / タブバー / アプリ誘導バナーの非表示化。
- WebKit の標準データストアを使用した Cookie 永続化によるログイン状態の維持
  （独自バックエンドを介在させない）。
- ネットワークエラー時の SwiftUI オーバーレイと再試行ボタン。
  `NSURLErrorCancelled` / `WebKitErrorCannotShowURL` /
  `WebKitErrorFrameLoadInterruptedByPolicyChange` はユーザー操作起因のため
  オーバーレイ対象から除外。
- 代表的な `NSURLErrorDomain` コードを日本語のユーザーフレンドリーな
  メッセージへ寄せる `InstagramWebView.userFriendlyErrorMessage(for:)`。
- `WKWebView.estimatedProgress` を反映する画面上部のリニアプログレスバー
  （`NSKeyValueObservation` で監視し、`Coordinator.deinit` で `invalidate()`）。
- モバイル Safari を装う `InstagramWebView.mobileSafariUserAgent` 定数の集約。
- `InstaDirectOnlyTests/InstagramWebViewURLPolicyTests.swift`
  に URL allowlist / エラーメッセージのユニットテスト。
- リポジトリ運用ドキュメント: `README.md` / `CONTRIBUTING.md` /
  `CODE_OF_CONDUCT.md` / `SECURITY.md` / `LICENSE` /
  `.github/CODEOWNERS` / `.github/PULL_REQUEST_TEMPLATE.md` /
  `.github/ISSUE_TEMPLATE/`（`bug_report.md` / `feature_request.md` /
  `config.yml`） / `.github/SUPPORT.md`。
- 開発補助ファイル: `.gitattributes` / `.gitignore` / `.gitmessage` /
  `.swift-format` / `Makefile`。

### Security

- URL allowlist で `evil-instagram.com.attacker.example` のような偽装ホストと、
  `javascript://www.instagram.com/...` のようなスキームを利用した allowlist 迂回を
  ブロック。
- Instagram ドメイン下のパスに対して `..` / `.` セグメントを含む URL を早期に拒否
  （パストラバーサル対策）。

[Unreleased]: https://github.com/mohadayo/InstaDirectOnly/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/mohadayo/InstaDirectOnly/releases/tag/v0.1.0
