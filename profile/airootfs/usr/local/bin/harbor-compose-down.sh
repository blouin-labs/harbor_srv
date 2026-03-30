#!/usr/bin/env bash
# shellcheck shell=bash
#
# harbor-compose-down — Stop all Docker Compose stacks from the NFS share.
#
# Unprefixed stacks stop first in any order.
# Priority stacks (numeric prefix) stop last, in reverse prefix order (99 → 01).
#

COMPOSE_BASE="/mnt/synology/harbor_srv/docker"

stop_stack() {
    local dir="$1"
    local name="${dir##*/}"
    local project="${name#[0-9][0-9]-}"
    local compose_file="${dir}/compose.yaml"

    echo ":: [${project}] Stopping..."
    if docker compose -f "${compose_file}" --project-name "${project}" down; then
        echo ":: [${project}] Stopped"
    else
        echo ":: [${project}] ERROR: docker compose down failed" >&2
    fi
}

# 1. Unprefixed stacks first — any order
for compose_file in "${COMPOSE_BASE}"/*/compose.yaml; do
    [[ -e "${compose_file}" ]] || continue
    dir="${compose_file%/compose.yaml}"
    name="${dir##*/}"
    [[ "${name}" =~ ^[0-9][0-9]- ]] && continue
    stop_stack "${dir}"
done

# 2. Priority stacks — reverse numeric order (99 → 01)
# Collect matching dirs into an array, then iterate in reverse
priority_dirs=()
for compose_file in "${COMPOSE_BASE}"/[0-9][0-9]-*/compose.yaml; do
    [[ -e "${compose_file}" ]] || continue
    priority_dirs+=("${compose_file%/compose.yaml}")
done

for (( i=${#priority_dirs[@]}-1; i>=0; i-- )); do
    stop_stack "${priority_dirs[$i]}"
done

echo ":: harbor-compose-down complete"
