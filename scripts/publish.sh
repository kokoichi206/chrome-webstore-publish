#!/usr/bin/env bash
set -euo pipefail

SERVICE_ACCOUNT_KEY_JSON="${SERVICE_ACCOUNT_KEY_JSON}"
EXTENSION_ID="${EXTENSION_ID}"
PUBLISHER_ID="${PUBLISHER_ID}"
ZIP_PATH="${ZIP_PATH}"
PUBLISH="${PUBLISH:-true}"

if [[ ! -f "$ZIP_PATH" ]]; then
  echo "zip file not found: $ZIP_PATH" >&2
  exit 1
fi

if ! echo "$SERVICE_ACCOUNT_KEY_JSON" | jq -e . >/dev/null; then
  echo "failed to parse service account key json" >&2
  exit 1
fi

PRIVATE_KEY="$(echo "$SERVICE_ACCOUNT_KEY_JSON" | jq -r '.private_key')"
CLIENT_EMAIL="$(echo "$SERVICE_ACCOUNT_KEY_JSON" | jq -r '.client_email')"

KEY_FILE="$(mktemp)"
trap 'rm -f "$KEY_FILE"' EXIT
printf '%s\n' "$PRIVATE_KEY" > "$KEY_FILE"

base64url() {
  openssl base64 -A | tr '+/' '-_' | tr -d '='
}

HEADER_B64="$(printf '%s' '{"alg":"RS256","typ":"JWT"}' | base64url)"
NOW="$(date +%s)"
EXP="$((NOW + 3600))"
CLAIMS_JSON="$(jq -cn \
  --arg iss "$CLIENT_EMAIL" \
  --arg scope "https://www.googleapis.com/auth/chromewebstore" \
  --arg aud "https://oauth2.googleapis.com/token" \
  --argjson iat "$NOW" \
  --argjson exp "$EXP" \
  '{iss:$iss,scope:$scope,aud:$aud,iat:$iat,exp:$exp}')"
CLAIMS_B64="$(printf '%s' "$CLAIMS_JSON" | base64url)"
UNSIGNED_JWT="$HEADER_B64.$CLAIMS_B64"
SIGNATURE_B64="$(printf '%s' "$UNSIGNED_JWT" | openssl dgst -sha256 -sign "$KEY_FILE" | base64url)"
JWT="$UNSIGNED_JWT.$SIGNATURE_B64"

TOKEN_RESPONSE="$(curl -sS https://oauth2.googleapis.com/token \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  --data-urlencode 'grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer' \
  --data-urlencode "assertion=$JWT")"

ACCESS_TOKEN="$(echo "$TOKEN_RESPONSE" | jq -r '.access_token // empty')"
if [[ -z "$ACCESS_TOKEN" ]]; then
  echo "failed to get access token" >&2
  echo "$TOKEN_RESPONSE" >&2
  exit 1
fi

echo "::add-mask::$ACCESS_TOKEN"

UPLOAD_URL="https://chromewebstore.googleapis.com/upload/v2/publishers/${PUBLISHER_ID}/items/${EXTENSION_ID}:upload"
UPLOAD_RAW="$(curl -sS -X POST "$UPLOAD_URL" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H 'Content-Type: application/zip' \
  -T "$ZIP_PATH" \
  -w $'\n%{http_code}')"
UPLOAD_BODY="$(printf '%s' "$UPLOAD_RAW" | sed '$d')"
UPLOAD_HTTP_CODE="$(printf '%s' "$UPLOAD_RAW" | tail -n1)"

if [[ "$UPLOAD_HTTP_CODE" -lt 200 || "$UPLOAD_HTTP_CODE" -ge 300 ]]; then
  echo "upload failed (http $UPLOAD_HTTP_CODE)" >&2
  echo "$UPLOAD_BODY" >&2
  exit 1
fi

UPLOAD_STATUS="$(echo "$UPLOAD_BODY" | jq -r '.uploadState // .status // empty')"
if [[ "$UPLOAD_STATUS" == "IN_PROGRESS" ]]; then
  STATUS_URL="https://chromewebstore.googleapis.com/v2/publishers/${PUBLISHER_ID}/items/${EXTENSION_ID}:fetchStatus"
  for _ in $(seq 1 30); do
    sleep 2
    STATUS_RAW="$(curl -sS "$STATUS_URL" \
      -H "Authorization: Bearer $ACCESS_TOKEN" \
      -w $'\n%{http_code}')"
    STATUS_BODY="$(printf '%s' "$STATUS_RAW" | sed '$d')"
    STATUS_HTTP_CODE="$(printf '%s' "$STATUS_RAW" | tail -n1)"

    if [[ "$STATUS_HTTP_CODE" -lt 200 || "$STATUS_HTTP_CODE" -ge 300 ]]; then
      echo "fetchStatus failed (http $STATUS_HTTP_CODE)" >&2
      echo "$STATUS_BODY" >&2
      exit 1
    fi

    UPLOAD_STATUS="$(echo "$STATUS_BODY" | jq -r '.lastAsyncUploadState // empty')"
    if [[ "$UPLOAD_STATUS" == "SUCCEEDED" ]]; then
      break
    fi

    if [[ "$UPLOAD_STATUS" == "FAILED" || "$UPLOAD_STATUS" == "NOT_FOUND" ]]; then
      echo "upload failed (status $UPLOAD_STATUS)" >&2
      echo "$STATUS_BODY" >&2
      exit 1
    fi
  done
fi

if [[ "$UPLOAD_STATUS" != "SUCCEEDED" && "$UPLOAD_STATUS" != "SUCCESS" && "$UPLOAD_STATUS" != "OK" ]]; then
  echo "upload failed (status $UPLOAD_STATUS)" >&2
  echo "$UPLOAD_BODY" >&2
  exit 1
fi

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  echo "upload-status=$UPLOAD_STATUS" >> "$GITHUB_OUTPUT"
fi

if [[ "$PUBLISH" == "true" ]]; then
  PUBLISH_URL="https://chromewebstore.googleapis.com/v2/publishers/${PUBLISHER_ID}/items/${EXTENSION_ID}:publish"
  PUBLISH_RAW="$(curl -sS -X POST "$PUBLISH_URL" \
    -H "Authorization: Bearer $ACCESS_TOKEN" \
    -w $'\n%{http_code}')"
  PUBLISH_BODY="$(printf '%s' "$PUBLISH_RAW" | sed '$d')"
  PUBLISH_HTTP_CODE="$(printf '%s' "$PUBLISH_RAW" | tail -n1)"

  if [[ "$PUBLISH_HTTP_CODE" -lt 200 || "$PUBLISH_HTTP_CODE" -ge 300 ]]; then
    echo "publish failed (http $PUBLISH_HTTP_CODE)" >&2
    echo "$PUBLISH_BODY" >&2
    exit 1
  fi

  PUBLISH_STATUS="$(echo "$PUBLISH_BODY" | jq -r '.state // .status // empty')"
  if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
    echo "publish-status=$PUBLISH_STATUS" >> "$GITHUB_OUTPUT"
  fi
fi
