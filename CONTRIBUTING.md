# Contributing to InstaDirectOnly

InstaDirectOnly への貢献に興味を持っていただきありがとうございます。本ドキュメントは、Issue 起票・PR 作成・レビューまでの共通フローをまとめています。

## 前提

- macOS + Xcode 15 以降
- Swift 5.9 以降
- iOS 15+ をターゲットとします

## 開発フロー

1. Issue で先に議論する
   - バグ報告: `.github/ISSUE_TEMPLATE/bug_report.md` に沿って情報を提供してください。
   - 機能追加: `.github/ISSUE_TEMPLATE/feature_request.md` を使ってください。
   - Security に関わる問題は `SECURITY.md` を参照し、Issue ではなく非公開経路で報告してください。
2. リポジトリを fork / clone し、作業用ブランチを切ります
   - 命名例: `feat/<簡潔な内容>`, `fix/<バグ内容>`, `chore/<雑務>`
3. Xcode で `InstaDirectOnly.xcodeproj` を開き、シミュレータ or 実機でビルド・動作確認
4. `InstaDirectOnlyTests` を実行し、既存テストが緑であることを確認
5. 変更が完了したら PR を作成（テンプレートは自動挿入されます）

## コーディング規約

- インデントは 4 スペース（Xcode デフォルト）
- 行長は 140 文字を目安（`.swiftlint.yml` 導入後は SwiftLint 準拠）
- 命名は Swift API Design Guidelines に従う
- `// TODO:` を残す場合は Issue 番号を併記する
- `print` によるデバッグ出力は PR 前に削除、ログが必要な場合は `os_log` / `Logger` を使う

## コミットメッセージ

以下のプレフィックスを推奨します（日本語で簡潔に）：

- `feat:` 機能追加
- `fix:` バグ修正
- `refactor:` 挙動を変えないコード改善
- `test:` テスト追加・修正
- `docs:` ドキュメントのみ
- `chore:` ビルド設定・雑務

1 コミットは 1 関心事にまとめてください。

## PR のガイドライン

- タイトル: 変更内容が一目で分かる日本語
- 本文は `.github/PULL_REQUEST_TEMPLATE.md` に沿って記述
- 対応する Issue がある場合は `Closes #N` を含める
- 動作確認手順（シミュレータ／実機で確認したこと）を記述
- Draft PR で作成し、レビュー準備ができたら Ready for review に変更

## レビュー基準

- 既存の UI/UX を壊さないこと
- Instagram の Web レイヤーに依存する処理は失敗時にユーザーへ明示する
- WebView の JS 注入は影響範囲・失敗時挙動をコメントで残す
- 個人情報・認証情報のログ出力を含まないこと

## Security

セキュリティに関わる報告は `SECURITY.md` に記載の手順に従ってください。GitHub Issue で公開しないでください。

## 質問

不明点は Discussions か、通常の Issue（`question` ラベル）でお気軽にどうぞ。
