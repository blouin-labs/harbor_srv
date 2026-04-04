#!/usr/bin/env bash
# shellcheck shell=bash
#
# harbor-verify-boot — Report the active root partition to GitHub after a deploy reboot.
#
# Called by harbor-verify-boot.service (oneshot, after network-online.target).
# Only runs when /etc/harbor/last-deploy-context exists — written by harbor-deploy.sh
# and deleted here so the service is a no-op on subsequent reboots.
#
set -euo pipefail

CONTEXT_FILE="/etc/harbor/last-deploy-context"
KEY_FILE="/etc/harbor/boot-app-key"
ID_FILE="/etc/harbor/boot-app-id"

[ -f "$CONTEXT_FILE" ] || exit 0

# shellcheck source=/dev/null
source /etc/harbor/partitions.conf
ACTIVE=$(findmnt -n -o SOURCE /)
if [ "$ACTIVE" = "$ROOT_A_DEV" ]; then ACTUAL="Root A"; else ACTUAL="Root B"; fi

RUN_ID=$(cat "$CONTEXT_FILE")
APP_ID=$(cat "$ID_FILE")

# Generate a GitHub App JWT (RS256).
# openssl reads the key directly from the file — avoids the trailing-newline loss
# that $() substitution would cause.
NOW=$(date +%s)
HEADER=$(printf '{"alg":"RS256","typ":"JWT"}' | base64 -w0 | tr '+/' '-_' | tr -d '=')
PAYLOAD=$(printf '{"iat":%d,"exp":%d,"iss":"%s"}' $((NOW - 60)) $((NOW + 600)) "$APP_ID" \
          | base64 -w0 | tr '+/' '-_' | tr -d '=')
SIG=$(printf '%s.%s' "$HEADER" "$PAYLOAD" \
      | openssl dgst -sha256 -sign "$KEY_FILE" \
      | base64 -w0 | tr '+/' '-_' | tr -d '=')
JWT="${HEADER}.${PAYLOAD}.${SIG}"

# Exchange the JWT for an installation access token.
INSTALL_ID=$(curl -sf \
  -H "Authorization: Bearer $JWT" \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/blouin-labs/harbor_srv/installation" \
  | jq -r '.id')

TOKEN=$(curl -sf \
  -X POST \
  -H "Authorization: Bearer $JWT" \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/app/installations/${INSTALL_ID}/access_tokens" \
  | jq -r '.token')

# Update the Actions variable: "{run_id}:{actual_partition}".
curl -sf \
  -X PATCH \
  -H "Authorization: Bearer $TOKEN" \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/blouin-labs/harbor_srv/actions/variables/HARBOR_BOOT_LAST" \
  -d "{\"name\":\"HARBOR_BOOT_LAST\",\"value\":\"${RUN_ID}:${ACTUAL}\"}"

rm -f "$CONTEXT_FILE"
echo "harbor-verify-boot: reported ${ACTUAL} for run ${RUN_ID}"
