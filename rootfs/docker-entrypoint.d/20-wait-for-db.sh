#!/usr/bin/env bash
# Wait for the database to accept connections (skipped for sqlite).
set -euo pipefail

case "${MOODLE_DATABASE_TYPE:-mariadb}" in
    sqlite|sqlite3) echo "[20-wait-for-db] sqlite: nothing to wait for"; exit 0 ;;
esac

HOST="${MOODLE_DATABASE_HOST:-}"
PORT="${MOODLE_DATABASE_PORT_NUMBER:-}"
USER="${MOODLE_DATABASE_USER:-}"
PASS="${MOODLE_DATABASE_PASSWORD:-}"
NAME="${MOODLE_DATABASE_NAME:-}"

if [ -z "${PORT}" ]; then
    case "${MOODLE_DATABASE_TYPE}" in
        postgres|postgresql|pgsql) PORT="5432" ;;
        *) PORT="3306" ;;
    esac
fi

MAX_TRIES="${MOODLE_DB_WAIT_RETRIES:-60}"
SLEEP_SEC="${MOODLE_DB_WAIT_INTERVAL:-2}"

echo "[20-wait-for-db] Waiting for ${MOODLE_DATABASE_TYPE} at ${HOST}:${PORT} (up to $((MAX_TRIES * SLEEP_SEC))s)"

for i in $(seq 1 "${MAX_TRIES}"); do
    case "${MOODLE_DATABASE_TYPE}" in
        postgres|postgresql|pgsql)
            if PGPASSWORD="${PASS}" psql -h "${HOST}" -p "${PORT}" -U "${USER}" \
                -d "${NAME}" -c '\q' >/dev/null 2>&1; then
                echo "[20-wait-for-db] postgres ready after ${i} attempts"
                exit 0
            fi
            ;;
        *)
            if mariadb -h "${HOST}" -P "${PORT}" -u "${USER}" \
                -p"${PASS}" -e 'SELECT 1' "${NAME}" >/dev/null 2>&1; then
                echo "[20-wait-for-db] mariadb/mysql ready after ${i} attempts"
                exit 0
            fi
            ;;
    esac
    sleep "${SLEEP_SEC}"
done

echo "[20-wait-for-db] ERROR: database never became reachable" >&2
exit 1
