#!/usr/bin/env bash
# shellcheck shell=bash
#
# ghio-puller-login — Authenticate Docker with ghcr.io using a short-lived
# GitHub App installation token. Runs as a systemd oneshot before
# harbor-runner.service so the runner image can be pulled on boot.
#
set -euo pipefail

APP_ID=3258342
KEY_FILE=/etc/ghio-puller/private-key.pem

if [ ! -f "$KEY_FILE" ]; then
    echo "ghio-puller-login: ${KEY_FILE} not found — was GHIO_PULLER_KEY injected at deploy time?" >&2
    exit 1
fi

# base64url-encode stdin (no padding, + → -, / → _).
b64url() { base64 -w0 | tr '+/' '-_' | tr -d '='; }

now=$(date +%s)
header=$(printf '{"alg":"RS256","typ":"JWT"}' | b64url)
payload=$(printf '{"iat":%d,"exp":%d,"iss":"%s"}' "$((now - 60))" "$((now + 600))" "$APP_ID" | b64url)
sig=$(printf '%s.%s' "$header" "$payload" | openssl dgst -sha256 -sign "$KEY_FILE" | b64url)
jwt="${header}.${payload}.${sig}"

# Resolve installation ID dynamically — no hardcoded config needed.
install_id=$(curl -sf \
    -H "Authorization: Bearer ${jwt}" \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    https://api.github.com/app/installations \
    | jq -r '.[] | select(.account.login == "blouin-labs") | .id')

if [ -z "$install_id" ]; then
    echo "ghio-puller-login: no blouin-labs installation found for app ${APP_ID}" >&2
    exit 1
fi

token=$(curl -sf -X POST \
    -H "Authorization: Bearer ${jwt}" \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "https://api.github.com/app/installations/${install_id}/access_tokens" \
    | jq -r '.token')

if [ -z "$token" ] || [ "$token" = "null" ]; then
    echo "ghio-puller-login: failed to obtain installation access token" >&2
    exit 1
fi

echo "$token" | docker login ghcr.io -u x-access-token --password-stdin
echo "ghio-puller-login: authenticated with ghcr.io"
