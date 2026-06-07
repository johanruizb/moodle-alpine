#!/usr/bin/env bash
# Render nginx snippets that depend on runtime env vars.
# Currently: HSTS header, enabled only when SSL is terminated at a proxy.
set -euo pipefail

SNIPPET="/etc/nginx/snippets/hsts.conf"
mkdir -p "$(dirname "${SNIPPET}")"

if [ "${MOODLE_SSLPROXY:-no}" = "yes" ]; then
    cat > "${SNIPPET}" <<'EOF'
add_header Strict-Transport-Security "max-age=63072000; includeSubDomains" always;
EOF
    echo "[15-render-nginx] HSTS enabled"
else
    : > "${SNIPPET}"
    echo "[15-render-nginx] HSTS disabled (MOODLE_SSLPROXY!=yes)"
fi
