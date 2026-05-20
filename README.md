# moodle-alpine

Lightweight Moodle Docker image based on **Alpine Linux**, designed as a free,
drop-in replacement for `bitnami/moodle` after Bitnami moved its catalog behind
a paid subscription.

- **Base:** `alpine:3.21` + PHP 8.3 + Nginx 1.26 + PHP-FPM (ondemand)
- **Process supervisor:** `s6-overlay` v3
- **Image size:** ~250 MB compressed (Moodle source itself is ~400 MB extracted)
- **Architectures:** `linux/amd64`, `linux/arm64`
- **Databases supported:** PostgreSQL, MariaDB, MySQL, SQLite
- **Moodle versions:** 4.5 LTS (`:4.5`, `:lts`), 5.0 LTS (`:5`, `:latest`)
- **Drop-in compatibility:** uses the same `MOODLE_*` environment variables as Bitnami

## Quick start

### PostgreSQL

```yaml
services:
  postgres:
    image: postgres:16-alpine
    environment:
      POSTGRES_DB: bitnami_moodle
      POSTGRES_USER: bn_moodle
      POSTGRES_PASSWORD: moodlepass
    volumes:
      - pg-data:/var/lib/postgresql/data

  moodle:
    image: ghcr.io/johanruizb/moodle-alpine:latest
    depends_on: [postgres]
    environment:
      MOODLE_DATABASE_TYPE: pgsql
      MOODLE_DATABASE_HOST: postgres
      MOODLE_DATABASE_NAME: bitnami_moodle
      MOODLE_DATABASE_USER: bn_moodle
      MOODLE_DATABASE_PASSWORD: moodlepass
      MOODLE_USERNAME: admin
      MOODLE_PASSWORD: ChangeMe123!
      MOODLE_EMAIL: admin@example.com
      MOODLE_SITE_NAME: My Moodle
      MOODLE_HOST: moodle.example.com
    ports:
      - "8080:8080"
    volumes:
      - moodle-data:/bitnami

volumes:
  pg-data:
  moodle-data:
```

### MariaDB

Same as above with:

```yaml
    environment:
      MOODLE_DATABASE_TYPE: mariadb
      MOODLE_DATABASE_HOST: mariadb
      MOODLE_DATABASE_PORT_NUMBER: "3306"
```

## Migrating from `bitnami/moodle`

Change only the `image:` line:

```diff
-  image: bitnami/moodle:latest
+  image: ghcr.io/johanruizb/moodle-alpine:latest
```

Volume paths (`/bitnami/moodledata`) and all `MOODLE_*` env vars match the
Bitnami contract. Run `docker compose up` against an existing `bitnami_moodle`
database and `/bitnami/moodledata` volume — no migration scripts needed.

## Environment variables

| Variable | Default | Purpose |
|---|---|---|
| `MOODLE_DATABASE_TYPE` | `mariadb` | One of `mariadb`, `mysqli`, `pgsql`, `sqlite3` |
| `MOODLE_DATABASE_HOST` | `mariadb` | DB hostname |
| `MOODLE_DATABASE_PORT_NUMBER` | `3306` / `5432` | DB port |
| `MOODLE_DATABASE_NAME` | `bitnami_moodle` | DB name |
| `MOODLE_DATABASE_USER` | `bn_moodle` | DB user |
| `MOODLE_DATABASE_PASSWORD` | — | DB password |
| `MOODLE_DATA_DIR` | `/bitnami/moodledata` | Moodle dataroot |
| `MOODLE_USERNAME` | `user` | Initial admin username |
| `MOODLE_PASSWORD` | `bitnami` | Initial admin password |
| `MOODLE_EMAIL` | `user@example.com` | Initial admin email |
| `MOODLE_SITE_NAME` | `New Site` | Site full/short name |
| `MOODLE_HOST` | — | `wwwroot` host (e.g. `moodle.example.com`) |
| `MOODLE_LANG` | `en` | Default language |
| `MOODLE_SKIP_BOOTSTRAP` | `no` | If `yes`, skip `install_database.php` |
| `MOODLE_INSTALL_EXTRA_ARGS` | — | Extra CLI args appended to install |
| `MOODLE_REVERSEPROXY` | `no` | Enable `$CFG->reverseproxy` |
| `MOODLE_SSLPROXY` | `no` | Enable `$CFG->sslproxy` |
| `MOODLE_CRON_MINUTES` | `1` | Internal cron interval |
| `MOODLE_SMTP_HOST` | — | SMTP relay host |
| `MOODLE_SMTP_PORT_NUMBER` | — | SMTP port |
| `MOODLE_SMTP_USER` | — | SMTP username |
| `MOODLE_SMTP_PASSWORD` | — | SMTP password |
| `MOODLE_SMTP_PROTOCOL` | — | `tls` or `ssl` |

## Build locally

```bash
docker build --build-arg MOODLE_VERSION=MOODLE_500_STABLE -t moodle:5.0 .
docker build --build-arg MOODLE_VERSION=MOODLE_405_STABLE -t moodle:4.5 .
```

## Run tests

```bash
docker compose -f tests/docker-compose.postgres.yml up -d
bash tests/smoke.sh
docker compose -f tests/docker-compose.postgres.yml down -v
```

## Tag scheme

| Tag | Moodle |
|---|---|
| `latest` | Latest stable (currently 5.0) |
| `5`, `5.0` | Moodle 5.0 LTS |
| `lts`, `4.5`, `4` | Moodle 4.5 LTS (support until Dec 2027) |

## Why?

Bitnami moved free public images to a paywall in 2025. This image preserves the
contract (`MOODLE_*` vars, `/bitnami/moodledata`) so existing compose files and
Helm charts keep working with a one-line change. Source code, build pipeline,
and image registry are public and free.

## License

The Dockerfile, scripts, and CI in this repository are released under the MIT
License. Moodle itself is GPL v3 — see `https://github.com/moodle/moodle`.
