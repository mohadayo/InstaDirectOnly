# プライバシー方針（PRIVACY）

このドキュメントは **InstaDirectOnly（本アプリ）がプライバシー観点でどのように振る舞うか** を、ソースコードを読まずに確認できる形で一次情報として集約したものです。App Store 向けの法的文書ではなく、OSS リポジトリとしての実装仕様の宣言です。

> 概要（README.md「プライバシー」節と同じ要旨）
>
> - 独自バックエンドや解析サービスを一切経由しません
> - セッション情報は Apple が提供する標準の Cookie 永続化のみで保持されます
> - アプリは Instagram のモバイル Web 版を `WKWebView` で表示しているだけです

## データフロー

```
+---------+     +------------------+     +-------------------+
|  User   | --> |  InstaDirectOnly | --> | Instagram Web(App)|
| (iOS)   |     |   (WKWebView)    |     |  instagram.com    |
+---------+     +------------------+     +-------------------+
                        |
                        v
             +----------------------+
             | WKWebsiteDataStore   |
             | .default()           |
             | (Cookie / Cache)     |
             +----------------------+
```

- アプリは **自社サーバを一切保持していません**。通信は常に Instagram（および Instagram が指定する CDN / 認証ドメイン）とユーザー端末の間で完結します。
- 画面遷移・URL 検証・CSS 注入はすべてローカルの `WKWebView` 内で行われ、外部にログを送信しません。
- `WKWebsiteDataStore.default()` を使用しているため、Cookie / Cache / LocalStorage は iOS 標準の仕組みに閉じて保存されます（アプリ固有のサンドボックス下）。

## 収集・保存されるデータ

| 種類 | 保存先 | 送信先 | 備考 |
|------|--------|--------|------|
| セッション Cookie | `WKWebsiteDataStore.default()`（アプリサンドボックス内） | Instagram のみ | ログイン維持のため。本アプリは読み取り / 書き込みしない |
| HTTP キャッシュ | 同上 | 送信しない | WebKit 内部キャッシュ |
| LocalStorage / IndexedDB | 同上 | Instagram のみ（SPA の内部用途） | Instagram 側 JS が利用 |
| ユーザー入力（メッセージ本文等） | 保存しない | Instagram のみ（WebView 経由） | アプリ側で傍受・ロギングしない |
| 認証情報（ID / パスワード） | 保存しない | Instagram のみ（WebView 内フォーム送信） | アプリは `/accounts/login` 等の URL 遷移を allowlist で許可するのみ |
| デバイス識別子 / IDFA | **取得しない** | — | AdSupport / AppTrackingTransparency を一切使わない |
| 位置情報 | **取得しない** | — | CoreLocation を使わない |
| 連絡先 / カメラ / マイク / 写真ライブラリ | **直接取得しない** | — | WebView が Instagram のメディア UI を介して iOS 標準の権限ダイアログを表示する場合のみ、ユーザーが明示的に許可した範囲で動作する |

## サードパーティ送信

- **解析 SDK**: 組み込みません（Firebase / Mixpanel / Google Analytics / Amplitude など一切なし）。
- **広告 SDK**: 組み込みません。
- **クラッシュレポーター**: 組み込みません（iOS 標準の TestFlight / App Store Connect クラッシュログは Apple のポリシーに従って Apple に送信される可能性がありますが、本アプリ由来の送信先ではありません）。
- **その他ネットワーク送信**: URL allowlist によって Instagram および Instagram が指定する CDN / 認証ドメインへの通信のみ許可されます。詳細は [`../README.md`](../README.md) の「URL ポリシー」節を参照してください。

## 権限（iOS Info.plist）

本アプリは起動時点では以下の権限を **要求しません**：

- 位置情報 (`NSLocationWhenInUseUsageDescription` / `NSLocationAlwaysAndWhenInUseUsageDescription`)
- カメラ (`NSCameraUsageDescription`)
- マイク (`NSMicrophoneUsageDescription`)
- 写真ライブラリ (`NSPhotoLibraryUsageDescription` / `NSPhotoLibraryAddUsageDescription`)
- 連絡先 (`NSContactsUsageDescription`)
- Face ID / Touch ID (`NSFaceIDUsageDescription`)
- モーション (`NSMotionUsageDescription`)
- Bluetooth (`NSBluetoothAlwaysUsageDescription`)
- 広告追跡許可 (`NSUserTrackingUsageDescription`)

Instagram の DM 画面上で画像添付・ボイスメッセージ録音・カメラ起動などを行う場合は、`WKWebView` が iOS 標準の権限ダイアログをその時点で表示します。この権限はアプリではなく OS が管理し、ユーザーが明示的に許可した場合のみ、Instagram の Web UI 経由で該当デバイス機能が利用されます。

## データの削除手順

### A. アプリをアンインストールする

iOS のアプリ削除で、`WKWebsiteDataStore` 配下の Cookie / Cache / LocalStorage を含むアプリサンドボックスがすべて破棄されます。これが最も確実な削除手段です。

### B. アプリ内でログアウトする

Instagram DM 画面右上のメニューから「ログアウト」を実行すると、`/accounts/logout` 系のパスが allowlist に含まれているため通常のフローで実行できます。ログアウト後、セッション Cookie は Instagram 側で無効化されます。

### C. iOS 設定からストレージを消す

「設定 > 一般 > iPhone ストレージ > InstaDirectOnly」から「App を取り除く」を選ぶとドキュメントと設定が残った状態で削除され、「App を削除」を選ぶと A と同等の完全削除になります。

## URL allowlist によるデータ漏えい防止

- Instagram 外のドメイン（広告・外部計測・短縮 URL 展開先など）への遷移は WebView レイヤーで deny-by-default でブロックされます。
- `javascript:` / `data:` / `blob:` 等の非 HTTP(S) スキームは拒否されるため、スキーム偽装を利用したデータ exfiltration ベクタも封じられます。
- 詳細な allowlist 仕様とテストケースは [`../README.md`](../README.md) の「URL ポリシー」節と `InstaDirectOnlyTests/InstagramWebViewURLPolicyTests.swift` を参照してください。

## 変更履歴

- 本ドキュメントの実質的な変更（データ送信先の追加・権限要求の追加・サードパーティ SDK の導入など）が発生した場合は、`../CHANGELOG.md` の該当バージョン節にも「プライバシーに関わる変更」として併記します。
- プライバシー観点の変更を伴う PR は、本ドキュメントの該当節と `../README.md` の「プライバシー」節の両方を同じ PR で更新してください。

## 関連ドキュメント

- [`../README.md`](../README.md) — 「プライバシー」節（サマリ）・「URL ポリシー」節（送信先の allowlist）
- [`../SECURITY.md`](../SECURITY.md) — 脆弱性報告手順
- [`./ARCHITECTURE.md`](./ARCHITECTURE.md) — `WKWebView` を中心とした構成要素と責務
- [`./FAQ.md`](./FAQ.md) — Cookie の保存場所など利用者視点の FAQ
