# アクセシビリティガイド

本ドキュメントは、`InstaDirectOnly` の iOS アプリとしての **アクセシビリティ方針** を一次情報としてまとめたものです。新規に SwiftUI View / UIKit View / `WKWebView` 周辺のコードを追加・変更する際、PR レビューの観点としても参照してください。

## 設計方針

- **「DM だけに集中する」** という本アプリのスコープ (`docs/ROADMAP.md` 参照) に合わせ、独自の UI 要素は最小限に抑え、Instagram Web が提供するアクセシビリティ属性を極力そのまま活かす方針を取ります。
- アプリ側で保証するのは **アプリ固有のシェル部分** (ナビゲーション、エラー表示、再試行ボタン、設定画面など) のアクセシビリティです。
- WebView の内部 (Instagram が描画する DOM) のアクセシビリティは **Instagram 側の実装に依存** し、本リポジトリでは制御しません。これは割り切りです。

## 保証する範囲

| 項目 | 保証レベル | 補足 |
| --- | --- | --- |
| VoiceOver での操作 (アプリシェル) | 保証 | 全ての操作可能要素に `accessibilityLabel` を付与する |
| Dynamic Type (アプリシェル) | 保証 | `.font(.body)` 等のセマンティックフォントを使用する |
| Reduce Motion | 保証 | `UIAccessibility.isReduceMotionEnabled` を尊重する |
| Bold Text | 保証 | システムフォント経由で自動反映される前提とする |
| 最小タップ領域 44x44pt | 保証 | 全てのタップ可能要素で満たす |
| カラーコントラスト WCAG AA | 努力目標 | システムカラー (`.primary` / `.secondary` 等) を優先的に使う |
| VoiceOver での WebView 内部操作 | 保証外 | Instagram 側の実装に委ねる |

## 実装チェックリスト

### SwiftUI View を追加・変更する時

- [ ] 画像・アイコンに意味がある場合、`.accessibilityLabel("...")` で日本語ラベルを付けたか。装飾目的なら `.accessibilityHidden(true)` にしたか。
- [ ] ボタン・タップ可能領域が **44x44pt 以上** あるか (`.frame(minWidth: 44, minHeight: 44)` または十分な padding)。
- [ ] 文字サイズは `.font(.body)` / `.font(.headline)` 等のセマンティックフォントか (固定 pt を避ける)。
- [ ] カラーは `.primary` / `.secondary` / `Color(.systemBackground)` 等、ダークモード・ハイコントラスト両対応のシステムカラーを優先しているか。
- [ ] アニメーションは `UIAccessibility.isReduceMotionEnabled` が `true` の時に無効化または簡略化されるか。
- [ ] 複数の要素を 1 つの意味単位として読み上げたい場合、`.accessibilityElement(children: .combine)` を使っているか。

### UIKit / `WKWebView` 周辺を変更する時

- [ ] カスタム `UIView` に `accessibilityLabel` / `accessibilityTraits` / `isAccessibilityElement` を設定したか。
- [ ] エラーダイアログ (`UIAlertController`) のメッセージが VoiceOver で意味を成すか (省略記号や記号の多用を避ける)。
- [ ] `WKWebView` の `allowsBackForwardNavigationGestures` を変更する際、スクリーンリーダ利用者の代替操作 (明示的な戻るボタン等) を用意したか。

## WebView 固有の制約

- `WKUserScript(.atDocumentStart)` で CSS を注入する場合でも、Instagram 側の `aria-*` 属性や `role` を打ち消さないこと。`display: none` で要素を消す時は、代わりの読み上げ対象がページ内に残っているかを確認する。
- URL allowlist (`docs/ARCHITECTURE.md` 参照) で遷移をブロックしたとき、ユーザに **「どこへの遷移がブロックされたか」** を VoiceOver でも伝わる形で通知する (単に `.alert` を出すだけでも最低限満たせる)。
- クラッシュリカバリ (`docs/CRASH_RECOVERY.md` 参照) の自動リロード時、画面が無言で切り替わるのは VoiceOver 利用者にとって混乱の元。`UIAccessibility.post(notification: .screenChanged, argument: ...)` で状態変化を明示的に通知する。

## PR レビュー時の確認観点

PR レビュワは以下を目視・実機で確認してください。

1. **VoiceOver を ON にして**、変更画面を上から下までスワイプで巡回できるか。読み上げ順序が不自然でないか。
2. **設定アプリ → アクセシビリティ → 画面表示とテキストサイズ → さらに大きな文字** で最大サイズに設定した時、レイアウトが破綻しないか (折返しは許容、要素のはみ出しは NG)。
3. **設定アプリ → アクセシビリティ → 動作 → 視差効果を減らす** を ON にした時、意図したアニメーション抑制が効いているか。
4. **ダークモード** と **ライトモード** の双方で、テキストが背景に埋もれていないか (ハードコードされた白/黒がないか)。

## 参考リンク

- Apple Human Interface Guidelines — Accessibility: https://developer.apple.com/design/human-interface-guidelines/accessibility
- Apple Developer — Accessibility API Reference: https://developer.apple.com/documentation/accessibility
- WCAG 2.2: https://www.w3.org/TR/WCAG22/

---

本ドキュメントは生きたチェックリストです。実装中に気付いた新しい観点があれば、別途 Issue / PR で追記してください。
