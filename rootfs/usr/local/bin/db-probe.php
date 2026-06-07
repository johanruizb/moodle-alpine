<?php
/**
 * Shared DB connectivity probe used by entrypoint scripts.
 *
 * Usage:
 *   php /usr/local/bin/db-probe.php connect   — wait until DB accepts connections
 *   php /usr/local/bin/db-probe.php table     — exit 0 if mdl_config exists, 1 otherwise
 *
 * Env vars read: MOODLE_DATABASE_TYPE, MOODLE_DATABASE_HOST,
 *   MOODLE_DATABASE_PORT_NUMBER, MOODLE_DATABASE_USER,
 *   MOODLE_DATABASE_PASSWORD, MOODLE_DATABASE_NAME,
 *   MOODLE_DB_WAIT_RETRIES (default 60), MOODLE_DB_WAIT_INTERVAL (default 2)
 */

function getDsn(): array {
    $type = getenv('MOODLE_DATABASE_TYPE') ?: 'mariadb';
    $host = getenv('MOODLE_DATABASE_HOST') ?: '';
    $port = getenv('MOODLE_DATABASE_PORT_NUMBER') ?: '';
    $name = getenv('MOODLE_DATABASE_NAME') ?: 'bitnami_moodle';

    $isPgsql = in_array($type, ['pgsql', 'postgres', 'postgresql'], true);

    if (!$port) {
        $port = $isPgsql ? '5432' : '3306';
    }

    $driver = $isPgsql ? 'pgsql' : 'mysql';
    $dsn = "{$driver}:host={$host};port={$port};dbname={$name}";

    return [$dsn, $port];
}

function getConnection(): PDO {
    [$dsn] = getDsn();
    $user = getenv('MOODLE_DATABASE_USER') ?: 'bn_moodle';
    $pass = getenv('MOODLE_DATABASE_PASSWORD') ?: '';

    return new PDO($dsn, $user, $pass, [
        PDO::ATTR_TIMEOUT   => 3,
        PDO::ATTR_ERRMODE   => PDO::ERRMODE_EXCEPTION,
    ]);
}

$action = $argv[1] ?? 'connect';

if ($action === 'table') {
    // Quick check: does mdl_config table exist?
    try {
        $pdo = getConnection();
        $stmt = $pdo->query('SELECT 1 FROM mdl_config LIMIT 1');
        exit($stmt !== false ? 0 : 1);
    } catch (Throwable $e) {
        exit(1);
    }
}

// Default: wait for connectivity
$tries = (int) (getenv('MOODLE_DB_WAIT_RETRIES') ?: 60);
$sleep = (int) (getenv('MOODLE_DB_WAIT_INTERVAL') ?: 2);

for ($i = 1; $i <= $tries; $i++) {
    try {
        $pdo = getConnection();
        $pdo->query('SELECT 1');
        fwrite(STDERR, "[db-probe] ready after {$i} attempts\n");
        exit(0);
    } catch (Throwable $e) {
        // not yet
    }
    sleep($sleep);
}

fwrite(STDERR, "[db-probe] ERROR: database never became reachable\n");
exit(1);
