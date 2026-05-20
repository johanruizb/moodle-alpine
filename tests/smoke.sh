#!/usr/bin/env bash
# Smoke test: wait for Moodle to come up, then verify login page renders.
set -euo pipefail

URL="${SMOKE_URL:-http://localhost:8080/login/index.php}"
MAX_WAIT="${SMOKE_TIMEOUT:-300}"
SLEEP=5

echo "[smoke] Probing ${URL} (up to ${MAX_WAIT}s)"

elapsed=0
while [ "${elapsed}" -lt "${MAX_WAIT}" ]; do
    body=$(curl -fsS -o - -w '\n%{http_code}' "${URL}" 2>/dev/null || true)
    code=$(printf '%s' "${body}" | tail -n1)
    page=$(printf '%s' "${body}" | sed '$d')
    if [ "${code}" = "200" ] && echo "${page}" | grep -qi 'moodle'; then
        echo "[smoke] OK: ${URL} returned 200 with Moodle content"
        exit 0
    fi
    printf '[smoke] %ss elapsed, http=%s\n' "${elapsed}" "${code:-???}"
    sleep "${SLEEP}"
    elapsed=$(( elapsed + SLEEP ))
done

echo "[smoke] FAIL: ${URL} never returned a valid Moodle login page" >&2
echo "[smoke] Recent container logs:" >&2
docker compose -f "$(dirname "$0")"/docker-compose.*.yml logs --tail=80 moodle >&2 || true
exit 1
