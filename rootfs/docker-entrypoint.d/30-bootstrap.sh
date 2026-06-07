#!/usr/bin/env bash
# Install Moodle on first boot, upgrade on subsequent boots if version changed.
# DB existence check uses the shared db-probe.php helper.
set -euo pipefail

DATA_DIR="${MOODLE_DATA_DIR:-/bitnami/moodledata}"
INSTALL_MARKER="${DATA_DIR}/.moodle-installed"

cd /var/www/html

if [ "${MOODLE_SKIP_BOOTSTRAP:-no}" = "yes" ]; then
    echo "[30-bootstrap] MOODLE_SKIP_BOOTSTRAP=yes — skipping install/upgrade"
    exit 0
fi

case "${MOODLE_DATABASE_TYPE:-mariadb}" in
    sqlite|sqlite3)
        if [ -f "${DATA_DIR}/sqlite/moodle.sqlite" ] && [ -s "${DATA_DIR}/sqlite/moodle.sqlite" ]; then
            already_installed="yes"
        else
            already_installed="no"
        fi
        ;;
    *)
        # Delegate to shared helper: exit 0 if mdl_config exists
        if php /usr/local/bin/db-probe.php table >/dev/null 2>&1; then
            already_installed="yes"
        else
            already_installed="no"
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
    # Capture exit status of php (not tail) so real upgrade failures abort boot.
    set +e
    upgrade_out="$(php admin/cli/upgrade.php --non-interactive --allow-unstable 2>&1)"
    upgrade_rc=$?
    set -e
    echo "${upgrade_out}" | tail -20
    if [ "${upgrade_rc}" -ne 0 ]; then
        # Moodle exits non-zero when already up to date; treat that as success,
        # anything else is a real failure.
        if echo "${upgrade_out}" | grep -qiE 'no upgrade|already up.?to.?date|cannot find version'; then
            echo "[30-bootstrap] No upgrade needed"
        else
            echo "[30-bootstrap] ERROR: upgrade.php failed (rc=${upgrade_rc})" >&2
            exit "${upgrade_rc}"
        fi
    fi
fi
