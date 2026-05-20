# syntax=docker/dockerfile:1.7
FROM alpine:3.21

ARG MOODLE_VERSION=MOODLE_405_STABLE
ARG S6_OVERLAY_VERSION=3.2.0.2
ARG TARGETARCH

ENV MOODLE_VERSION=${MOODLE_VERSION} \
    S6_BEHAVIOUR_IF_STAGE2_FAILS=2 \
    S6_KEEP_ENV=1 \
    PATH="/command:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
    MOODLE_DATA_DIR="/bitnami/moodledata" \
    MOODLE_DATABASE_TYPE="mariadb" \
    MOODLE_DATABASE_HOST="mariadb" \
    MOODLE_DATABASE_PORT_NUMBER="3306" \
    MOODLE_DATABASE_NAME="bitnami_moodle" \
    MOODLE_DATABASE_USER="bn_moodle" \
    MOODLE_DATABASE_PASSWORD="" \
    MOODLE_USERNAME="user" \
    MOODLE_PASSWORD="bitnami" \
    MOODLE_EMAIL="user@example.com" \
    MOODLE_SITE_NAME="New Site" \
    MOODLE_LANG="en" \
    MOODLE_HOST="" \
    MOODLE_REVERSEPROXY="no" \
    MOODLE_SSLPROXY="no" \
    MOODLE_SKIP_BOOTSTRAP="" \
    MOODLE_INSTALL_EXTRA_ARGS="" \
    MOODLE_CRON_MINUTES="1" \
    MOODLE_SMTP_HOST="" \
    MOODLE_SMTP_PORT_NUMBER="" \
    MOODLE_SMTP_USER="" \
    MOODLE_SMTP_PASSWORD="" \
    MOODLE_SMTP_PROTOCOL=""

RUN set -eux; \
    apk add --no-cache \
        bash curl ca-certificates tzdata tini \
        nginx \
        php83 php83-fpm php83-opcache php83-session php83-iconv \
        php83-xml php83-xmlreader php83-xmlwriter php83-dom php83-simplexml \
        php83-tokenizer php83-curl php83-gd php83-mbstring php83-intl \
        php83-zip php83-fileinfo php83-openssl php83-ctype php83-phar \
        php83-sodium php83-exif php83-soap php83-ldap php83-bcmath \
        php83-pecl-redis php83-pecl-igbinary \
        php83-pgsql php83-pdo_pgsql \
        php83-mysqli php83-pdo_mysql \
        php83-sqlite3 php83-pdo_sqlite \
        php83-posix php83-pcntl \
        postgresql16-client mariadb-client; \
    ln -sf /usr/bin/php83 /usr/bin/php; \
    ln -sf /usr/sbin/php-fpm83 /usr/sbin/php-fpm; \
    mkdir -p /var/www /run/nginx /run/php

# s6-overlay v3 (multi-arch)
RUN set -eux; \
    case "${TARGETARCH:-amd64}" in \
        amd64) S6_ARCH="x86_64" ;; \
        arm64) S6_ARCH="aarch64" ;; \
        arm)   S6_ARCH="armhf" ;; \
        386)   S6_ARCH="i686" ;; \
        *) echo "Unsupported arch: ${TARGETARCH}"; exit 1 ;; \
    esac; \
    curl -fsSL "https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-noarch.tar.xz" \
        | tar -C / -Jxpf -; \
    curl -fsSL "https://github.com/just-containers/s6-overlay/releases/download/v${S6_OVERLAY_VERSION}/s6-overlay-${S6_ARCH}.tar.xz" \
        | tar -C / -Jxpf -

# Download Moodle source
RUN set -eux; \
    mkdir -p /var/www/html; \
    curl -fsSL "https://github.com/moodle/moodle/archive/refs/heads/${MOODLE_VERSION}.tar.gz" \
        -o /tmp/moodle.tar.gz 2>/dev/null \
    || curl -fsSL "https://github.com/moodle/moodle/archive/${MOODLE_VERSION}.tar.gz" \
        -o /tmp/moodle.tar.gz; \
    tar -xzf /tmp/moodle.tar.gz -C /var/www/html --strip-components=1; \
    rm /tmp/moodle.tar.gz; \
    mkdir -p /bitnami/moodledata; \
    chown -R nobody:nobody /var/www /bitnami /run/nginx /run/php

# Install moosh CLI helper (optional, ~3MB)
RUN set -eux; \
    curl -fsSL https://moodle.org/plugins/download.php/33485/moosh_moodle45_2024061900.zip -o /tmp/moosh.zip 2>/dev/null \
        && unzip -q /tmp/moosh.zip -d /opt/ \
        && rm /tmp/moosh.zip \
        && ln -sf /opt/moosh/moosh.php /usr/local/bin/moosh \
        || echo "moosh install skipped"

COPY --chown=nobody:nobody rootfs/ /

RUN set -eux; \
    chmod +x /docker-entrypoint.d/*.sh /usr/local/bin/* 2>/dev/null || true; \
    chmod +x /etc/s6-overlay/s6-rc.d/*/run 2>/dev/null || true; \
    chmod +x /etc/s6-overlay/s6-rc.d/*/up 2>/dev/null || true

EXPOSE 8080

VOLUME ["/bitnami"]

WORKDIR /var/www/html

ENTRYPOINT ["/init"]
