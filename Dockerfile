FROM alpine:latest

ENV \
  CHARSET="UTF-8" \
  LANG="en_US.UTF-8" \
  LC_ALL="en_US.UTF-8"

# Install common packages
RUN set -exo pipefail; \
  apk add --no-cache \
    bash \
    ca-certificates \
    curl \
    libressl \
    tini \
    tzdata \
    ; \
  rm -f /etc/supervisord.conf; \
  # Show Alpine Linux version
  cat /etc/alpine-release

# Install lighttpd
RUN set -exo pipefail; \
  adduser -D -H -u 1000 lighttpd; \
  apk add --no-cache \
    "lighttpd" \
    "lighttpd-mod_auth" \
    ; \
  mkdir -p \
    /var/www \
    /var/cache/lighttpd \
    /var/lib/lighttpd \
    /var/log/lighttpd \
    ; \
  rm -rf /var/www/*; \
  chown lighttpd:lighttpd \
    /var/cache/lighttpd \
    /var/lib/lighttpd \
    /var/log/lighttpd \
    ; \
  chmod 750 \
    /var/cache/lighttpd \
    /var/lib/lighttpd \
    /var/log/lighttpd \
    ; \
  lighttpd -v

COPY rootfs /
RUN set -exo pipefail; \
  chmod +x /docker-entrypoint.sh

ENTRYPOINT ["/sbin/tini", "--", "/docker-entrypoint.sh"]
ENV DOCKER_COMMAND="/usr/sbin/lighttpd"
CMD ["-D", "-f", "/etc/lighttpd/lighttpd.conf"]
