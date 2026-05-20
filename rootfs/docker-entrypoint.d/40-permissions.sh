#!/usr/bin/env bash
# Ensure dataroot is writable by the runtime user (nobody).
# Only chown if running as root — under USER nobody this is a no-op.
set -euo pipefail

DATA_DIR="${MOODLE_DATA_DIR:-/bitnami/moodledata}"

mkdir -p "${DATA_DIR}"

if [ "$(id -u)" = "0" ]; then
    chown -R nobody:nobody "${DATA_DIR}" /var/www/html
    echo "[40-permissions] Adjusted ownership of ${DATA_DIR} to nobody:nobody"
else
    echo "[40-permissions] Running as $(id -un), no chown needed"
fi
