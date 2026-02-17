# chrome-webstore-publish

Chrome Web Store API v2 とサービスアカウント認証を使って、Chrome 拡張機能の zip アップロードと公開を行う GitHub Composite Action です。

## 背景

- 本 Action は **Chrome Web Store API v2** を利用します。
- Chrome Web Store API v1 は **2026年10月15日** に廃止予定です。

## 入力パラメータ

| 名前 | 必須 | デフォルト | 説明 |
| --- | --- | --- | --- |
| `service-account-key-json` | yes | - | サービスアカウント JSON キー |
| `extension-id` | yes | - | Chrome 拡張機能 ID |
| `publisher-id` | yes | - | Chrome Web Store パブリッシャー ID |
| `zip-path` | yes | - | アップロードする zip ファイルパス |
| `publish` | no | `"true"` | アップロード後に公開するか |

## 出力パラメータ

| 名前 | 説明 |
| --- | --- |
| `upload-status` | upload API のレスポンスステータス |
| `publish-status` | publish API のレスポンスステータス（`publish=true` の場合のみ） |

## 事前準備

### 1. Chrome Web Store 側の前提

- 対象の拡張機能を Chrome Web Store で一度手動公開しておく

### 2. Google Cloud Console でサービスアカウントを作成

1. Google Cloud プロジェクトを作成
2. 「API とサービス」で **Chrome Web Store API** を有効化
3. サービスアカウントを作成
4. サービスアカウントの JSON キーを発行して取得

### 3. Developer Dashboard でサービスアカウントを追加

1. [Chrome Web Store Developer Dashboard](https://chrome.google.com/webstore/devconsole/) を開く
2. Account セクションを開く
3. サービスアカウントの `client_email` を追加

### 4. パブリッシャー ID を確認

1. Developer Dashboard の Account セクションを開く
2. 表示される Publisher ID を控える

### 5. GitHub Secrets を設定

1. 対象リポジトリの `Settings` -> `Secrets and variables` -> `Actions`
2. `GOOGLE_SA_KEY_JSON` などの名前で JSON 全体を保存

## 使い方

### 最小構成

```yaml
name: release

on:
  workflow_dispatch:

jobs:
  publish:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Publish extension
        uses: kokoichi206/chrome-webstore-publish@v1
        with:
          service-account-key-json: ${{ secrets.GOOGLE_SA_KEY_JSON }}
          extension-id: abcdefghijklmnopqrstuvwxyz123456
          publisher-id: "1234567890"
          zip-path: extension.zip
```

### フルオプション

```yaml
name: release

on:
  workflow_dispatch:

jobs:
  publish:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Upload only (no publish)
        id: cws
        uses: kokoichi206/chrome-webstore-publish@v1
        with:
          service-account-key-json: ${{ secrets.GOOGLE_SA_KEY_JSON }}
          extension-id: abcdefghijklmnopqrstuvwxyz123456
          publisher-id: "1234567890"
          zip-path: dist/extension.zip
          publish: "false"

      - name: Show action outputs
        run: |
          echo "upload-status=${{ steps.cws.outputs.upload-status }}"
          echo "publish-status=${{ steps.cws.outputs.publish-status }}"
```

## 実装メモ

- `scripts/publish.sh` は `set -euo pipefail` を使用
- サービスアカウントの `private_key` は一時ファイルに書き出し、`trap` で削除
- アクセストークンは `::add-mask::` でマスク
- Upload/Publish の失敗時はレスポンス内容を標準エラーに出力して終了

## 参考リンク

- [Chrome Web Store API Reference (REST)](https://developer.chrome.com/docs/webstore/api/reference/rest)
- [Use service accounts](https://developer.chrome.com/docs/webstore/service-accounts)
- [Introducing the Chrome Web Store Publish API V2](https://developer.chrome.com/blog/cws-api-v2)
- [Using OAuth 2.0 for Server to Server Applications](https://developers.google.com/identity/protocols/oauth2/service-account)
- [Discovery Document (v2)](https://chromewebstore.googleapis.com/$discovery/rest?version=v2)
