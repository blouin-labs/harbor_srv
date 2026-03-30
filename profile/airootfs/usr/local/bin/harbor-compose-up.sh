#!/usr/bin/env bash
# shellcheck shell=bash
#
# harbor-compose-up — Start all Docker Compose stacks from the NFS share.
#
# Directories with a two-digit numeric prefix (e.g. 01-technitium) start first,
# in prefix order. Unprefixed directories start afterward in any order.
# A failure in any single stack is logged but does not stop the others.
#

COMPOSE_BASE="/mnt/synology/harbor_srv/docker"

start_stack() {
    local dir="$1"
    local name="${dir##*/}"
    local project="${name#[0-9][0-9]-}"
    local compose_file="${dir}/compose.yaml"

    if [[ ! -f "${compose_file}" ]]; then
        echo ":: [${project}] compose.yaml not found, skipping"
        return
    fi

    echo ":: [${project}] Starting..."
    if docker compose -f "${compose_file}" --project-name "${project}" up -d; then
        echo ":: [${project}] Started successfully"
    else
        echo ":: [${project}] ERROR: docker compose up failed" >&2
    fi
}

# 1. Priority stacks — two-digit prefix, glob order = numeric order
for compose_file in "${COMPOSE_BASE}"/[0-9][0-9]-*/compose.yaml; do
    [[ -e "${compose_file}" ]] || continue
    start_stack "${compose_file%/compose.yaml}"
done

# 2. Remaining stacks — no numeric prefix, any order
for compose_file in "${COMPOSE_BASE}"/*/compose.yaml; do
    [[ -e "${compose_file}" ]] || continue
    dir="${compose_file%/compose.yaml}"
    name="${dir##*/}"
    [[ "${name}" =~ ^[0-9][0-9]- ]] && continue
    start_stack "${dir}"
done

echo ":: harbor-compose-up complete"
