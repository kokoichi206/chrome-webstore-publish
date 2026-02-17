# chrome-webstore-publish

A GitHub Composite Action to upload and publish a Chrome extension zip using the Chrome Web Store API v2 with service account authentication.

## Background

- This action uses **Chrome Web Store API v2**.
- Chrome Web Store API v1 is scheduled to be deprecated on **October 15, 2026**.

## Inputs

| Name | Required | Default | Description |
| --- | --- | --- | --- |
| `service-account-key-json` | yes | - | Service account JSON key |
| `extension-id` | yes | - | Chrome extension ID |
| `publisher-id` | yes | - | Chrome Web Store publisher ID |
| `zip-path` | yes | - | Path to the extension zip file |
| `publish` | no | `"true"` | Whether to publish after upload |

## Outputs

| Name | Description |
| --- | --- |
| `upload-status` | Upload API response status |
| `publish-status` | Publish API response status (only when `publish=true`) |

## Prerequisites

### 1. Chrome Web Store requirements

- Your extension must have been published manually at least once in Chrome Web Store.

### 2. Create a service account in Google Cloud Console

1. Create a Google Cloud project.
2. Enable **Chrome Web Store API** under APIs & Services.
3. Create a service account.
4. Generate and download a JSON key for the service account.

### 3. Add the service account in Developer Dashboard

1. Open [Chrome Web Store Developer Dashboard](https://chrome.google.com/webstore/devconsole/).
2. Go to the `Account` section.
3. Add the service account `client_email`.

### 4. Find your publisher ID

1. Open the `Account` section in Developer Dashboard.
2. Copy the displayed Publisher ID.

### 5. Configure GitHub Secrets

1. Go to your repository: `Settings` -> `Secrets and variables` -> `Actions`.
2. Add a secret such as `GOOGLE_SA_KEY_JSON` and paste the full JSON key.

## Usage

### Minimal example

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

### Full options example

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

## References

- [Chrome Web Store API Reference (REST)](https://developer.chrome.com/docs/webstore/api/reference/rest)
- [Use service accounts](https://developer.chrome.com/docs/webstore/service-accounts)
- [Introducing the Chrome Web Store Publish API V2](https://developer.chrome.com/blog/cws-api-v2)
- [Using OAuth 2.0 for Server to Server Applications](https://developers.google.com/identity/protocols/oauth2/service-account)
- [Discovery Document (v2)](https://chromewebstore.googleapis.com/$discovery/rest?version=v2)
