#!/usr/bin/env bash
# Install Moodle on first boot, upgrade on subsequent boots if version changed.
set -euo pipefail

DATA_DIR="${MOODLE_DATA_DIR:-/bitnami/moodledata}"
INSTALL_MARKER="${DATA_DIR}/.moodle-installed"

cd /var/www/html

if [ "${MOODLE_SKIP_BOOTSTRAP:-no}" = "yes" ]; then
    echo "[30-bootstrap] MOODLE_SKIP_BOOTSTRAP=yes — skipping install/upgrade"
    exit 0
fi

# Probe the DB for the Moodle config table using the native client.
# Avoids loading Moodle's bootstrap (which would crash if not installed).
already_installed="no"
case "${MOODLE_DATABASE_TYPE:-mariadb}" in
    postgres|postgresql|pgsql)
        if PGPASSWORD="${MOODLE_DATABASE_PASSWORD}" psql \
            -h "${MOODLE_DATABASE_HOST}" \
            -p "${MOODLE_DATABASE_PORT_NUMBER:-5432}" \
            -U "${MOODLE_DATABASE_USER}" \
            -d "${MOODLE_DATABASE_NAME}" \
            -tAc "SELECT 1 FROM information_schema.tables WHERE table_name='mdl_config' LIMIT 1" 2>/dev/null \
            | grep -q 1; then
            already_installed="yes"
        fi
        ;;
    sqlite|sqlite3)
        if [ -f "${DATA_DIR}/sqlite/moodle.sqlite" ] && [ -s "${DATA_DIR}/sqlite/moodle.sqlite" ]; then
            already_installed="yes"
        fi
        ;;
    *)
        if mariadb -h "${MOODLE_DATABASE_HOST}" \
            -P "${MOODLE_DATABASE_PORT_NUMBER:-3306}" \
            -u "${MOODLE_DATABASE_USER}" \
            -p"${MOODLE_DATABASE_PASSWORD}" \
            -N -e "SHOW TABLES LIKE 'mdl_config'" "${MOODLE_DATABASE_NAME}" 2>/dev/null \
            | grep -q mdl_config; then
            already_installed="yes"
        fi
        ;;
esac

if [ "${already_installed}" = "no" ]; then
    echo "[30-bootstrap] Fresh database detected — running install_database.php"

    # shellcheck disable=SC2086
    php admin/cli/install_database.php \
        --agree-license \
        --adminuser="${MOODLE_USERNAME:-user}" \
        --adminpass="${MOODLE_PASSWORD:-bitnami}" \
        --adminemail="${MOODLE_EMAIL:-user@example.com}" \
        --fullname="${MOODLE_SITE_NAME:-New Site}" \
        --shortname="${MOODLE_SITE_NAME:-New Site}" \
        --lang="${MOODLE_LANG:-en}" \
        ${MOODLE_INSTALL_EXTRA_ARGS:-}

    touch "${INSTALL_MARKER}"
    echo "[30-bootstrap] Install complete"
else
    echo "[30-bootstrap] Existing installation — running upgrade.php if version changed"
    php admin/cli/upgrade.php --non-interactive --allow-unstable 2>&1 | tail -10 || \
        echo "[30-bootstrap] upgrade.php returned non-zero (likely no upgrade needed)"
fi
