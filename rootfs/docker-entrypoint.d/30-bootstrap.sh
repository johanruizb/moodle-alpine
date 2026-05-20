#!/usr/bin/env bash
# Install Moodle on first boot, upgrade on subsequent boots if version changed.
# DB existence check uses PHP PDO — no mariadb/psql CLI needed.
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
        # PHP PDO probe: returns 0 if the mdl_config table exists, 1 otherwise.
        if php -r '
$type = getenv("MOODLE_DATABASE_TYPE");
$port = getenv("MOODLE_DATABASE_PORT_NUMBER")
    ?: (in_array($type, ["pgsql","postgres","postgresql"], true) ? "5432" : "3306");
$dsn = in_array($type, ["pgsql","postgres","postgresql"], true)
    ? "pgsql:host=".getenv("MOODLE_DATABASE_HOST").";port=$port;dbname=".getenv("MOODLE_DATABASE_NAME")
    : "mysql:host=".getenv("MOODLE_DATABASE_HOST").";port=$port;dbname=".getenv("MOODLE_DATABASE_NAME");
try {
    $pdo = new PDO($dsn, getenv("MOODLE_DATABASE_USER"), getenv("MOODLE_DATABASE_PASSWORD"),
        [PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION]);
    $stmt = $pdo->query("SELECT 1 FROM mdl_config LIMIT 1");
    exit($stmt !== false ? 0 : 1);
} catch (Throwable $e) { exit(1); }
' >/dev/null 2>&1; then
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
    php admin/cli/upgrade.php --non-interactive --allow-unstable 2>&1 | tail -10 || \
        echo "[30-bootstrap] upgrade.php returned non-zero (likely no upgrade needed)"
fi
