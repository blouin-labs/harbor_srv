#!/usr/bin/env bash
# shellcheck shell=bash
#
# ghio-puller-login — Authenticate Docker with ghcr.io using a PAT.
# Runs as a systemd oneshot before harbor-runner.service so the runner
# image can be pulled on boot.
#
# Note: GitHub App installation tokens do not work for GHCR pulls due to
# a platform limitation. Tracking: blouin-labs/issues#72
#
set -euo pipefail

PAT_FILE=/etc/ghio-puller/pat

if [ ! -f "$PAT_FILE" ]; then
    echo "ghio-puller-login: ${PAT_FILE} not found — was GHIO_PULLER_PAT injected at deploy time?" >&2
    exit 1
fi

cat "$PAT_FILE" | docker login ghcr.io -u x-access-token --password-stdin
echo "ghio-puller-login: authenticated with ghcr.io"
