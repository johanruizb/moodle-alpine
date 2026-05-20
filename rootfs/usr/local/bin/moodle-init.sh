#!/usr/bin/env bash
# Master entrypoint runner. Invoked by s6-rc.d/moodle-init/up.
set -euo pipefail

log() { printf '[moodle-init] %s\n' "$*"; }

log "Starting Moodle initialization"

shopt -s nullglob
for script in /docker-entrypoint.d/*.sh; do
    log "Running $(basename "$script")"
    # shellcheck disable=SC1090
    bash "$script"
done

log "Initialization complete"
