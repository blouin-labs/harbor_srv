#!/usr/bin/env bash
# shellcheck shell=bash
#
# harbor-compose-update — Pull latest images and restart all stacks.
#
# Follows the same priority order as harbor-compose-up.
# A failure in any single stack is logged but does not stop the others.
#

COMPOSE_BASE="/mnt/synology/harbor_srv/docker"

update_stack() {
    local dir="$1"
    local name="${dir##*/}"
    local project="${name#[0-9][0-9]-}"
    local compose_file="${dir}/compose.yaml"

    if [[ ! -f "${compose_file}" ]]; then
        echo ":: [${project}] compose.yaml not found, skipping"
        return
    fi

    echo ":: [${project}] Pulling latest images..."
    if ! docker compose -f "${compose_file}" --project-name "${project}" pull; then
        echo ":: [${project}] WARNING: pull failed, continuing with existing images" >&2
    fi

    echo ":: [${project}] Restarting..."
    if docker compose -f "${compose_file}" --project-name "${project}" up -d; then
        echo ":: [${project}] Updated successfully"
    else
        echo ":: [${project}] ERROR: docker compose up failed" >&2
    fi
}

# 1. Priority stacks first
for compose_file in "${COMPOSE_BASE}"/[0-9][0-9]-*/compose.yaml; do
    [[ -e "${compose_file}" ]] || continue
    update_stack "${compose_file%/compose.yaml}"
done

# 2. Remaining stacks
for compose_file in "${COMPOSE_BASE}"/*/compose.yaml; do
    [[ -e "${compose_file}" ]] || continue
    dir="${compose_file%/compose.yaml}"
    name="${dir##*/}"
    [[ "${name}" =~ ^[0-9][0-9]- ]] && continue
    update_stack "${dir}"
done

echo ":: harbor-compose-update complete"
