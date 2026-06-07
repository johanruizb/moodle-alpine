#!/usr/bin/env bash
# Wait for the database to accept connections (skipped for sqlite).
# Delegates to the shared db-probe.php helper.
set -euo pipefail

case "${MOODLE_DATABASE_TYPE:-mariadb}" in
    sqlite|sqlite3) echo "[20-wait-for-db] sqlite: nothing to wait for"; exit 0 ;;
esac

# Retry/interval are read directly from env by db-probe.php
# (MOODLE_DB_WAIT_RETRIES / MOODLE_DB_WAIT_INTERVAL).
echo "[20-wait-for-db] Waiting for DB at ${MOODLE_DATABASE_HOST:-auto}:${MOODLE_DATABASE_PORT_NUMBER:-auto}"

exec php /usr/local/bin/db-probe.php connect
