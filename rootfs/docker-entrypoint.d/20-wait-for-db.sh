#!/usr/bin/env bash
# Wait for the database to accept connections (skipped for sqlite).
# Uses PHP PDO (which ships with the image for pgsql/mysqli) instead of the
# native CLI clients, so we don't have to install postgresql-client or
# mariadb-client just for a connectivity probe.
set -euo pipefail

case "${MOODLE_DATABASE_TYPE:-mariadb}" in
    sqlite|sqlite3) echo "[20-wait-for-db] sqlite: nothing to wait for"; exit 0 ;;
esac

MAX_TRIES="${MOODLE_DB_WAIT_RETRIES:-60}"
SLEEP_SEC="${MOODLE_DB_WAIT_INTERVAL:-2}"

echo "[20-wait-for-db] Waiting for ${MOODLE_DATABASE_TYPE} at ${MOODLE_DATABASE_HOST}:${MOODLE_DATABASE_PORT_NUMBER:-auto} (up to $((MAX_TRIES * SLEEP_SEC))s)"

exec php -r '
$type  = getenv("MOODLE_DATABASE_TYPE") ?: "mariadb";
$host  = getenv("MOODLE_DATABASE_HOST");
$port  = getenv("MOODLE_DATABASE_PORT_NUMBER");
$user  = getenv("MOODLE_DATABASE_USER");
$pass  = getenv("MOODLE_DATABASE_PASSWORD");
$name  = getenv("MOODLE_DATABASE_NAME");
$tries = (int) (getenv("MOODLE_DB_WAIT_RETRIES") ?: 60);
$sleep = (int) (getenv("MOODLE_DB_WAIT_INTERVAL") ?: 2);

if (in_array($type, ["pgsql", "postgres", "postgresql"], true)) {
    if (!$port) { $port = "5432"; }
    $dsn = "pgsql:host=$host;port=$port;dbname=$name";
} else {
    if (!$port) { $port = "3306"; }
    $dsn = "mysql:host=$host;port=$port;dbname=$name";
}

for ($i = 1; $i <= $tries; $i++) {
    try {
        $pdo = new PDO($dsn, $user, $pass, [
            PDO::ATTR_TIMEOUT => 3,
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        ]);
        $pdo->query("SELECT 1");
        fwrite(STDERR, "[20-wait-for-db] ready after $i attempts\n");
        exit(0);
    } catch (Throwable $e) {
        // not yet
    }
    sleep($sleep);
}
fwrite(STDERR, "[20-wait-for-db] ERROR: database never became reachable\n");
exit(1);
'
