#!/usr/bin/env bash
# shellcheck shell=bash
#
# harbor-compose-ctl — Privileged dispatcher for Docker Compose management.
#
# Usage: harbor-compose-ctl <rescan|update|stop|start>
#   rescan  — Start any stacks not yet running (idempotent)
#   update  — Pull latest images and restart all stacks
#   stop    — Stop all stacks via systemd
#   start   — Start all stacks via systemd
#

ACTION="${1:-}"

case "${ACTION}" in
    rescan)
        exec /usr/local/bin/harbor-compose-up.sh
        ;;
    update)
        exec /usr/local/bin/harbor-compose-update.sh
        ;;
    stop)
        exec systemctl stop harbor-compose.service
        ;;
    start)
        exec systemctl start harbor-compose.service
        ;;
    *)
        echo "Usage: harbor-compose-ctl <rescan|update|stop|start>" >&2
        exit 1
        ;;
esac
